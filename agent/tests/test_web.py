"""The desk web page server: local Host only, own origin only, its own key."""
import json

import pytest
from fastapi.testclient import TestClient
from starlette.websockets import WebSocketDisconnect

from deskpanel_agent.hub import Hub
from deskpanel_agent.pairing import desk_url, load_identity
from deskpanel_agent.server import WEB_DIR, create_web_app

PORT = 8766
HOST = {"host": f"127.0.0.1:{PORT}"}
ORIGIN = {**HOST, "origin": f"http://127.0.0.1:{PORT}"}


@pytest.fixture
def web(tmp_path):
    (tmp_path / "index.html").write_text("<!doctype html><title>DeskPanel</title>")
    (tmp_path / "app.js").write_text("1")
    (tmp_path / "notes.txt").write_text("secret")
    ident = load_identity()
    with TestClient(create_web_app(Hub(), ident, PORT, web_dir=tmp_path)) as c:
        yield c, ident


def hello(token):
    return json.dumps({"t": "hello", "proto": 1, "token": token,
                       "client": {"name": "desk", "platform": "web", "app_version": "0"}})


def test_serves_the_page_with_a_strict_policy(web):
    c, _ = web
    r = c.get("/", headers=HOST)
    assert r.status_code == 200 and "DeskPanel" in r.text
    assert "script-src 'self'" in r.headers["content-security-policy"]
    assert c.get("/app.js", headers={"host": f"localhost:{PORT}"}).status_code == 200


def test_rejects_other_hosts_and_files(web):
    c, _ = web
    assert c.get("/", headers={"host": f"evil.example:{PORT}"}).status_code == 421  # DNS rebinding
    assert c.get("/notes.txt", headers=HOST).status_code == 404  # not a page file type
    assert c.get("/../pyproject.toml", headers=HOST).status_code == 404
    assert c.get("/%2e%2e/pairing.py", headers=HOST).status_code == 404


def test_socket_needs_own_origin_and_the_web_key(web):
    c, ident = web
    with pytest.raises(WebSocketDisconnect) as e, c.websocket_connect(
            "/ws", headers={**HOST, "origin": "https://evil.example"}) as ws:
        ws.receive_text()
    assert e.value.code == 4403
    with c.websocket_connect("/ws", headers=ORIGIN) as ws:  # the phone's key is not accepted
        ws.send_text(hello(ident.token))
        assert json.loads(ws.receive_text())["code"] == "auth_failed"
    with c.websocket_connect("/ws", headers=ORIGIN) as ws:
        ws.send_text(hello(ident.web_token))
        assert json.loads(ws.receive_text())["t"] == "welcome"


def test_keys_differ_and_url_keeps_key_in_fragment():
    ident = load_identity()
    assert ident.web_token and ident.web_token != ident.token
    assert desk_url(ident, PORT) == f"http://127.0.0.1:{PORT}/#k={ident.web_token}"


def test_page_files_ship_with_the_agent():
    assert (WEB_DIR / "index.html").is_file()
