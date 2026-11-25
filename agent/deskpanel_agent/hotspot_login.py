"""`deskpanel-agent hotspot-login`: sign in to the Hotspot Monitor Server once (password +
authenticator code) and keep the session token in ~/.deskpanel/config.toml (0600).

The password is read with getpass and never stored; only the 30-day session token is.
Nothing secret is printed.
"""
from __future__ import annotations

import getpass
import json
import os
import re
from pathlib import Path

import httpx

from .config import home_dir, load_config


def set_section(text: str, section: str, values: dict[str, str]) -> str:
    """Set `key = "value"` lines in a TOML [section], keeping everything else as it was."""
    lines = text.splitlines()
    head = re.compile(r"^\s*\[([^\[\]]+)\]\s*(#.*)?$")
    start = next((i for i, l in enumerate(lines) if (m := head.match(l)) and m.group(1).strip() == section), None)
    new = [f"{k} = {json.dumps(v)}" for k, v in values.items()]
    if start is None:
        return "\n".join([*lines, "", f"[{section}]", *new]) + "\n"
    end = next((i for i in range(start + 1, len(lines)) if head.match(lines[i]) or lines[i].startswith("[[")), len(lines))
    keys = re.compile(r"^\s*(" + "|".join(map(re.escape, values)) + r")\s*=")
    body = [l for l in lines[start + 1:end] if not keys.match(l)]
    return "\n".join([*lines[:start + 1], *new, *body, *lines[end:]]) + "\n"


def login(server: str | None = None) -> int:
    path: Path = home_dir() / "config.toml"
    cfg = load_config(path).hotspot
    server = (server or cfg.server_url or input("Hotspot Monitor Server URL (https://…): ").strip()).rstrip("/")
    if not server.startswith("https://") and not server.startswith("http://localhost"):
        print("Use the https:// address of your Server.")
        return 2
    print(f"Signing in to {server}")
    print("Tip: a viewer account is enough (it can't send commands to the phone).")
    user = input("Username: ").strip()
    pw = getpass.getpass("Password: ")
    with httpx.Client(timeout=60, headers={"User-Agent": "DeskPanel"}) as c:
        try:
            r = c.post(f"{server}/api/auth/login", json={"username": user, "password": pw})
        except httpx.HTTPError as e:
            print(f"Couldn't reach the Server ({type(e).__name__}). It may be waking up; try again in a minute.")
            return 1
        if r.status_code != 200:
            print(f"Sign-in failed: {_msg(r)}")
            return 1
        body = r.json()
        if body.get("totp_required"):
            code = input("Authenticator code: ").strip().replace(" ", "")
            r = c.post(f"{server}/api/auth/totp", json={"pending_token": body["pending_token"], "code": code})
            if r.status_code != 200:
                print(f"Sign-in failed: {_msg(r)}")
                return 1
            body = r.json()
        token, expires = body["token"], body.get("expires_at", "")
        me = c.get(f"{server}/api/auth/me", headers={"Authorization": f"Bearer {token}"})
        if me.status_code == 200 and me.json().get("totp_enrollment_required"):
            print("This account has no authenticator app yet. Sign in to the Dashboard once to set it up.")
            return 1
        devices = c.get(f"{server}/api/devices", headers={"Authorization": f"Bearer {token}"})
        names = [d.get("name") for d in devices.json()] if devices.status_code == 200 else []

    text = path.read_text() if path.exists() else ""
    path.write_text(set_section(text, "hotspot", {"server_url": server, "token": token, "expires": expires}))
    os.chmod(path, 0o600)
    role = body.get("user", {}).get("role", "?")
    print(f"Signed in as {user} ({role}). Saved to {path} (valid until {expires[:10]}).")
    if role == "admin":
        print("Note: this is an admin account. DeskPanel only reads, but a viewer account is safer.")
    print(f"Phones on the Server: {', '.join(n or '?' for n in names) or 'none paired yet'}")
    print("Restart the DeskPanel agent (or Remote Trackpad) to start showing it.")
    return 0


def _msg(r: httpx.Response) -> str:
    try:
        j = r.json()
        return j.get("message") or j.get("error") or r.reason_phrase
    except ValueError:
        return f"HTTP {r.status_code}"
