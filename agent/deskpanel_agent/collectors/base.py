"""Common provider plumbing: a supervised run loop, demand tracking, publishing."""
from __future__ import annotations

import asyncio
import logging
from typing import Any

from ..hub import ActionHandler, Hub

log = logging.getLogger(__name__)


class BaseProvider:
    topics: tuple[str, ...] = ()

    def __init__(self) -> None:
        self.hub: Hub | None = None
        self.actions: dict[str, ActionHandler] = {}
        self._tasks: list[asyncio.Task] = []
        self.wanted: set[str] = set()
        self.demand = asyncio.Event()

    async def start(self, hub: Hub) -> None:
        self.hub = hub
        try:
            await self.setup()
        except Exception as e:  # noqa: BLE001
            log.exception("%s setup failed", type(self).__name__)
            for t in self.topics:
                hub.publish(t, {"status": "error", "message": f"Failed to start: {e}"})
            return
        for name in self.loops():
            self._tasks.append(asyncio.create_task(self._supervise(name)))

    async def setup(self) -> None:
        """One-time init (may publish an initial snapshot)."""

    def loops(self) -> list[str]:
        """Names of async methods to run forever (each restarted if it crashes)."""
        return ["run"]

    async def run(self) -> None:  # pragma: no cover - overridden
        await asyncio.Event().wait()

    async def _supervise(self, name: str) -> None:
        fn = getattr(self, name)
        while True:
            try:
                await fn()
                return
            except asyncio.CancelledError:
                raise
            except Exception:  # noqa: BLE001
                log.exception("%s.%s crashed; restarting in 5s", type(self).__name__, name)
                await asyncio.sleep(5)

    async def stop(self) -> None:
        for t in self._tasks:
            t.cancel()

    def on_demand(self, topic: str, wanted: bool) -> None:
        (self.wanted.add if wanted else self.wanted.discard)(topic)
        self.demand.set()

    def publish(self, topic: str, data: Any) -> None:
        assert self.hub
        self.hub.publish(topic, data)


async def run_cmd(*args: str, timeout: float = 5.0, stdin: bytes | None = None) -> tuple[int, str]:
    """Run a command without a shell. Returns (returncode, stdout+stderr)."""
    proc = await asyncio.create_subprocess_exec(
        *args,
        stdin=asyncio.subprocess.PIPE if stdin is not None else asyncio.subprocess.DEVNULL,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.STDOUT,
    )
    try:
        out, _ = await asyncio.wait_for(proc.communicate(stdin), timeout)
    except asyncio.TimeoutError:
        proc.kill()
        return -1, "timeout"
    return proc.returncode or 0, out.decode(errors="replace")


async def osascript(script: str, timeout: float = 5.0) -> tuple[int, str]:
    rc, out = await run_cmd("osascript", "-", timeout=timeout, stdin=script.encode())
    return rc, out.rstrip("\n")
