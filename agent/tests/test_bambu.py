"""Bambu Lab printer collector: parser, backend wiring (fake MQTT client), collector logic."""
import asyncio
import copy
import json

import pytest

from deskpanel_agent.collectors.printer import (
    BambuBackend, PrinterBackend, PrinterCollector, merge_report, to_printer_data,
)
from deskpanel_agent.collectors.printer.bambu import PUSHALL
from deskpanel_agent.collectors.printer.bambu_parse import (
    error_text, hms_code, map_state, model_from_serial, speed_name, tray_color,
)
from deskpanel_agent.config import BambuCfg
from deskpanel_agent.hub import ActionError
from deskpanel_agent.protocol import PrinterData

SERIAL = "00M09A350100123"
CFG = BambuCfg(host="192.168.1.50", serial=SERIAL, access_code="12345678", name="X1 Carbon")

# ------------------------------------------------------------------ fixtures

# Trimmed but structurally faithful X1C `pushall` reply (field names and value types as the
# printer sends them: many numbers are strings, colours are RRGGBBAA, empty tray = {"id"}).
PUSHALL_REPORT = {
    "print": {
        "command": "push_status",
        "msg": 0,
        "sequence_id": "0",
        "gcode_state": "RUNNING",
        "gcode_file": "/data/Metadata/plate_1.gcode",
        "subtask_name": "Desk_Organizer",
        "mc_print_stage": "2",
        "mc_percent": 47,
        "mc_remaining_time": 48,
        "layer_num": 112,
        "total_layer_num": 240,
        "spd_lvl": 2,
        "spd_mag": 100,
        "nozzle_temper": 219.84375,
        "nozzle_target_temper": 220,
        "bed_temper": 54.96875,
        "bed_target_temper": 55,
        "chamber_temper": 34,
        "cooling_fan_speed": "15",
        "wifi_signal": "-52dBm",
        "print_error": 0,
        "hms": [],
        "lights_report": [{"node": "chamber_light", "mode": "on"}],
        "ams": {
            "ams_exist_bits": "1",
            "tray_exist_bits": "f",
            "tray_is_bbl_bits": "f",
            "tray_now": "2",
            "tray_pre": "2",
            "tray_tar": "2",
            "version": 4,
            "ams": [{
                "id": "0",
                "humidity": "4",
                "temp": "24.1",
                "tray": [
                    {"id": "0", "tray_type": "PLA", "tray_sub_brands": "PLA Basic",
                     "tray_color": "F1F1EEFF", "tray_info_idx": "GFA00", "remain": 80,
                     "nozzle_temp_min": "190", "nozzle_temp_max": "230"},
                    {"id": "1", "tray_type": "PLA", "tray_sub_brands": "PLA Matte",
                     "tray_color": "1D1E21FF", "tray_info_idx": "GFA01", "remain": 35},
                    {"id": "2", "tray_type": "PETG", "tray_sub_brands": "PETG HF",
                     "tray_color": "F5A623FF", "tray_info_idx": "GFG02", "remain": 60},
                    {"id": "3", "tray_type": "PLA", "tray_sub_brands": "",
                     "tray_color": "3b82f6ff", "tray_info_idx": "GFL99", "remain": -1},
                ],
            }],
        },
        "vt_tray": {"id": "254", "tray_type": "", "tray_color": "00000000"},
        "upgrade_state": {"sequence_id": 0, "status": "IDLE"},
    }
}

# Partial deltas, as the printer streams them between full reports.
DELTA_TEMPS = {"print": {"command": "push_status", "msg": 1, "sequence_id": "1771",
                         "nozzle_temper": 220.1, "bed_temper": 55.0}}
DELTA_PROGRESS = {"print": {"command": "push_status", "msg": 1, "sequence_id": "1772",
                            "mc_percent": 48, "mc_remaining_time": 46, "layer_num": 115}}
DELTA_TRAY = {"print": {"command": "push_status", "msg": 1, "sequence_id": "1773",
                        "ams": {"ams": [{"id": "0", "tray": [{"id": "1", "remain": 30}]}]}}}
DELTA_TRAY_UNLOADED = {"print": {"command": "push_status", "msg": 1,
                                 "ams": {"tray_exist_bits": "d",
                                         "ams": [{"id": "0", "tray": [{"id": "1"}]}]}}}
DELTA_PAUSE_RUNOUT = {"print": {"command": "push_status", "msg": 1, "gcode_state": "PAUSE",
                                "print_error": 0x07008011,
                                "hms": [{"attr": 0x07000300, "code": 0x00020001}]}}
GCODE_ACK = {"print": {"command": "gcode_line", "sequence_id": "5", "result": "success",
                       "param": "M400\n"}}
VERSION_INFO = {"info": {"command": "get_version", "module": [{"name": "ota", "sw_ver": "01.08.05.00"}]}}


def full_state() -> dict:
    return merge_report({}, PUSHALL_REPORT)


# ------------------------------------------------------------------ merge


def test_merge_full_report_then_deltas_keep_other_fields():
    s = full_state()
    for d in (DELTA_TEMPS, DELTA_PROGRESS):
        s = merge_report(s, d)
    assert s["nozzle_temper"] == 220.1 and s["mc_percent"] == 48 and s["layer_num"] == 115
    # untouched fields survive the deltas
    assert s["subtask_name"] == "Desk_Organizer"
    assert s["total_layer_num"] == 240 and s["chamber_temper"] == 34
    assert s["bed_target_temper"] == 55
    assert len(s["ams"]["ams"][0]["tray"]) == 4 and s["ams"]["tray_now"] == "2"


def test_merge_ams_trays_by_id():
    s = merge_report(full_state(), DELTA_TRAY)
    trays = s["ams"]["ams"][0]["tray"]
    assert [t["id"] for t in trays] == ["0", "1", "2", "3"]
    assert trays[1]["remain"] == 30
    assert trays[1]["tray_type"] == "PLA" and trays[1]["tray_color"] == "1D1E21FF"  # kept
    assert trays[0]["tray_color"] == "F1F1EEFF"
    assert s["ams"]["ams"][0]["humidity"] == "4"


def test_merge_id_only_tray_means_empty():
    s = merge_report(full_state(), DELTA_TRAY_UNLOADED)
    assert s["ams"]["ams"][0]["tray"][1] == {"id": "1"}
    slots = to_printer_data(s, "X").ams
    assert slots[1].type is None and slots[1].color is None
    assert slots[0].type == "PLA"


def test_merge_is_pure_and_ignores_non_status_messages():
    s = full_state()
    before = copy.deepcopy(s)
    out = merge_report(s, DELTA_TRAY)
    assert s == before and out is not s
    assert merge_report(s, GCODE_ACK) is s
    assert merge_report(s, VERSION_INFO) is s
    assert merge_report(s, {"print": "garbage"}) is s


def test_merge_replaces_plain_lists():
    s = merge_report(full_state(), {"print": {"hms": [{"attr": 1, "code": 2}]}})
    s = merge_report(s, {"print": {"hms": []}})
    assert s["hms"] == []


def test_merge_appends_new_ams_unit():
    unit1 = {"id": "1", "tray": [{"id": "0", "tray_type": "ABS", "tray_color": "FF0000FF"}]}
    s = merge_report(full_state(), {"print": {"ams": {"ams_exist_bits": "3", "tray_exist_bits": "1f",
                                                      "ams": [unit1]}}})
    assert [u["id"] for u in s["ams"]["ams"]] == ["0", "1"]
    slot4 = [a for a in to_printer_data(s, "X").ams if a.slot == 4][0]
    assert slot4.type == "ABS" and slot4.color == "#FF0000"


# ------------------------------------------------------------------ mapping


@pytest.mark.parametrize("gs,want", [
    ("IDLE", "idle"), ("PREPARE", "printing"), ("RUNNING", "printing"), ("SLICING", "printing"),
    ("PAUSE", "paused"), ("FINISH", "finished"), ("FAILED", "error"), ("WHATEVER", "idle"),
    (None, "idle"), ("running", "printing"),
])
def test_state_mapping(gs, want):
    assert map_state(gs) == want


def test_cancelled_job_is_idle_not_error():
    assert map_state("FAILED", 0x0300400C) == "idle"
    s = merge_report(full_state(), {"print": {"gcode_state": "FAILED", "print_error": 50348044}})
    d = to_printer_data(s, "X")
    assert d.state == "idle" and d.error is None and d.job is None


@pytest.mark.parametrize("lvl,want", [(1, "silent"), (2, "standard"), (3, "sport"),
                                      (4, "ludicrous"), ("3", "sport"), (0, None), (None, None), (9, None)])
def test_speed_mapping(lvl, want):
    assert speed_name(lvl) == want


@pytest.mark.parametrize("raw,want", [
    ("F1F1EEFF", "#F1F1EE"), ("3b82f6ff", "#3B82F6"), ("000000FF", "#000000"),  # black is a colour
    ("00000000", None), ("FF000000", None),  # fully transparent = empty tray
    ("A1B2C3", "#A1B2C3"), ("", None), (None, None), ("ZZZZZZFF", None), ("123", None),
])
def test_colour_conversion(raw, want):
    assert tray_color(raw) == want


def test_to_printer_data_full_report():
    d = to_printer_data(full_state(), "X1 Carbon", model="X1C")
    assert isinstance(d, PrinterData) and d.status == "ok"
    assert d.kind == "bambu" and d.name == "X1 Carbon" and d.model == "X1C"
    assert d.state == "printing"
    j = d.job
    assert (j.name, j.progress_pct, j.remaining_min, j.layer, j.total_layers, j.speed) == \
        ("Desk_Organizer", 47.0, 48, 112, 240, "standard")
    t = d.temps
    assert (t.nozzle, t.nozzle_target, t.bed, t.bed_target, t.chamber) == (219.8, 220, 55.0, 55, 34)
    assert [(a.slot, a.type, a.color, a.active) for a in d.ams] == [
        (0, "PLA", "#F1F1EE", False), (1, "PLA", "#1D1E21", False),
        (2, "PETG", "#F5A623", True), (3, "PLA", "#3B82F6", False)]
    assert d.ams[2].name == "PETG HF" and d.ams[3].name is None
    assert d.error is None
    # serialises into the wire shape the phone expects
    dump = d.model_dump(mode="json")
    assert dump["job"]["remaining_min"] == 48 and dump["ams"][2]["active"] is True


def test_active_tray_global_index_and_specials():
    s = merge_report(full_state(), {"print": {"ams": {"tray_now": "1"}}})
    assert [a.slot for a in to_printer_data(s, "X").ams if a.active] == [1]
    s = merge_report(s, {"print": {"ams": {"tray_now": "255"}}})  # nothing loaded
    assert not any(a.active for a in to_printer_data(s, "X").ams)
    # second AMS unit, tray 2 -> global slot 6
    unit1 = {"id": "1", "tray": [{"id": str(i), "tray_type": "PLA", "tray_color": "FFFFFFFF"} for i in range(4)]}
    s = merge_report(s, {"print": {"ams": {"ams_exist_bits": "3", "tray_exist_bits": "ff",
                                           "tray_now": "6", "ams": [unit1]}}})
    d = to_printer_data(s, "X")
    assert [a.slot for a in d.ams] == list(range(8))
    assert [a.slot for a in d.ams if a.active] == [6]


def test_external_spool():
    s = merge_report(full_state(), {"print": {
        "ams": {"tray_now": "254"},
        "vt_tray": {"id": "254", "tray_type": "TPU", "tray_color": "00FF00FF"}}})
    d = to_printer_data(s, "X")
    ext = d.ams[-1]
    assert (ext.slot, ext.type, ext.color, ext.active, ext.name) == (254, "TPU", "#00FF00", True, "External spool")
    assert sum(a.active for a in d.ams) == 1
    # Not feeding from it and an AMS is present: not listed.
    s = merge_report(s, {"print": {"ams": {"tray_now": "0"}}})
    assert [a.slot for a in to_printer_data(s, "X").ams] == [0, 1, 2, 3]


def test_no_ams_shows_external_spool():
    s = merge_report({}, {"print": {"gcode_state": "IDLE", "ams": {"ams": [], "tray_now": "255"},
                                    "vt_tray": {"id": "254", "tray_type": "PLA", "tray_color": "FFFFFFFF"}}})
    assert [(a.slot, a.type, a.active) for a in to_printer_data(s, "X").ams] == [(254, "PLA", False)]


def test_disconnected_ams_unit_hidden():
    unit1 = {"id": "1", "tray": [{"id": "0", "tray_type": "ABS", "tray_color": "FF0000FF"}]}
    s = merge_report(full_state(), {"print": {"ams": {"ams_exist_bits": "3", "ams": [unit1]}}})
    assert len(to_printer_data(s, "X").ams) == 5
    s = merge_report(s, {"print": {"ams": {"ams_exist_bits": "1"}}})
    assert len(to_printer_data(s, "X").ams) == 4


def test_error_mapping():
    assert hms_code({"attr": 0x07000300, "code": 0x00020001}) == "0700_0300_0002_0001"
    s = merge_report(full_state(), DELTA_PAUSE_RUNOUT)
    d = to_printer_data(s, "X")
    assert d.state == "paused"  # a paused job with an error is still "paused"
    assert d.error == "Print error 0700_8011 · HMS 0700_0300_0002_0001 (serious)"
    assert d.job is not None and d.job.layer == 112

    # most severe HMS first; info-level ignored
    st = {"hms": [{"attr": 0x05000100, "code": 0x00030002},
                  {"attr": 0x03000100, "code": 0x00010007},
                  {"attr": 0x0C000100, "code": 0x00040001}]}
    assert error_text(st) == "HMS 0300_0100_0001_0007 (fatal) +1 more"
    assert error_text({"hms": [{"attr": 1, "code": 0x00040001}]}) is None
    assert error_text({"print_error": 0, "hms": []}) is None

    s = merge_report(full_state(), {"print": {"gcode_state": "FAILED", "print_error": 0x0500C011}})
    d = to_printer_data(s, "X")
    assert d.state == "error" and d.error == "Print error 0500_C011"

    # cleared again by later deltas
    s = merge_report(s, {"print": {"gcode_state": "IDLE", "print_error": 0, "hms": []}})
    d = to_printer_data(s, "X")
    assert d.state == "idle" and d.error is None and d.job is None


def test_finished_job_has_zero_remaining():
    s = merge_report(full_state(), {"print": {"gcode_state": "FINISH", "mc_percent": 100,
                                              "mc_remaining_time": 1, "layer_num": 240}})
    d = to_printer_data(s, "X")
    assert d.state == "finished" and d.job.progress_pct == 100 and d.job.remaining_min == 0


def test_empty_state_is_valid_and_model_from_serial():
    d = to_printer_data({}, "X1 Carbon")
    assert d.state == "idle" and d.job is None and d.ams == [] and d.temps.nozzle is None
    assert model_from_serial("00M09A350100123") == "X1C"
    assert model_from_serial("01P00A000000000") is None and model_from_serial(None) is None


# ------------------------------------------------------------------ backend with a fake MQTT client


class FakeClient:
    """Stands in for paho.mqtt.client.Client: records calls; tests fire the callbacks."""

    def __init__(self, access_code):
        self.access_code = access_code
        self.subscribed, self.published, self.calls = [], [], []

    def connect_async(self, host, port, keepalive=60):
        self.calls.append(("connect_async", host, port))

    def loop_start(self):
        self.calls.append(("loop_start",))

    def loop_stop(self):
        self.calls.append(("loop_stop",))

    def disconnect(self):
        self.calls.append(("disconnect",))

    def subscribe(self, topic):
        self.subscribed.append(topic)

    def publish(self, topic, payload):
        self.published.append((topic, json.loads(payload)))

        class Info:
            rc = 0
        return Info()


class Msg:
    def __init__(self, obj):
        self.payload = json.dumps(obj).encode()


class Clock:
    def __init__(self, t=1000.0):
        self.t = t

    def __call__(self):
        return self.t


async def _drain():
    for _ in range(3):
        await asyncio.sleep(0)


async def test_backend_connect_subscribe_pushall_and_merge():
    clock = Clock()
    clients = []
    b = BambuBackend(CFG, clock=clock, client_factory=lambda code: clients.append(FakeClient(code)) or clients[-1])
    notified = []
    await b.start(lambda: notified.append(1))
    c = clients[0]
    assert c.access_code == "12345678"
    assert ("connect_async", "192.168.1.50", 8883) in c.calls and ("loop_start",) in c.calls
    assert b.snapshot() is None

    c.on_connect(c, None, {}, 0, None)
    await _drain()
    assert b.connected and b.error is None
    assert c.subscribed == [f"device/{SERIAL}/report"]
    assert c.published == [(f"device/{SERIAL}/request", PUSHALL)]
    assert PUSHALL == {"pushing": {"sequence_id": "0", "command": "pushall"}}

    c.on_message(c, None, Msg(PUSHALL_REPORT))
    clock.t += 5
    c.on_message(c, None, Msg(DELTA_PROGRESS))
    c.on_message(c, None, type("M", (), {"payload": b"\xff not json"})())
    await _drain()
    assert b.last_report_at == 1005.0
    d = b.snapshot()
    assert d.name == "X1 Carbon" and d.model == "X1C" and d.job.layer == 115 and d.ams[2].active
    assert notified

    await b.refresh()
    assert c.published[-1] == (f"device/{SERIAL}/request", PUSHALL)

    c.on_disconnect(c, None, {}, 7, None)
    await _drain()
    assert not b.connected
    with pytest.raises(ActionError):
        await b.refresh()

    await b.stop()
    assert ("disconnect",) in c.calls and ("loop_stop",) in c.calls


async def test_backend_auth_failure_sets_error():
    clients = []
    b = BambuBackend(CFG, client_factory=lambda code: clients.append(FakeClient(code)) or clients[-1])
    await b.start(lambda: None)
    c = clients[0]
    c.on_connect(c, None, {}, 5, None)  # CONNACK "not authorized"
    await _drain()
    assert not b.connected and "access code" in b.error
    assert c.subscribed == []
    c.on_connect(c, None, {}, 0, None)
    await _drain()
    assert b.connected and b.error is None


async def test_backend_missing_paho_reports_error():
    def boom(code):
        raise ImportError("no paho")

    b = BambuBackend(CFG, client_factory=boom)
    await b.start(lambda: None)
    assert "paho-mqtt" in b.error


def test_backend_missing_settings():
    assert BambuBackend(CFG).missing_settings() == []
    b = BambuBackend(BambuCfg(host="10.0.0.2", serial=" ", access_code=None))
    assert b.missing_settings() == ["serial", "access_code"]
    hint = b.setup_hint()
    assert "host" in hint and "serial" in hint and "access_code" in hint
    assert "Missing: bambu.serial, bambu.access_code" in hint


# ------------------------------------------------------------------ collector with a fake backend


class FakeBackend(PrinterBackend):
    kind = "fake"
    address = "192.168.1.50"

    def __init__(self, missing=()):
        super().__init__()
        self.missing = list(missing)
        self.data: PrinterData | None = None
        self.refreshed = 0
        self.started = False

    def missing_settings(self):
        return self.missing

    def setup_hint(self):
        return "set host, serial and access_code"

    async def start(self, notify):
        self.started = True
        self.notify = notify

    async def stop(self):
        self.started = False

    async def refresh(self):
        if not self.connected:
            raise ActionError("failed", "not connected")
        self.refreshed += 1

    def snapshot(self):
        return self.data.model_copy(deep=True) if self.data else None


class FakeHub:
    def __init__(self):
        self.events = []

    def publish(self, topic, data):
        self.events.append((topic, data))


def make(backend, clock):
    col = PrinterCollector(BambuCfg(name="X1 Carbon"), backend=backend, clock=clock, min_interval=0)
    hub = FakeHub()
    col.hub = hub
    return col, hub


async def test_collector_unconfigured():
    col = PrinterCollector(BambuCfg(host="192.168.1.50"))  # real BambuBackend, no serial/code
    hub = FakeHub()
    await col.start(hub)
    assert hub.events == [("printer", {"status": "unconfigured", "message": col.backend.setup_hint()})]
    msg = hub.events[0][1]["message"]
    assert "serial" in msg and "access_code" in msg and "host (the printer's IP address)" in msg
    assert col.backend.client is None  # never tried to connect
    with pytest.raises(ActionError) as e:
        await col.refresh({}, None)
    assert e.value.code == "unconfigured"
    await col.stop()


async def test_collector_offline_timeout_keeps_last_values():
    clock = Clock()
    b = FakeBackend()
    col, hub = make(b, clock)
    await col.setup()
    assert b.started
    assert hub.events[-1][1]["status"] == "starting"

    b.connected = True
    b.data = to_printer_data(full_state(), "X1 Carbon", "X1C")
    b.last_report_at = clock.t
    col.publish_if_changed()
    live = hub.events[-1][1]
    assert live["state"] == "printing" and live["job"]["layer"] == 112

    n = len(hub.events)
    clock.t += 59
    col.publish_if_changed()
    assert len(hub.events) == n  # unchanged -> not republished

    clock.t += 2  # 61 s since the last report
    col.publish_if_changed()
    off = hub.events[-1][1]
    assert off["state"] == "offline" and off["status"] == "ok"
    assert off["job"]["layer"] == 112 and off["temps"]["nozzle"] == 219.8  # last values kept
    assert "No status" in off["message"]

    b.last_report_at = clock.t  # report arrives again
    col.publish_if_changed()
    assert hub.events[-1][1]["state"] == "printing" and hub.events[-1][1]["message"] is None


async def test_collector_disconnect_is_offline_immediately():
    clock = Clock()
    b = FakeBackend()
    col, hub = make(b, clock)
    await col.setup()
    b.connected, b.last_report_at = True, clock.t
    b.data = to_printer_data(full_state(), "X1 Carbon")
    col.publish_if_changed()
    b.connected = False
    col.publish_if_changed()
    d = hub.events[-1][1]
    assert d["state"] == "offline" and "reconnecting" in d["message"] and d["ams"][2]["active"]

    b.error = "The printer rejected the access code."
    col.publish_if_changed()
    d = hub.events[-1][1]
    assert d["status"] == "error" and d["state"] == "offline" and d["message"] == b.error


async def test_collector_never_reached():
    clock = Clock()
    b = FakeBackend()
    col, hub = make(b, clock)
    await col.setup()
    assert hub.events[-1][1] == {"status": "starting", "message": "Connecting to X1 Carbon at 192.168.1.50…"}
    clock.t += 61
    col.publish_if_changed()
    d = hub.events[-1][1]
    assert d["state"] == "offline" and d["status"] == "ok" and "Can't reach" in d["message"]
    b.error = "The printer rejected the access code."
    col.publish_if_changed()
    assert hub.events[-1][1] == {"status": "error", "message": b.error}


async def test_collector_run_loop_publishes_on_notify_and_refresh_action():
    clock = Clock()
    b = FakeBackend()
    col, hub = make(b, clock)
    await col.start(hub)
    try:
        b.connected, b.last_report_at = True, clock.t
        b.data = to_printer_data(full_state(), "X1 Carbon")
        b.notify()
        for _ in range(20):
            await asyncio.sleep(0)
            if hub.events[-1][1].get("state") == "printing":
                break
        assert hub.events[-1][1]["state"] == "printing"
        assert await col.actions["printer.refresh"]({}, None) == {}
        assert b.refreshed == 1
        b.connected = False
        with pytest.raises(ActionError):
            await col.refresh({}, None)
    finally:
        await col.stop()
    assert not b.started


def test_published_payloads_validate_against_protocol():
    d = to_printer_data(merge_report(full_state(), DELTA_PAUSE_RUNOUT), "X1 Carbon", "X1C")
    PrinterData.model_validate(d.model_dump(mode="json"))
