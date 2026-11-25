import json
import sys

import pytest

from deskpanel_agent.hub import ActionError, Client, Hub
from deskpanel_agent.mouse_share import MouseShare

mac_only = pytest.mark.skipif(sys.platform != "darwin", reason="macOS event tap")


async def _noop(_frame: str) -> None:
    pass


@pytest.fixture
def setup(monkeypatch):
    """A MouseShare in a hub with one phone; the real event tap is stubbed out."""
    hub, ms, phone = Hub(), MouseShare(), Client(_noop, "phone")
    started = []
    monkeypatch.setattr(ms, "_start_tap", lambda: started.append(1) or setattr(ms, "_tap", object()) or True)
    monkeypatch.setattr(ms, "_stop_tap", lambda: setattr(ms, "_tap", None))
    hub.add_provider(ms)
    hub.add_client(phone)
    return hub, ms, phone, started


async def _call(hub, client, params):
    await hub.start()
    await hub.run_action(client, "1", "mouse.setup", params)
    return json.loads(client._fifo.pop())


@mac_only
async def test_setup_starts_watching_for_that_phone(setup):
    hub, ms, phone, started = setup
    res = await _call(hub, phone, {"on": True, "rect": [150, 1080, 512, 230], "w": 1024, "h": 461})
    assert res["ok"] and res["result"] == {"active": True}
    assert ms.client is phone and ms.rect.y == 1080 and started == [1]


@mac_only
async def test_off_and_disconnect_stop_it(setup):
    hub, ms, phone, _ = setup
    await _call(hub, phone, {"on": True, "rect": [150, 1080, 512, 230], "w": 1024, "h": 461})
    hub.remove_client(phone)
    assert ms.client is None and ms._tap is None


async def test_bad_requests_are_refused(setup):
    hub, ms, phone, _ = setup
    assert (await _call(hub, phone, {"on": True, "w": 1024}))["error"]["code"] == "bad_request"
    assert (await _call(hub, phone, {"on": False}))["result"] == {"active": False}


def test_frames_go_only_to_the_phone_that_asked():
    ms, phone = MouseShare(), Client(_noop, "phone")
    ms.client = phone
    ms._push({"t": "ptr", "k": "down"})
    assert json.loads(phone._fifo.pop()) == {"t": "ptr", "k": "down"}
    phone.closed = True
    ms._push({"t": "ptr", "k": "up"})
    assert not phone._fifo


class FakeQuartz:
    """Just enough of Quartz for the park / hide / show bookkeeping."""

    def __init__(self):
        self.hidden, self.visible_after_hide, self.warps, self.assoc = 0, False, [], []

    def CGMainDisplayID(self):
        return 1

    def CGDisplayHideCursor(self, _):
        self.hidden += 1
        return 0

    def CGDisplayShowCursor(self, _):
        self.hidden -= 1

    def CGCursorIsVisible(self):
        return self.hidden <= 0 or self.visible_after_hide

    def CGPointMake(self, x, y):
        return (x, y)

    def CGWarpMouseCursorPosition(self, p):
        self.warps.append(p)

    def CGAssociateMouseAndMouseCursorPosition(self, v):
        self.assoc.append(v)


def test_cursor_is_re_hidden_kept_parked_and_fully_shown_again(monkeypatch):
    import types

    import deskpanel_agent.mouse_share as m

    q = FakeQuartz()
    monkeypatch.setitem(sys.modules, "Quartz", q)
    monkeypatch.setattr(m, "_allow_background_cursor", lambda: None)
    ms = MouseShare()
    ms._park = (100.0, 1439.0)
    ms._hide_cursor()
    q.visible_after_hide = True           # another app showed it again
    ms._keep_parked(types.SimpleNamespace(x=300.0, y=900.0), force=True)  # and it drifted
    assert q.warps == [(100.0, 1439.0)] and q.assoc == [False]
    assert ms._hides == 2                 # hidden again
    q.visible_after_hide = False
    ms._show_cursor()
    assert q.hidden == 0 and ms._hides == 0 and ms._park is None
