import asyncio
import json

from deskpanel_agent.adb import is_network_serial, parse_devices
from deskpanel_agent.hub import Client, Hub
from deskpanel_agent.pairing import load_identity


class FakeProvider:
    topics = ("system", "github")
    actions: dict = {}

    def __init__(self):
        self.demand: list[tuple[str, bool]] = []

    async def start(self, hub):
        pass

    async def stop(self):
        pass

    def on_demand(self, topic, wanted):
        self.demand.append((topic, wanted))


async def test_slow_client_only_gets_latest_frame_per_topic():
    sent: list[str] = []
    gate = asyncio.Event()

    async def send(s):
        await gate.wait()
        sent.append(s)

    hub = Hub()
    hub.add_provider(FakeProvider())
    c = Client(send)
    hub.add_client(c)
    hub.subscribe(c, ["system"])
    task = asyncio.create_task(c.writer())
    for i in range(100):
        hub.publish("system", {"i": i})
    c.push('{"t":"res","id":"x"}')
    await asyncio.sleep(0)
    gate.set()
    await asyncio.sleep(0.05)
    task.cancel()
    frames = [json.loads(s) for s in sent]
    assert frames[0]["t"] == "res"  # responses are never dropped and go first
    evts = [f for f in frames if f["t"] == "evt"]
    assert len(evts) == 1 and evts[0]["data"]["i"] == 99 and evts[0]["seq"] == 100


async def test_demand_tracking_with_linger():
    hub = Hub()
    hub.linger_s = 0.05
    p = FakeProvider()
    hub.add_provider(p)
    c = Client(lambda s: asyncio.sleep(0))
    hub.add_client(c)
    hub.subscribe(c, ["github"])
    assert ("github", True) in p.demand
    hub.subscribe(c, ["system"])
    assert ("github", False) not in p.demand  # lingers before stopping
    await asyncio.sleep(0.1)
    assert ("github", False) in p.demand


async def test_snapshot_sent_on_subscribe():
    sent = []

    async def send(s):
        sent.append(json.loads(s))

    hub = Hub()
    hub.add_provider(FakeProvider())
    hub.publish("system", {"cpu": 1})
    c = Client(send)
    hub.add_client(c)
    hub.subscribe(c, ["system"])
    t = asyncio.create_task(c.writer())
    await asyncio.sleep(0.01)
    t.cancel()
    assert sent and sent[0]["data"] == {"cpu": 1}


def test_parse_adb_devices():
    out = ("* daemon started successfully\nList of devices attached\n"
           "R58N123ABC\tdevice usb:1-1 product:x model:Pixel_8\n"
           "emulator-5554\toffline\nZY22\tunauthorized\n")
    assert parse_devices(out) == {"R58N123ABC": "device", "emulator-5554": "offline", "ZY22": "unauthorized"}


def test_identity_persists_and_token_check():
    a = load_identity()
    b = load_identity()
    assert a == b and len(a.token) >= 40
    assert a.check(a.token) and not a.check("x") and not a.check(None)
    c = load_identity(reset_token=True)
    assert c.agent_id == a.agent_id and c.token != a.token


def test_launchd_plist_shape():
    from deskpanel_agent.startup import LABEL, plist

    p = plist(tray=True)
    assert p["Label"] == LABEL and p["RunAtLoad"] is True
    assert p["ProgramArguments"][1:] == ["-m", "deskpanel_agent", "run", "--tray"]
    assert p["KeepAlive"] == {"SuccessfulExit": False}  # Quit from the menu stays quit
    assert "/opt/homebrew/bin" in p["EnvironmentVariables"]["PATH"]
    assert plist(tray=False)["ProgramArguments"][-1] == "run"


def test_config_file_is_private(tmp_path):
    import os
    import stat

    from deskpanel_agent.config import load_config

    p = tmp_path / "config.toml"
    p.write_text('[github]\ntoken = "ghp_x"\n')
    os.chmod(p, 0o644)
    cfg = load_config(p)
    assert cfg.github.token == "ghp_x"
    assert stat.S_IMODE(p.stat().st_mode) == 0o600


def test_wireless_debugging_devices_get_no_reverse():
    assert is_network_serial("192.168.1.23:37001")
    assert is_network_serial("adb-R58M12ABCDE-AbC123._adb-tls-connect._tcp")
    assert not is_network_serial("R58M12ABCDE")
    assert not is_network_serial("emulator-5554")
