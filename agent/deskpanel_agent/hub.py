"""Topic hub: latest snapshot per topic, per-client subscriptions, action dispatch.

Slow clients never build up a backlog: each client keeps only the newest pending frame
per topic, plus a small FIFO for action responses/progress which must not be dropped.
"""
from __future__ import annotations

import asyncio
import contextvars
import json
import logging
import time
from collections import deque
from typing import Any, Awaitable, Callable, Protocol

from pydantic import BaseModel

from .protocol import TOPICS

log = logging.getLogger(__name__)


def now_ms() -> int:
    return int(time.time() * 1000)


def dumps(obj: dict) -> str:
    return json.dumps(obj, separators=(",", ":"), ensure_ascii=False)


class ActionError(Exception):
    def __init__(self, code: str, message: str = ""):
        super().__init__(message or code)
        self.code = code
        self.message = message or code


# The client whose request is being handled (for actions that answer that phone later,
# e.g. mouse.setup, which streams pointer frames back to the phone that asked).
current_client: contextvars.ContextVar["Client | None"] = contextvars.ContextVar("current_client", default=None)

Progress = Callable[[dict], Awaitable[None]]
ActionHandler = Callable[[dict, Progress], Awaitable[dict | None]]


class Provider(Protocol):
    """Produces one or more topics and/or handles actions."""

    topics: tuple[str, ...]
    actions: dict[str, ActionHandler]

    async def start(self, hub: "Hub") -> None: ...
    async def stop(self) -> None: ...
    # Called when a topic gains its first / loses its last subscriber.
    def on_demand(self, topic: str, wanted: bool) -> None: ...


class Client:
    def __init__(self, send: Callable[[str], Awaitable[None]], name: str = "client"):
        self._send = send
        self.name = name
        self.topics: set[str] = set()
        self._pending: dict[str, str] = {}
        self._fifo: deque[str] = deque()
        self._wake = asyncio.Event()
        self.closed = False

    def push_topic(self, topic: str, frame: str) -> None:
        self._pending[topic] = frame
        self._wake.set()

    def push(self, frame: str) -> None:
        self._fifo.append(frame)
        self._wake.set()

    async def writer(self) -> None:
        while not self.closed:
            await self._wake.wait()
            self._wake.clear()
            while self._fifo:
                await self._send(self._fifo.popleft())
            while self._pending:
                topic = next(iter(self._pending))
                await self._send(self._pending.pop(topic))
                while self._fifo:  # responses jump ahead of further topic frames
                    await self._send(self._fifo.popleft())


class Hub:
    def __init__(self) -> None:
        self.latest: dict[str, str] = {}
        self._seq: dict[str, int] = {}
        self.clients: set[Client] = set()
        self.providers: list[Provider] = []
        self._actions: dict[str, ActionHandler] = {}
        self._topic_owner: dict[str, Provider] = {}
        self._linger: dict[str, asyncio.TimerHandle] = {}
        self.linger_s = 60.0

    # ---------------------------------------------------------- providers

    def add_provider(self, p: Provider) -> None:
        self.providers.append(p)
        for t in p.topics:
            self._topic_owner[t] = p
        self._actions.update(p.actions)

    @property
    def topics(self) -> list[str]:
        return [t for t in TOPICS if t in self._topic_owner]

    @property
    def actions(self) -> list[str]:
        return sorted(self._actions)

    async def start(self) -> None:
        for p in self.providers:
            await p.start(self)

    async def stop(self) -> None:
        for p in self.providers:
            try:
                await p.stop()
            except Exception:  # noqa: BLE001
                log.exception("provider stop failed")

    # ---------------------------------------------------------- publish

    def publish(self, topic: str, data: BaseModel | dict) -> None:
        payload = data.model_dump(mode="json") if isinstance(data, BaseModel) else data
        seq = self._seq.get(topic, 0) + 1
        self._seq[topic] = seq
        frame = dumps({"t": "evt", "topic": topic, "seq": seq, "ts": now_ms(), "data": payload})
        self.latest[topic] = frame
        for c in self.clients:
            if topic in c.topics:
                c.push_topic(topic, frame)

    # ---------------------------------------------------------- clients

    def add_client(self, c: Client) -> None:
        self.clients.add(c)

    def remove_client(self, c: Client) -> None:
        c.closed = True
        c._wake.set()
        self.clients.discard(c)
        for p in self.providers:
            gone = getattr(p, "on_client_gone", None)
            if gone:
                try:
                    gone(c)
                except Exception:  # noqa: BLE001
                    log.exception("on_client_gone failed")
        old = c.topics
        c.topics = set()
        self._demand_changed(old)

    def subscribe(self, c: Client, topics: list[str]) -> list[str]:
        """Replace c's subscription set. Returns unknown topics."""
        known = set(self._topic_owner)
        wanted = {t for t in topics if t in known}
        if "media" in wanted:
            wanted.add("media.art")
        unknown = [t for t in topics if t not in known]
        added = wanted - c.topics
        old = c.topics
        c.topics = wanted
        self._demand_changed(old | wanted)
        for t in TOPICS:  # stable order
            if t in added and t in self.latest:
                c.push_topic(t, self.latest[t])
        return unknown

    def subscribers(self, topic: str) -> int:
        return sum(1 for c in self.clients if topic in c.topics)

    def _demand_changed(self, topics: set[str]) -> None:
        loop = asyncio.get_running_loop()
        for t in topics:
            owner = self._topic_owner.get(t)
            if owner is None:
                continue
            n = self.subscribers(t)
            h = self._linger.pop(t, None)
            if h:
                h.cancel()
            if n > 0:
                owner.on_demand(t, True)
            else:
                self._linger[t] = loop.call_later(self.linger_s, owner.on_demand, t, False)

    # ---------------------------------------------------------- actions

    async def run_action(self, c: Client, req_id: str, action: str, params: dict) -> None:
        handler = self._actions.get(action)

        async def progress(data: dict) -> None:
            c.push(dumps({"t": "prog", "id": req_id, "data": data}))

        if handler is None:
            c.push(dumps({"t": "res", "id": req_id, "ok": False,
                          "error": {"code": "unsupported", "message": f"Unknown action {action}"}}))
            return
        token = current_client.set(c)
        try:
            result: Any = await handler(params, progress)
            c.push(dumps({"t": "res", "id": req_id, "ok": True, "result": result or {}}))
        except ActionError as e:
            c.push(dumps({"t": "res", "id": req_id, "ok": False,
                          "error": {"code": e.code, "message": e.message}}))
        except Exception as e:  # noqa: BLE001
            log.exception("action %s failed", action)
            c.push(dumps({"t": "res", "id": req_id, "ok": False,
                          "error": {"code": "failed", "message": str(e)}}))
        finally:
            current_client.reset(token)
