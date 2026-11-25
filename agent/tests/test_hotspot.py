import json

import httpx
import pytest

from deskpanel_agent.collectors.hotspot import EXPIRED_MSG, HotspotCollector, build, grade, iso_ms
from deskpanel_agent.config import HotspotCfg
from deskpanel_agent.hotspot_login import set_section

SNAP = {
    "device_id": "d_1", "name": "Roof phone", "online": True, "last_seen": "2026-11-24T10:00:00.000Z",
    "paired_at": "2026-11-01T00:00:00.000Z",
    "info": {"manufacturer": "samsung", "model": "SM-M526B", "android_version": "14"},
    "state": {
        "radio": {"net_type": "NR_NSA", "band": 40, "nr": {"band": 78}, "operator": "Jio 5G",
                  "rsrp": -86, "sinr": 14.5, "rsrq": -11, "score": 76.4},
        "net": {"online": True, "rx_bps": 18e6, "tx_bps": 3e6, "ping_ms": 34, "ping_loss_pct": 0, "jitter_ms": 4},
        "power": {"percent": 18, "status": "not_charging", "current_ma": -120, "plug": "usb",
                  "charging_enabled": False, "stop_reason": "heat"},
        "heat": {"battery_c": 42, "cpu_c": 50, "thermal_status": 2},
        "traffic": {"cycle_rx": 100e9, "cycle_tx": 10e9, "today_rx": 2e9, "today_tx": None},
        "system": {"uptime_s": 3600, "agent_uptime_s": 3500, "boot_count": 9, "boot_reason": "reboot"},
        "tether": {"usb_tether_on": True, "clients": [{"ip": "192.168.42.10"}]},
    },
    "state_ts": {"radio": "2026-11-24T10:00:05.000Z", "power": "2026-11-24T09:59:00.000Z"},
}
SETTINGS = {"watchdog": {"temp_warn_c": 40, "temp_stop_charge_c": 45}, "alerts": {"low_battery_pct": 20},
            "plan": {"quota_gb": 200}}
EVENTS = [{"id": "e_1", "ts": "2026-11-24T09:50:00.000Z", "kind": "connectivity", "severity": "warning",
           "message": "Internet down", "device_id": "d_1"}]


def test_build_maps_the_overview():
    d = build(SNAP, SETTINGS, EVENTS, None)
    assert (d.name, d.model, d.online) == ("Roof phone", "samsung SM-M526B · Android 14", True)
    assert (d.net_type, d.band, d.operator) == ("5G NSA", "B40 + n78", "Jio 5G")
    assert (d.score, d.grade) == (76, "excellent")
    assert d.low_battery and d.heat == "warm" and d.thermal == "Moderate"
    assert d.charge_note == "charging paused (heat)" and d.charge_status == "not charging"
    assert d.cycle_used == 110e9 and d.quota == 200e9 and d.today_used == 2e9
    assert d.tether_on and d.clients == 1
    assert d.updated == iso_ms("2026-11-24T10:00:05.000Z") and d.events[0].message == "Internet down"


def test_build_handles_an_empty_snapshot():
    d = build({"online": False, "state": {}}, None, [], None)
    assert d.score is None and d.grade is None and d.quota is None and d.heat == "ok" and not d.low_battery


def test_grades_match_the_dashboard():
    assert [grade(v) for v in (80, 75, 60, 40, 10)] == ["excellent", "excellent", "good", "fair", "poor"]


class FakeStore(dict):
    def set(self, k, v):
        self[k] = v


def _client(handler):
    return httpx.AsyncClient(transport=httpx.MockTransport(handler))


@pytest.mark.asyncio
async def test_poll_reads_device_events_and_settings_with_the_token():
    seen = []

    def handler(req: httpx.Request) -> httpx.Response:
        assert req.headers["authorization"] == "Bearer tok"
        seen.append(req.url.path)
        body = {"/api/devices": [{"device_id": "d_1"}], "/api/device": SNAP,
                "/api/settings": {"device_id": "d_1", "settings": SETTINGS, "version": 3},
                "/api/events": EVENTS}[req.url.path]
        return httpx.Response(200, json=body)

    col = HotspotCollector(FakeStore(), HotspotCfg(server_url="https://hs.example/", token="tok"), client=_client(handler))
    d = await col.poll_once()
    assert d.quota == 200e9 and col.device_id == "d_1"
    assert sorted(seen) == ["/api/device", "/api/devices", "/api/events", "/api/settings"]


@pytest.mark.asyncio
async def test_expired_session_asks_to_sign_in_again():
    col = HotspotCollector(FakeStore(), HotspotCfg(server_url="https://hs.example", token="old", device_id="d_1"),
                           client=_client(lambda r: httpx.Response(401, json={"error": "unauthorized"})))
    with pytest.raises(Exception) as e:
        await col.poll_once()
    assert getattr(e.value, "msg", None) == EXPIRED_MSG


def test_set_section_updates_only_hotspot_keys():
    text = '[slack]\napp_token = "x"\n\n[hotspot]\n# comment\ntoken = "old"\n\n[calendar]\nics_urls = []\n'
    out = set_section(text, "hotspot", {"server_url": "https://a", "token": "new"})
    assert 'app_token = "x"' in out and 'token = "old"' not in out and '# comment' in out
    assert out.index('token = "new"') < out.index("[calendar]")
    assert json.dumps("https://a") in out
    added = set_section("[slack]\n", "hotspot", {"token": "t"})
    assert added.endswith('[hotspot]\ntoken = "t"\n')
