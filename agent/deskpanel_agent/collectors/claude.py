"""`claude` topic: Claude Code usage from the local session transcripts, plus the plan's
5-hour / weekly limits captured by the statusLine bridge.

Transcripts: ~/.claude/projects/**/*.jsonl (sub-agent sessions included). Claude Code
writes one line per content block, repeating the same `message.id` with identical usage,
so messages are deduped by id. Files are tailed incrementally: each file's byte offset is
remembered, and only complete new lines are parsed. Messages are indexed in SQLite, so a
restart doesn't re-read gigabytes of history.

Limits: ~/.deskpanel/claude_limits.json, written by the statusLine bridge
(deskpanel_agent/statusline.py). Nothing here reads credentials or calls any API.
"""
from __future__ import annotations

import asyncio
import datetime as dt
import json
import logging
import os
import re
import sqlite3
import time
from pathlib import Path
from typing import Any

from ..config import home_dir
from ..protocol import ClaudeData, ClaudeDay, ClaudeToday, LimitWindow, Limits, ModelUsage
from .base import BaseProvider

log = logging.getLogger(__name__)

SCHEMA = """
CREATE TABLE IF NOT EXISTS claude_msgs (
  id TEXT PRIMARY KEY, ts INTEGER NOT NULL, model TEXT, tokens INTEGER NOT NULL, output INTEGER NOT NULL);
CREATE INDEX IF NOT EXISTS claude_msgs_ts ON claude_msgs(ts);
CREATE TABLE IF NOT EXISTS claude_files (path TEXT PRIMARY KEY, offset INTEGER NOT NULL, ino INTEGER);
"""

HISTORY_DAYS = 8


def parse_line(line: str) -> tuple[str, int, str, int, int] | None:
    """One transcript line -> (message_id, ts_ms, model, total_tokens, output_tokens), or None.
    total = input + output + cache creation + cache read (what Claude Code counts)."""
    if '"assistant"' not in line or '"usage"' not in line:  # cheap pre-filter (most lines aren't)
        return None
    try:
        d = json.loads(line)
    except json.JSONDecodeError:
        return None
    if d.get("type") != "assistant":
        return None
    m = d.get("message") or {}
    mid, u, model = m.get("id"), m.get("usage"), m.get("model")
    if not mid or not isinstance(u, dict) or not model or model.startswith("<"):
        return None  # "<synthetic>" = locally generated, not billed
    ts = d.get("timestamp")
    try:
        ts_ms = int(dt.datetime.fromisoformat(ts.replace("Z", "+00:00")).timestamp() * 1000)
    except (AttributeError, ValueError):
        return None
    n = lambda k: int(u.get(k) or 0)  # noqa: E731
    out = n("output_tokens")
    total = n("input_tokens") + out + n("cache_creation_input_tokens") + n("cache_read_input_tokens")
    return mid, ts_ms, model, total, out


def model_family(model: str) -> str:
    """claude-opus-5-5 -> opus; claude-3-5-sonnet-2024… -> sonnet."""
    for fam in ("opus", "sonnet", "haiku", "fable"):
        if fam in model:
            return fam
    parts = model.split("-")
    return parts[1] if len(parts) > 1 else model


class TranscriptIndex:
    def __init__(self, db_path: Path, root: Path):
        self.root = root
        self.db = sqlite3.connect(db_path, check_same_thread=False, isolation_level=None)
        self.db.execute("PRAGMA journal_mode=WAL")
        self.db.executescript(SCHEMA)

    def scan(self, first: bool = False) -> int:
        """Ingest new complete lines from every transcript. Returns new messages added.
        On the first pass, files untouched for HISTORY_DAYS are skipped entirely."""
        if not self.root.is_dir():
            return 0
        cutoff = time.time() - HISTORY_DAYS * 86400
        known = {p: (o, i) for p, o, i in self.db.execute("SELECT path, offset, ino FROM claude_files")}
        added = 0
        for dirpath, _, files in os.walk(self.root):
            for name in files:
                if not name.endswith(".jsonl"):
                    continue
                path = os.path.join(dirpath, name)
                try:
                    st = os.stat(path)
                except OSError:
                    continue
                off, ino = known.get(path, (0, None))
                if ino is not None and ino != st.st_ino or st.st_size < off:
                    off = 0  # replaced or truncated: start over (ids dedupe)
                if st.st_size == off:
                    continue
                if path not in known and st.st_mtime < cutoff:
                    # Old file: remember its end so we never read it, but pick up appends.
                    self.db.execute("INSERT OR REPLACE INTO claude_files VALUES(?,?,?)", (path, st.st_size, st.st_ino))
                    continue
                added += self._ingest(path, off, st.st_ino)
        return added

    def _ingest(self, path: str, off: int, ino: int) -> int:
        rows = []
        with open(path, "rb") as f:
            f.seek(off)
            data = f.read()
        end = data.rfind(b"\n")
        if end < 0:
            return 0  # no complete line yet
        for raw in data[: end + 1].splitlines():
            r = parse_line(raw.decode("utf-8", errors="replace"))
            if r:
                rows.append(r)
        cur = self.db.cursor()
        cur.execute("BEGIN")
        before = self.db.total_changes
        cur.executemany("INSERT OR IGNORE INTO claude_msgs VALUES(?,?,?,?,?)", rows)
        cur.execute("INSERT OR REPLACE INTO claude_files VALUES(?,?,?)", (path, off + end + 1, ino))
        cur.execute("COMMIT")
        return self.db.total_changes - before - 1

    # ------------------------------------------------------------------ queries

    def summary(self, now: dt.datetime | None = None) -> dict[str, Any]:
        now = now or dt.datetime.now().astimezone()
        midnight = now.replace(hour=0, minute=0, second=0, microsecond=0)
        ms = lambda t: int(t.timestamp() * 1000)  # noqa: E731
        q = self.db.execute
        tok, out, msgs = q(
            "SELECT COALESCE(SUM(tokens),0), COALESCE(SUM(output),0), COUNT(*) FROM claude_msgs WHERE ts >= ?",
            (ms(midnight),)).fetchone()
        last_hour = q("SELECT COALESCE(SUM(tokens),0) FROM claude_msgs WHERE ts >= ?",
                      (ms(now - dt.timedelta(hours=1)),)).fetchone()[0]
        days = []
        for i in range(6, -1, -1):
            d0 = midnight - dt.timedelta(days=i)
            d1 = d0 + dt.timedelta(days=1)
            t = q("SELECT COALESCE(SUM(tokens),0) FROM claude_msgs WHERE ts >= ? AND ts < ?", (ms(d0), ms(d1))).fetchone()[0]
            days.append({"date": d0.date().isoformat(), "tokens": int(t)})
        fams: dict[str, tuple[str, int]] = {}
        for model, t in q("SELECT model, SUM(tokens) FROM claude_msgs WHERE ts >= ? GROUP BY model", (ms(midnight),)):
            f = model_family(model)
            prev = fams.get(f, (model, 0))
            fams[f] = (prev[0] if prev[1] >= t else model, prev[1] + int(t))
        models = sorted(({"family": f, "model": m, "tokens": t} for f, (m, t) in fams.items()),
                        key=lambda x: -x["tokens"])
        return {"tokens": int(tok), "output": int(out), "messages": int(msgs), "last_hour": int(last_hour),
                "days": days, "models": models}


# ---------------------------------------------------------------------- limits

LIMITS_FILE = "claude_limits.json"


def _to_ms(v: Any) -> int | None:
    """resets_at may be epoch seconds, epoch ms or an ISO-8601 string."""
    if v is None:
        return None
    if isinstance(v, (int, float)):
        return int(v if v > 1e12 else v * 1000)
    if isinstance(v, str):
        try:
            return int(dt.datetime.fromisoformat(v.replace("Z", "+00:00")).timestamp() * 1000)
        except ValueError:
            try:
                return _to_ms(float(v))
            except ValueError:
                return None
    return None


def read_limits(path: Path, now_ms: int | None = None) -> Limits | None:
    """Parse what the statusLine bridge saved. A window whose reset time has passed is
    reported as expired (its percentage no longer applies)."""
    try:
        raw = json.loads(path.read_text())
    except (OSError, json.JSONDecodeError):
        return None
    rl = raw.get("rate_limits") or {}
    now_ms = now_ms or int(time.time() * 1000)

    def window(*names: str) -> LimitWindow | None:
        w = next((rl[n] for n in names if isinstance(rl.get(n), dict)), None)
        if not w:
            return None
        pct = w.get("used_percentage")  # 0-100 per the statusLine docs
        if pct is None:
            return None
        pct = float(pct)
        reset = _to_ms(w.get("resets_at"))
        return LimitWindow(used_pct=round(pct, 1), resets_at=reset, expired=bool(reset and reset <= now_ms))

    five, week = window("five_hour"), window("seven_day")
    if not five and not week:
        return None
    return Limits(source="statusline", updated_at=int(raw.get("updated_at") or 0), five_hour=five, seven_day=week)


# ---------------------------------------------------------------------- limit pings

PING_PROMPT = "Reply with just: OK"


def find_claude() -> str | None:
    import shutil

    for c in (shutil.which("claude"), "/opt/homebrew/bin/claude", "/usr/local/bin/claude",
              str(Path.home() / ".claude" / "local" / "claude"), str(Path.home() / ".local" / "bin" / "claude")):
        if c and Path(c).is_file() and os.access(c, os.X_OK):
            return c
    return None


def ping_command(claude: str, model: str) -> list[str]:
    """A minimal headless request. No tools, no transcript saved, user settings skipped
    (so user hooks, e.g. usage uploaders, don't see these pings)."""
    return [claude, "-p", PING_PROMPT, "--model", model, "--output-format", "stream-json", "--verbose",
            "--no-session-persistence", "--tools", "", "--setting-sources", "project"]


def parse_rate_limit_events(stream: str) -> dict[str, dict]:
    """stream-json output -> {window: {"used_percentage": 0-100, "resets_at": epoch_s}} from
    `rate_limit_event` lines (rateLimitType e.g. "seven_day", utilization 0..1)."""
    out: dict[str, dict] = {}
    for line in stream.splitlines():
        if '"rate_limit_event"' not in line:
            continue
        try:
            info = json.loads(line).get("rate_limit_info") or {}
        except json.JSONDecodeError:
            continue
        kind, util = info.get("rateLimitType"), info.get("utilization")
        if not kind or util is None:
            continue
        w: dict[str, Any] = {"used_percentage": round(float(util) * 100, 1)}
        if info.get("resetsAt") is not None:
            w["resets_at"] = info["resetsAt"]
        out[kind] = w
    return out


def usage_command(claude: str) -> list[str]:
    """Claude Code's built-in `/usage`: answered locally (no model call, 0 tokens) with the
    plan's current session (5-hour) and weekly usage as text."""
    return [claude, "-p", "/usage", "--output-format", "stream-json", "--verbose",
            "--no-session-persistence", "--tools", "", "--setting-sources", "project"]


_MONTHS = {m: i for i, m in enumerate(["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"], 1)}
_USAGE_LINE = re.compile(
    r"Current (session|week \(all models\)):\s*(\d+(?:\.\d+)?)%\s*used(?:\s*[·•-]\s*resets\s*(.+))?", re.I)
_RESET = re.compile(
    r"(?:(?P<mon>[A-Za-z]{3})[a-z]*\.?\s+(?P<day>\d{1,2}),?\s*(?:at\s+)?)?"
    r"(?P<h>\d{1,2})(?::(?P<m>\d{2}))?\s*(?P<ap>[ap]m)?\s*(?:\((?P<tz>[^)]+)\))?", re.I)


def _parse_reset(text: str, now: dt.datetime) -> int | None:
    """"Nov 23 at 7:20pm (Asia/Calcutta)" / "7pm (Europe/Berlin)" -> epoch seconds."""
    m = _RESET.search(text.strip())
    if not m:
        return None
    try:
        from zoneinfo import ZoneInfo

        tz = ZoneInfo(m["tz"]) if m["tz"] else now.astimezone().tzinfo
    except Exception:  # noqa: BLE001 - unknown zone name
        tz = now.astimezone().tzinfo
    local_now = now.astimezone(tz)
    h, mi = int(m["h"]), int(m["m"] or 0)
    if m["ap"]:
        h = h % 12 + (12 if m["ap"].lower() == "pm" else 0)
    if m["mon"] and m["mon"].lower()[:3] in _MONTHS:
        t = local_now.replace(month=_MONTHS[m["mon"].lower()[:3]], day=int(m["day"]), hour=h, minute=mi,
                              second=0, microsecond=0)
        if t < local_now - dt.timedelta(days=2):  # e.g. "Jan 2" seen on Dec 30
            t = t.replace(year=t.year + 1)
    else:
        t = local_now.replace(hour=h, minute=mi, second=0, microsecond=0)
        if t < local_now - dt.timedelta(minutes=5):
            t += dt.timedelta(days=1)
    return int(t.timestamp())


def parse_usage_text(text: str, now: dt.datetime | None = None) -> dict[str, dict]:
    """`/usage` output -> {"five_hour": {...}, "seven_day": {...}} (statusLine-compatible)."""
    now = now or dt.datetime.now().astimezone()
    out: dict[str, dict] = {}
    for line in text.splitlines():
        m = _USAGE_LINE.search(line)
        if not m:
            continue
        key = "five_hour" if m.group(1).lower() == "session" else "seven_day"
        w: dict[str, Any] = {"used_percentage": float(m.group(2))}
        if m.group(3):
            r = _parse_reset(m.group(3), now)
            if r:
                w["resets_at"] = r
        out.setdefault(key, w)
    return out


def result_text(stream: str) -> str:
    for line in stream.splitlines():
        if '"type":"result"' in line.replace(" ", ""):
            try:
                return json.loads(line).get("result") or ""
            except json.JSONDecodeError:
                pass
    return ""


def merge_limits(path: Path, windows: dict[str, dict]) -> None:
    """Merge windows into the limits file (keeping others, e.g. five_hour from the
    statusLine). Atomic replace."""
    if not windows:
        return
    try:
        cur = json.loads(path.read_text())
    except (OSError, json.JSONDecodeError):
        cur = {}
    rl = dict(cur.get("rate_limits") or {})
    for k, w in windows.items():
        old = rl.get(k) or {}
        # /usage prints reset times to the minute; the statusLine has the exact second.
        # Same window (within 2 min): keep the precise value.
        if old.get("resets_at") and w.get("resets_at") and abs(old["resets_at"] - w["resets_at"]) <= 120:
            w = {**w, "resets_at": old["resets_at"]}
        rl[k] = w
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps({"rate_limits": rl, "updated_at": int(time.time() * 1000)}))
    tmp.replace(path)


class ClaudeCollector(BaseProvider):
    topics = ("claude",)

    def __init__(self, root: Path | None = None, db_path: Path | None = None, cfg=None):
        super().__init__()
        self.root = root or Path.home() / ".claude" / "projects"
        self.db_path = db_path or home_dir() / "deskpanel.db"
        self.limits_path = home_dir() / LIMITS_FILE
        self.cfg = cfg
        self.claude_bin = find_claude() if (cfg is None or cfg.limit_pings) else None
        self._last_ping = 0.0
        self._msgs_at_ping = -1
        self._pinging = False

    async def setup(self) -> None:
        if not self.root.is_dir():
            self.publish("claude", {"status": "unconfigured",
                                    "message": "No Claude Code history found on this laptop (~/.claude/projects)."})
            return
        self.index = TranscriptIndex(self.db_path, self.root)
        self.publish("claude", {"status": "starting", "message": "Reading your Claude Code history…"})

    async def run(self) -> None:
        if not self.root.is_dir():
            return
        t0 = time.monotonic()
        added = await asyncio.to_thread(self.index.scan, True)
        log.info("claude: indexed %d messages in %.1fs", added, time.monotonic() - t0)
        last_pub = 0.0
        last_limits_mtime = 0.0
        while True:
            try:
                lm = self.limits_path.stat().st_mtime
            except OSError:
                lm = 0.0
            new = await asyncio.to_thread(self.index.scan)
            now = time.monotonic()
            self._maybe_ping(now, lm)
            if new or lm != last_limits_mtime or now - last_pub > 30:
                last_limits_mtime, last_pub = lm, now
                self.publish("claude", await asyncio.to_thread(self.snapshot))
            await asyncio.sleep(3)

    def _maybe_ping(self, now: float, limits_mtime: float) -> None:
        if not self.claude_bin or self._pinging:
            return
        every = max(1, getattr(self.cfg, "ping_every_min", 5)) * 60
        if now - self._last_ping < every:
            return
        msgs = self.index.db.execute("SELECT COUNT(*) FROM claude_msgs").fetchone()[0]
        # /usage costs no tokens, but there's no point asking while you're away: limits only
        # move when Claude is used. Idle: refresh every 30 min (keeps reset times current).
        stale = time.time() - limits_mtime > 1800
        if msgs == self._msgs_at_ping and not stale:
            return
        self._last_ping, self._msgs_at_ping, self._pinging = now, msgs, True
        asyncio.create_task(self._ping())

    async def _run_claude(self, cmd: list[str]) -> str:
        cwd = home_dir() / "claude-ping"
        cwd.mkdir(parents=True, exist_ok=True)
        proc = await asyncio.create_subprocess_exec(
            *cmd, cwd=cwd, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL)
        try:
            out, _ = await asyncio.wait_for(proc.communicate(), 90)
        except asyncio.TimeoutError:
            proc.kill()
            raise
        return out.decode(errors="replace")

    async def _ping(self) -> None:
        try:
            # 1) /usage: both windows, answered locally, costs nothing.
            windows = parse_usage_text(result_text(await self._run_claude(usage_command(self.claude_bin))))
            how = "/usage"
            # 2) Fallback if its wording ever changes: a tiny Haiku request, whose
            #    rate_limit_event carries the window you're closest to.
            if not windows:
                model = getattr(self.cfg, "ping_model", "haiku")
                windows = parse_rate_limit_events(await self._run_claude(ping_command(self.claude_bin, model)))
                how = model
            if windows:
                await asyncio.to_thread(merge_limits, self.limits_path, windows)
                log.info("claude: limits refreshed via %s (%s)", how, ", ".join(
                    f"{k} {v['used_percentage']:.0f}%" for k, v in windows.items()))
            else:
                log.info("claude: no limit info available (not on a Pro/Max plan?)")
        except asyncio.TimeoutError:
            log.warning("claude: limit check timed out")
        except Exception:  # noqa: BLE001
            log.exception("claude: limit check failed")
        finally:
            self._pinging = False

    def snapshot(self) -> ClaudeData:
        s = self.index.summary()
        return ClaudeData(
            limits=read_limits(self.limits_path),
            today=ClaudeToday(tokens=s["tokens"], output_tokens=s["output"], messages=s["messages"],
                              last_hour_tokens=s["last_hour"]),
            days=[ClaudeDay(**d) for d in s["days"]],
            models_today=[ModelUsage(**m) for m in s["models"]],
        )
