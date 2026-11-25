import contextlib
import json
import time

import pytest
from fastapi.testclient import TestClient
from starlette.websockets import WebSocketDisconnect

from deskpanel_agent.hub import Hub
from deskpanel_agent.mock import MockProvider
from deskpanel_agent.pairing import load_identity
from deskpanel_agent.server import create_app


@pytest.fixture
def setup():
    ident = load_identity()
    hub = Hub()
    hub.add_provider(MockProvider())
    app = create_app(hub, ident, tls=False)

    @contextlib.asynccontextmanager
    async def lifespan(_app):
        await hub.start()
        yield
        await hub.stop()

    app.router.lifespan_context = lifespan
    with TestClient(app) as client:
        yield client, ident


def hello(token, proto=1):
    return json.dumps({"t": "hello", "proto": proto, "token": token,
                       "client": {"name": "test", "platform": "pytest", "app_version": "0"}})


def recv_until(ws, pred, limit=50):
    for _ in range(limit):
        msg = json.loads(ws.receive_text())
        if pred(msg):
            return msg
    raise AssertionError("expected frame not received")


def test_health_is_open(setup):
    client, ident = setup
    r = client.get("/api/health")
    assert r.status_code == 200 and r.json()["agent_id"] == ident.agent_id


def test_rejects_bad_token(setup):
    client, _ = setup
    with client.websocket_connect("/ws") as ws:
        ws.send_text(hello("nope"))
        assert json.loads(ws.receive_text())["code"] == "auth_failed"
        with pytest.raises(WebSocketDisconnect) as e:
            ws.receive_text()
        assert e.value.code == 4401


def test_rejects_missing_hello(setup):
    client, _ = setup
    with client.websocket_connect("/ws") as ws:
        ws.send_text(json.dumps({"t": "sub", "topics": ["system"]}))
        assert json.loads(ws.receive_text())["code"] == "bad_request"


def test_rejects_wrong_proto(setup):
    client, ident = setup
    with client.websocket_connect("/ws") as ws:
        ws.send_text(hello(ident.token, proto=99))
        msg = json.loads(ws.receive_text())
        assert msg["code"] == "proto_unsupported" and msg["supported"] == [1]


def test_handshake_subscribe_and_snapshot(setup):
    client, ident = setup
    with client.websocket_connect("/ws") as ws:
        ws.send_text(hello(ident.token))
        welcome = json.loads(ws.receive_text())
        assert welcome["t"] == "welcome" and welcome["proto"] == 1
        assert "system" in welcome["topics"] and "shortcut.run" in welcome["actions"]
        ws.send_text(json.dumps({"t": "sub", "topics": ["system", "media", "bogus"]}))
        got = set()
        warn = None
        for _ in range(10):
            m = json.loads(ws.receive_text())
            if m["t"] == "evt":
                got.add(m["topic"])
            elif m["t"] == "warn":
                warn = m
            if {"system", "media", "media.art"} <= got and warn:
                break
        assert {"system", "media", "media.art"} <= got  # media implies media.art
        assert warn["topics"] == ["bogus"]


def test_ping_pong_and_actions(setup):
    client, ident = setup
    with client.websocket_connect("/ws") as ws:
        ws.send_text(hello(ident.token))
        ws.receive_text()
        ws.send_text(json.dumps({"t": "ping", "ts": 123}))
        assert recv_until(ws, lambda m: m["t"] == "pong")["ts"] == 123

        ws.send_text(json.dumps({"t": "req", "id": "a1", "action": "shortcut.run",
                                 "params": {"id": "rm -rf /"}}))
        res = recv_until(ws, lambda m: m["t"] == "res")
        assert res["id"] == "a1" and not res["ok"] and res["error"]["code"] == "forbidden"

        ws.send_text(json.dumps({"t": "req", "id": "a2", "action": "nope.nope"}))
        res = recv_until(ws, lambda m: m["t"] == "res")
        assert res["error"]["code"] == "unsupported"

        ws.send_text(json.dumps({"t": "req", "id": "a3", "action": "media.play_pause"}))
        res = recv_until(ws, lambda m: m["t"] == "res")
        assert res["ok"] and res["result"]["playing"] is False


def test_no_topics_before_subscribe(setup):
    client, ident = setup
    with client.websocket_connect("/ws") as ws:
        ws.send_text(hello(ident.token))
        ws.receive_text()
        time.sleep(1.2)  # mock publishes system every second
        ws.send_text(json.dumps({"t": "ping", "ts": 1}))
        assert json.loads(ws.receive_text())["t"] == "pong"
