import datetime as dt
import shutil
import subprocess

import pytest

from deskpanel_agent.collectors.media import SEP, parse_tracks, pick
from deskpanel_agent.collectors.network import NetworkCollector, jitter
from deskpanel_agent.collectors.shortcuts import _VOL, ShortcutBackend, ShortcutsCollector
from deskpanel_agent.config import CustomShortcut
from deskpanel_agent.hub import ActionError
from deskpanel_agent.storage import Store


def test_parse_tracks_spotify_and_music():
    out = (f"Spotify{SEP}paused{SEP}Song A{SEP}Artist{SEP}Album{SEP}241000{SEP}75000{SEP}https://i.scdn.co/x{SEP}spotify:track:1\n"
           f"Music{SEP}playing{SEP}Song B{SEP}Band{SEP}LP{SEP}200000{SEP}1500{SEP}{SEP}ABC123\n"
           "garbage line\n")
    tracks = parse_tracks(out)
    assert [t.app for t in tracks] == ["Spotify", "Music"]
    assert tracks[0].duration_ms == 241000 and tracks[0].position_ms == 75000 and not tracks[0].playing
    assert tracks[1].art_url is None and tracks[1].track_id == "Music:ABC123"
    assert pick(tracks).title == "Song B"  # the playing one wins


def test_pick_prefers_spotify_when_neither_playing():
    out = (f"Spotify{SEP}paused{SEP}A{SEP}x{SEP}y{SEP}1{SEP}0{SEP}{SEP}1\n"
           f"Music{SEP}paused{SEP}B{SEP}x{SEP}y{SEP}1{SEP}0{SEP}{SEP}2\n")
    assert pick(parse_tracks(out)).app == "Spotify"
    assert pick([]) is None


def test_volume_settings_regex():
    m = _VOL.search("output volume:44, input volume:0, alert volume:75, output muted:true")
    assert m.groups() == ("44", "0", "true")
    m = _VOL.search("output volume:missing value, input volume:37, alert volume:75, output muted:false")
    assert m.group(1) == "missing value" and m.group(2) == "37"


def test_jitter():
    assert jitter([10, 12, None, 11]) == pytest.approx((2 + 1) / 2)
    assert jitter([None, 5]) is None


def test_usage_store_day_and_month(tmp_path):
    s = Store(tmp_path / "t.db")
    d1, d2, other = dt.date(2026, 11, 2), dt.date(2026, 11, 23), dt.date(2026, 10, 31)
    s.add_usage(100, 50, d1)
    s.add_usage(10, 5, d2)
    s.add_usage(10, 5, d2)
    s.add_usage(999, 0, other)
    assert s.usage_day(d2) == 30
    assert s.usage_month(d2) == 180
    s.set("k", {"a": 1})
    assert s.get("k") == {"a": 1} and s.get("missing", 7) == 7


def test_speedtest_history(tmp_path):
    s = Store(tmp_path / "t.db")
    assert s.last_speedtest() is None
    s.add_speedtest(1, 10.0, 2.0, 9.0)
    s.add_speedtest(2, 20.0, 4.0, 8.0)
    assert s.last_speedtest()["down_bps"] == 20.0


def test_network_online_tracking(tmp_path):
    n = NetworkCollector(Store(tmp_path / "t.db"))
    n.online, n._fails, n.last_drop, n.online_since = True, 0, None, 0
    n.store.set("x", 1)
    for _ in range(2):
        n._track(None)
    assert n.online  # two lost pings aren't a drop
    n._track(None)
    assert not n.online and n.last_drop is not None
    n._track(12.0)
    assert n.online and n.online_since >= n.last_drop


async def test_shortcuts_allowlist(tmp_path):
    custom = [CustomShortcut(id="hello", label="Hello", command=["true"])]
    c = ShortcutsCollector(Store(tmp_path / "t.db"), custom, backend=ShortcutBackend())
    assert [t.id for t in c.tiles()] == ["hello"]  # unsupported built-ins hidden
    assert (await c.run_tile({"id": "hello"}, None))["message"] == "Hello done"
    with pytest.raises(ActionError) as e:
        await c.run_tile({"id": "rm -rf /"}, None)
    assert e.value.code == "forbidden"


@pytest.mark.skipif(shutil.which("osacompile") is None, reason="macOS only")
def test_now_playing_applescript_compiles(tmp_path):
    """A syntax error here silently reads as 'nothing playing' (it happened: `st` is reserved)."""
    from deskpanel_agent.collectors.media import _QUERY

    src = tmp_path / "q.applescript"
    src.write_text(_QUERY)
    r = subprocess.run(["osacompile", "-o", str(tmp_path / "q.scpt"), str(src)], capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
