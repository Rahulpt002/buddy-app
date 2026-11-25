"""FastAPI app: /ws (authenticated, single socket per client) and /api/health."""
from __future__ import annotations

import asyncio
import json
import logging
import platform
import socket

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from pydantic import ValidationError

from . import PROTO_VERSION, __version__
from .hub import Client, Hub, dumps, now_ms
from .pairing import Identity, lan_ipv4s
from .protocol import Hello, Req, Sub

log = logging.getLogger(__name__)

HELLO_TIMEOUT_S = 5.0
MAX_FRAME = 64 * 1024


def create_app(hub: Hub, ident: Identity, tls: bool) -> FastAPI:
    app = FastAPI(title="DeskPanel agent", docs_url=None, redoc_url=None, openapi_url=None)

    @app.get("/api/health")
    async def health() -> dict:
        return {"agent_id": ident.agent_id, "proto": PROTO_VERSION, "tls": tls}

    @app.websocket("/ws")
    async def ws_endpoint(ws: WebSocket) -> None:
        await ws.accept()
        peer = f"{ws.client.host}:{ws.client.port}" if ws.client else "?"

        async def close(code: int, err: dict | None = None) -> None:
            if err:
                try:
                    await ws.send_text(dumps({"t": "error", **err}))
                except Exception:  # noqa: BLE001
                    pass
            await ws.close(code)

        # ---- handshake
        try:
            raw = await asyncio.wait_for(ws.receive_text(), HELLO_TIMEOUT_S)
        except asyncio.TimeoutError:
            await close(4408, {"code": "hello_timeout"})
            return
        except WebSocketDisconnect:
            return
        try:
            hello = Hello.model_validate_json(raw[:MAX_FRAME])
        except ValidationError:
            await close(4400, {"code": "bad_request", "message": "expected hello"})
            return
        if not ident.check(hello.token):
            log.warning("rejected connection from %s: bad token", peer)
            await close(4401, {"code": "auth_failed"})
            return
        if hello.proto != PROTO_VERSION:
            await close(4426, {"code": "proto_unsupported", "supported": [PROTO_VERSION]})
            return

        await ws.send_text(dumps({
            "t": "welcome",
            "proto": PROTO_VERSION,
            "agent_id": ident.agent_id,
            "agent_version": __version__,
            "host": socket.gethostname().removesuffix(".local"),
            "os": {"Darwin": "macos", "Windows": "windows"}.get(platform.system(), "linux"),
            "server_time": now_ms(),
            # Current LAN addresses, so a phone connected over USB can find the laptop on
            # Wi-Fi later even if its IP changed since pairing (mDNS often doesn't cross
            # wired <-> wireless on home routers).
            "hosts": lan_ipv4s(),
            "topics": hub.topics,
            "actions": hub.actions,
        }))
        log.info("client %s (%s, %s) connected from %s", hello.client.name,
                 hello.client.platform, hello.client.app_version, peer)

        client = Client(ws.send_text, name=hello.client.name)
        hub.add_client(client)
        writer = asyncio.create_task(client.writer())
        tasks: set[asyncio.Task] = set()
        try:
            while True:
                raw = await ws.receive_text()
                if len(raw) > MAX_FRAME:
                    continue
                try:
                    msg = json.loads(raw)
                    t = msg.get("t")
                except (json.JSONDecodeError, AttributeError):
                    continue
                if t == "ping":
                    client.push(dumps({"t": "pong", "ts": msg.get("ts")}))
                elif t == "pong":
                    pass
                elif t == "sub":
                    try:
                        sub = Sub.model_validate(msg)
                    except ValidationError:
                        continue
                    unknown = hub.subscribe(client, sub.topics)
                    if unknown:
                        client.push(dumps({"t": "warn", "code": "unknown_topics", "topics": unknown}))
                elif t == "req":
                    try:
                        req = Req.model_validate(msg)
                    except ValidationError:
                        rid = msg.get("id") if isinstance(msg.get("id"), str) else ""
                        client.push(dumps({"t": "res", "id": rid, "ok": False,
                                           "error": {"code": "bad_request", "message": "invalid req"}}))
                        continue
                    task = asyncio.create_task(hub.run_action(client, req.id, req.action, req.params))
                    tasks.add(task)
                    task.add_done_callback(tasks.discard)
        except WebSocketDisconnect:
            pass
        except Exception:  # noqa: BLE001
            log.exception("websocket error")
        finally:
            hub.remove_client(client)
            writer.cancel()
            log.info("client %s disconnected", hello.client.name)

    return app
