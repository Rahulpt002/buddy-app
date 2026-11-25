#!/usr/bin/env python3
"""DeskPanel bridge for Claude Code's statusLine (stdlib only, must stay fast).

Claude Code runs the statusLine command with a JSON document on stdin. For Pro/Max/Ultra
plans it includes `rate_limits.five_hour` / `.seven_day` (`used_percentage` 0-100,
`resets_at` epoch seconds; https://code.claude.com/docs/en/statusline). This script:

1. saves `rate_limits` (when present) to ~/.deskpanel/claude_limits.json for the agent;
2. if you already had a statusLine command, runs it with the same stdin and prints its
   output unchanged (the original is kept in ~/.deskpanel/statusline_chain.json);
3. otherwise prints a compact line: "Opus · 5h 38% · week 61%".

It never reads credentials and makes no network calls.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path

HOME = Path(os.environ.get("DESKPANEL_HOME", Path.home() / ".deskpanel"))
LIMITS = HOME / "claude_limits.json"
CHAIN = HOME / "statusline_chain.json"


def save_limits(data: dict) -> None:
    rl = data.get("rate_limits")
    if not isinstance(rl, dict) or not rl:
        return  # absent until the first reply of a session; keep the last known values
    HOME.mkdir(parents=True, exist_ok=True)
    payload = json.dumps({"rate_limits": rl, "updated_at": int(time.time() * 1000)})
    fd, tmp = tempfile.mkstemp(dir=HOME, prefix=".limits-")
    with os.fdopen(fd, "w") as f:
        f.write(payload)
    os.replace(tmp, LIMITS)  # atomic: the agent never sees a half-written file


def default_line(data: dict) -> str:
    parts = [((data.get("model") or {}).get("display_name")) or "Claude"]
    rl = data.get("rate_limits") or {}
    for key, label in (("five_hour", "5h"), ("seven_day", "week")):
        w = rl.get(key)
        if isinstance(w, dict) and w.get("used_percentage") is not None:
            parts.append(f"{label} {round(float(w['used_percentage']))}%")
    return " · ".join(parts)


def main() -> int:
    raw = sys.stdin.read()
    try:
        data = json.loads(raw) if raw.strip() else {}
    except json.JSONDecodeError:
        data = {}
    try:
        save_limits(data)
    except OSError:
        pass  # never break the user's status line over this
    try:
        chained = json.loads(CHAIN.read_text()).get("command")
    except (OSError, json.JSONDecodeError):
        chained = None
    if chained:
        r = subprocess.run(chained, shell=True, input=raw, text=True, capture_output=True)
        sys.stdout.write(r.stdout)
        return r.returncode
    print(default_line(data))
    return 0


if __name__ == "__main__":
    sys.exit(main())
