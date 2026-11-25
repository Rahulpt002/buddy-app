import datetime as dt
import json
import os
import subprocess
import sys
from pathlib import Path

from deskpanel_agent.collectors.claude import TranscriptIndex, model_family, parse_line, read_limits


def line(mid, ts, model="claude-opus-5-5", inp=10, out=5, cc=100, cr=1000, typ="assistant"):
    return json.dumps({"type": typ, "timestamp": ts, "message": {"id": mid, "model": model, "usage": {
        "input_tokens": inp, "output_tokens": out, "cache_creation_input_tokens": cc, "cache_read_input_tokens": cr}}})


def iso(t):
    return t.astimezone(dt.timezone.utc).isoformat().replace("+00:00", "Z")


def test_parse_line():
    r = parse_line(line("m1", "2026-11-23T07:27:06.988Z"))
    assert r[0] == "m1" and r[2] == "claude-opus-5-5" and r[3] == 1115 and r[4] == 5
    assert parse_line(line("m2", "2026-11-23T07:27:06Z", model="<synthetic>")) is None
    assert parse_line(line("m3", "2026-11-23T07:27:06Z", typ="user")) is None
    assert parse_line('{"type":"assistant"') is None
    assert model_family("claude-opus-5-5") == "opus" and model_family("claude-3-5-sonnet-20241022") == "sonnet"


def test_index_dedupes_and_tails_incrementally(tmp_path):
    root = tmp_path / "projects" / "p"
    root.mkdir(parents=True)
    f = root / "s.jsonl"
    now = dt.datetime.now().astimezone()
    # Same message id written twice (one line per content block) + a partial last line.
    f.write_text(line("a", iso(now)) + "\n" + line("a", iso(now)) + "\n" + line("b", iso(now))[:30])
    idx = TranscriptIndex(tmp_path / "db.sqlite", tmp_path / "projects")
    assert idx.scan(first=True) == 1
    s = idx.summary(now)
    assert s["messages"] == 1 and s["tokens"] == 1115 and s["output"] == 5
    # Finish the partial line and append another: only the new bytes are read.
    with f.open("a") as fh:
        fh.write(line("b", iso(now))[30:] + "\n" + line("c", iso(now - dt.timedelta(days=2)), model="claude-haiku-5-5") + "\n")
    assert idx.scan() == 2
    s = idx.summary(now)
    assert s["messages"] == 2  # b today; c two days ago
    assert s["days"][-1]["tokens"] == 2230 and s["days"][-3]["tokens"] == 1115
    assert [m["family"] for m in s["models"]] == ["opus"]
    assert idx.scan() == 0  # nothing new


def test_old_files_skipped_on_first_scan(tmp_path):
    root = tmp_path / "projects"
    root.mkdir()
    old = root / "old.jsonl"
    old.write_text(line("x", "2020-01-01T00:00:00Z") + "\n")
    t = 1_600_000_000
    os.utime(old, (t, t))
    idx = TranscriptIndex(tmp_path / "db.sqlite", root)
    assert idx.scan(first=True) == 0


def test_read_limits_documented_schema(tmp_path):
    p = tmp_path / "claude_limits.json"
    now_s = 1_800_000_000
    p.write_text(json.dumps({"updated_at": 1, "rate_limits": {
        "five_hour": {"used_percentage": 23.5, "resets_at": now_s + 3600},
        "seven_day": {"used_percentage": 41.2, "resets_at": now_s - 10}}}))
    lim = read_limits(p, now_ms=now_s * 1000)
    assert lim.five_hour.used_pct == 23.5 and lim.five_hour.resets_at == (now_s + 3600) * 1000
    assert not lim.five_hour.expired and lim.seven_day.expired
    p.write_text(json.dumps({"rate_limits": {}}))
    assert read_limits(p) is None
    assert read_limits(tmp_path / "missing.json") is None


def test_statusline_bridge_saves_limits_and_prints(tmp_path):
    script = Path(__file__).resolve().parents[1] / "deskpanel_agent" / "statusline.py"
    stdin = json.dumps({"model": {"display_name": "Opus"}, "rate_limits": {
        "five_hour": {"used_percentage": 38, "resets_at": 1738425600},
        "seven_day": {"used_percentage": 61.4, "resets_at": 1738857600}}})
    env = {**os.environ, "DESKPANEL_HOME": str(tmp_path)}
    r = subprocess.run([sys.executable, str(script)], input=stdin, text=True, capture_output=True, env=env)
    assert r.returncode == 0 and r.stdout.strip() == "Opus · 5h 38% · week 61%"
    saved = json.loads((tmp_path / "claude_limits.json").read_text())
    assert saved["rate_limits"]["five_hour"]["used_percentage"] == 38
    # A chained (pre-existing) command receives the same stdin and its output is shown.
    (tmp_path / "statusline_chain.json").write_text(json.dumps({"command": "cat | head -c 9; echo"}))
    r = subprocess.run([sys.executable, str(script)], input=stdin, text=True, capture_output=True, env=env)
    assert r.returncode == 0 and r.stdout.strip() == stdin[:9]
    # No rate_limits (start of a session): keep the previous file.
    r = subprocess.run([sys.executable, str(script)], input='{"model":{}}', text=True, capture_output=True, env=env)
    assert json.loads((tmp_path / "claude_limits.json").read_text())["rate_limits"]["seven_day"]["used_percentage"] == 61.4


def test_installer_preserves_settings_and_chains(tmp_path, monkeypatch):
    from deskpanel_agent import statusline_install as si

    claude = tmp_path / "home" / ".claude"
    claude.mkdir(parents=True)
    (claude / "settings.json").write_text(json.dumps({"model": "opus", "statusLine": {"type": "command", "command": "~/my.sh", "padding": 2}}))
    monkeypatch.setattr(si.Path, "home", staticmethod(lambda: tmp_path / "home"))
    assert si.install(assume_yes=True) == 0
    s = json.loads((claude / "settings.json").read_text())
    assert s["model"] == "opus" and s["statusLine"]["padding"] == 2 and si.MARK in s["statusLine"]["command"]
    assert json.loads((tmp_path / "deskpanel" / "statusline_chain.json").read_text())["command"] == "~/my.sh"
    assert list(claude.glob("settings.json.bak-*"))
    assert si.uninstall() == 0
    s = json.loads((claude / "settings.json").read_text())
    assert s["statusLine"] == {"type": "command", "command": "~/my.sh", "padding": 2}


def test_rate_limit_events_parsed_and_merged(tmp_path):
    from deskpanel_agent.collectors.claude import merge_limits, parse_rate_limit_events, ping_command

    stream = "\n".join([
        '{"type":"system","subtype":"init"}',
        '{"type":"rate_limit_event","rate_limit_info":{"status":"allowed_warning","resetsAt":1795856400,"rateLimitType":"seven_day","utilization":0.51,"isUsingOverage":false}}',
        '{"type":"result","subtype":"success"}',
    ])
    w = parse_rate_limit_events(stream)
    assert w == {"seven_day": {"used_percentage": 51.0, "resets_at": 1795856400}}
    p = tmp_path / "claude_limits.json"
    p.write_text(json.dumps({"rate_limits": {"five_hour": {"used_percentage": 57, "resets_at": 1795800000}}}))
    merge_limits(p, w)
    rl = json.loads(p.read_text())["rate_limits"]
    assert rl["five_hour"]["used_percentage"] == 57 and rl["seven_day"]["used_percentage"] == 51.0
    lim = read_limits(p, now_ms=1795000000 * 1000)
    assert lim.seven_day.used_pct == 51.0 and lim.five_hour.used_pct == 57
    cmd = ping_command("/x/claude", "haiku")
    assert "--no-session-persistence" in cmd and cmd[cmd.index("--setting-sources") + 1] == "project"
    assert cmd[cmd.index("--tools") + 1] == ""


def test_parse_usage_text_from_real_output():
    from zoneinfo import ZoneInfo

    from deskpanel_agent.collectors.claude import parse_usage_text, result_text

    text = ("You are currently using your subscription to power your Claude Code usage\n\n"
            "Current session: 59% used · resets Nov 23 at 7:20pm (Asia/Calcutta)\n"
            "Current week (all models): 52% used · resets Nov 28 at 2:30pm (Asia/Calcutta)\n"
            "Current week (Fable): 4% used · resets Nov 28 at 2:30pm (Asia/Calcutta)\n")
    now = dt.datetime(2026, 11, 23, 17, 50, tzinfo=ZoneInfo("Asia/Calcutta"))
    w = parse_usage_text(text, now)
    assert w["five_hour"]["used_percentage"] == 59.0 and w["seven_day"]["used_percentage"] == 52.0
    assert w["five_hour"]["resets_at"] == int(dt.datetime(2026, 11, 23, 19, 20, tzinfo=ZoneInfo("Asia/Calcutta")).timestamp())
    assert w["seven_day"]["resets_at"] == int(dt.datetime(2026, 11, 28, 14, 30, tzinfo=ZoneInfo("Asia/Calcutta")).timestamp())
    # Year rollover and time-only forms.
    w = parse_usage_text("Current session: 10% used · resets Jan 2 at 9am (UTC)",
                         dt.datetime(2026, 12, 30, 12, tzinfo=dt.timezone.utc))
    assert dt.datetime.fromtimestamp(w["five_hour"]["resets_at"], dt.timezone.utc).year == 2027
    w = parse_usage_text("Current session: 3% used · resets 7pm (UTC)", dt.datetime(2026, 11, 23, 20, tzinfo=dt.timezone.utc))
    assert dt.datetime.fromtimestamp(w["five_hour"]["resets_at"], dt.timezone.utc).day == 24
    assert parse_usage_text("Usage unavailable") == {}
    assert result_text('{"type":"system"}\n{"type": "result", "result": "hello"}') == "hello"


def test_merge_keeps_precise_reset_time(tmp_path):
    from deskpanel_agent.collectors.claude import merge_limits

    p = tmp_path / "l.json"
    p.write_text(json.dumps({"rate_limits": {"five_hour": {"used_percentage": 57, "resets_at": 1795441785}}}))
    merge_limits(p, {"five_hour": {"used_percentage": 59.0, "resets_at": 1795441740}})
    w = json.loads(p.read_text())["rate_limits"]["five_hour"]
    assert w == {"used_percentage": 59.0, "resets_at": 1795441785}
    merge_limits(p, {"five_hour": {"used_percentage": 1.0, "resets_at": 1795459740}})  # new window
    assert json.loads(p.read_text())["rate_limits"]["five_hour"]["resets_at"] == 1795459740
