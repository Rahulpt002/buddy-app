"""FastAPI apps.

`create_app`: the phone's server, /ws (authenticated, single socket per client) and /api/health.
`create_web_app`: the desk web page for a browser on this Mac, plain http bound to 127.0.0.1:
the page's files plus the same /ws, keyed by the separate web token. Requests must name
127.0.0.1/localhost as Host (stops DNS rebinding) and sockets must come from the page's own
origin (stops other websites reaching it).
"""
from __future__ import annotations

import asyncio
import hmac
import json
import logging
import platform
import socket

from pathlib import Path

from fastapi import FastAPI, Request, WebSocket, WebSocketDisconnect
from fastapi.responses import FileResponse, PlainTextResponse, Response
from pydantic import ValidationError

from . import PROTO_VERSION, __version__
from .hub import Client, Hub, dumps, now_ms
from .pairing import Identity, lan_ipv4s
from .protocol import Hello, Req, Sub

log = logging.getLogger(__name__)

HELLO_TIMEOUT_S = 5.0
MAX_FRAME = 64 * 1024
WEB_DIR = Path(__file__).parent / "web"
_TYPES = {".html": "text/html; charset=utf-8", ".js": "text/javascript; charset=utf-8",
          ".css": "text/css; charset=utf-8", ".svg": "image/svg+xml", ".png": "image/png"}
_CSP = ("default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; "
        "img-src 'self' data: blob:; connect-src 'self' https://api.open-meteo.com "
        "https://geocoding-api.open-meteo.com; frame-ancestors 'none'; base-uri 'none'")


def create_app(hub: Hub, ident: Identity, tls: bool) -> FastAPI:
    app = FastAPI(title="DeskPanel agent", docs_url=None, redoc_url=None, openapi_url=None)

    @app.get("/api/health")
    async def health() -> dict:
        return {"agent_id": ident.agent_id, "proto": PROTO_VERSION, "tls": tls}

    @app.websocket("/ws")
    async def ws_endpoint(ws: WebSocket) -> None:
        await _session(ws, hub, ident, ident.token)

    return app


def _local_hosts(port: int) -> set[str]:
    return {f"127.0.0.1:{port}", f"localhost:{port}"}


def create_web_app(hub: Hub, ident: Identity, port: int, web_dir: Path = WEB_DIR) -> FastAPI:
    app = FastAPI(title="DeskPanel desk", docs_url=None, redoc_url=None, openapi_url=None)
    hosts = _local_hosts(port)
    origins = {f"http://{h}" for h in hosts}

    @app.middleware("http")
    async def only_local_host(request: Request, call_next):  # noqa: ANN001, ANN202
        if request.headers.get("host", "") not in hosts:
            return PlainTextResponse("Open this page at http://127.0.0.1:%d/" % port, status_code=421)
        return await call_next(request)

    @app.get("/{name:path}")
    async def page(name: str) -> Response:
        name = name or "index.html"
        f = (web_dir / name).resolve()
        if f.parent != web_dir.resolve() or f.suffix not in _TYPES or not f.is_file():
            return PlainTextResponse("not found", status_code=404)
        return FileResponse(f, media_type=_TYPES[f.suffix], headers={
            "Cache-Control": "no-cache", "Content-Security-Policy": _CSP,
            "X-Content-Type-Options": "nosniff", "Referrer-Policy": "no-referrer"})

    @app.websocket("/ws")
    async def ws_endpoint(ws: WebSocket) -> None:
        if ws.headers.get("host", "") not in hosts or ws.headers.get("origin", "") not in origins:
            await ws.close(4403)
            return
        await _session(ws, hub, ident, ident.web_token)

    return app


async def _session(ws: WebSocket, hub: Hub, ident: Identity, token: str) -> None:
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
    if not token or not hello.token or not hmac.compare_digest(hello.token.encode(), token.encode()):
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
