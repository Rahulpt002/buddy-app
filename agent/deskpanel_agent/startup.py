"""Run the agent at login (macOS launchd LaunchAgent), restarted automatically if it exits."""
from __future__ import annotations

import os
import plistlib
import subprocess
import sys
from pathlib import Path

from .config import home_dir

LABEL = "com.deskpanel.agent"


def plist_path() -> Path:
    return Path.home() / "Library" / "LaunchAgents" / f"{LABEL}.plist"


def plist(tray: bool = True) -> dict:
    log = str(home_dir() / "agent.log")
    args = [sys.executable, "-m", "deskpanel_agent", "run"] + (["--tray"] if tray else [])
    # launchd starts with a minimal PATH; adb, claude and Homebrew tools live here.
    path = ":".join([
        "/opt/homebrew/bin", "/usr/local/bin", str(Path.home() / ".local" / "bin"),
        str(Path.home() / "Library" / "Android" / "sdk" / "platform-tools"),
        "/usr/bin", "/bin", "/usr/sbin", "/sbin",
    ])
    return {
        "Label": LABEL,
        "ProgramArguments": args,
        "RunAtLoad": True,
        "KeepAlive": {"SuccessfulExit": False},  # restart after a crash, not after Quit
        "ThrottleInterval": 10,
        "ProcessType": "Interactive",
        "LimitLoadToSessionType": "Aqua",  # the GUI session, so the menu-bar icon works
        "EnvironmentVariables": {"PATH": path, "PYTHONUNBUFFERED": "1"},
        "StandardOutPath": log,
        "StandardErrorPath": log,
        "WorkingDirectory": str(home_dir()),
    }


def _launchctl(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["launchctl", *args], capture_output=True, text=True)


def install(tray: bool = True) -> int:
    p = plist_path()
    p.parent.mkdir(parents=True, exist_ok=True)
    domain = f"gui/{os.getuid()}"
    if p.exists():
        _launchctl("bootout", domain, str(p))
    with p.open("wb") as f:
        plistlib.dump(plist(tray), f)
    r = _launchctl("bootstrap", domain, str(p))
    if r.returncode != 0 and "already" not in (r.stderr or ""):
        print(f"launchctl bootstrap failed: {r.stderr.strip()}")
        return 1
    print(f"Installed {p}")
    print("The agent now starts at login (and has started now), with a menu-bar icon.")
    print(f"Log: {home_dir() / 'agent.log'}")
    print("Note: macOS will ask again to allow Python to control Spotify/Music and to record the "
          "screen, because the agent now runs as its own app rather than from Terminal.")
    return 0


def uninstall() -> int:
    p = plist_path()
    if p.exists():
        _launchctl("bootout", f"gui/{os.getuid()}", str(p))
        p.unlink()
        print(f"Removed {p}; the agent no longer starts at login.")
    else:
        print("Not installed.")
    return 0
