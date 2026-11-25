"""Install / remove the DeskPanel statusLine bridge in ~/.claude/settings.json.

Only the `statusLine` key is touched. A timestamped backup of settings.json is written
first, and an existing statusLine command is preserved and chained (its output still
shows in Claude Code), then restored on uninstall.
"""
from __future__ import annotations

import json
import shlex
import shutil
import sys
import time
from pathlib import Path

from .config import home_dir

MARK = "deskpanel-statusline"


def settings_path() -> Path:
    return Path.home() / ".claude" / "settings.json"


def bridge_command() -> str:
    """The command Claude Code will run: this venv's Python + the bridge copied into
    ~/.deskpanel (so moving the repo doesn't break it). Quoted for the shell."""
    dst = home_dir() / "statusline.py"
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(Path(__file__).with_name("statusline.py"), dst)
    return f"{shlex.quote(sys.executable)} {shlex.quote(str(dst))}  # {MARK}"


def _load(p: Path) -> dict:
    if not p.exists():
        return {}
    return json.loads(p.read_text())


def plan() -> tuple[dict, dict, str | None]:
    """(current statusLine or {}, new statusLine, command that will be chained)."""
    cur = _load(settings_path()).get("statusLine") or {}
    chained = None
    if cur.get("type") == "command" and cur.get("command") and MARK not in cur["command"]:
        chained = cur["command"]
    new = {"type": "command", "command": bridge_command()}
    for k in ("padding", "refreshInterval", "hideVimModeIndicator"):
        if k in cur:
            new[k] = cur[k]
    return cur, new, chained


def install(assume_yes: bool = False) -> int:
    p = settings_path()
    try:
        settings = _load(p)
    except json.JSONDecodeError as e:
        print(f"{p} is not valid JSON ({e}); not touching it.")
        return 1
    cur, new, chained = plan()
    print(f"File: {p}")
    print(f"  current statusLine: {json.dumps(cur) if cur else '(none)'}")
    print(f"  new statusLine:     {json.dumps(new)}")
    if chained:
        print(f"  your existing command keeps running and its output is still shown: {chained}")
    if not assume_yes:
        if input("Apply this change? [y/N] ").strip().lower() not in ("y", "yes"):
            print("No changes made.")
            return 1
    if p.exists():
        backup = p.with_name(f"settings.json.bak-{time.strftime('%Y%m%d-%H%M%S')}")
        shutil.copy2(p, backup)
        print(f"Backup: {backup}")
    chain_file = home_dir() / "statusline_chain.json"
    if chained:
        chain_file.write_text(json.dumps({"command": chained}))
    elif chain_file.exists() and MARK not in (cur.get("command") or ""):
        chain_file.unlink()
    settings["statusLine"] = new
    p.parent.mkdir(parents=True, exist_ok=True)
    tmp = p.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(settings, indent=2) + "\n")
    tmp.replace(p)
    print("Done. Limits appear on the phone after Claude Code's next reply in any session.")
    return 0


def uninstall() -> int:
    p = settings_path()
    settings = _load(p)
    cur = settings.get("statusLine") or {}
    if MARK not in (cur.get("command") or ""):
        print("The DeskPanel statusLine isn't installed; nothing to do.")
        return 0
    chain_file = home_dir() / "statusline_chain.json"
    try:
        chained = json.loads(chain_file.read_text()).get("command")
    except (OSError, json.JSONDecodeError):
        chained = None
    if chained:
        restored = {"type": "command", "command": chained}
        for k in ("padding", "refreshInterval", "hideVimModeIndicator"):
            if k in cur:
                restored[k] = cur[k]
        settings["statusLine"] = restored
        chain_file.unlink(missing_ok=True)
    else:
        settings.pop("statusLine", None)
    p.write_text(json.dumps(settings, indent=2) + "\n")
    print("Removed the DeskPanel statusLine" + (f"; restored: {chained}" if chained else "."))
    return 0
