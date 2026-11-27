"""Agent configuration: ~/.deskpanel/config.toml (all sections optional)."""
from __future__ import annotations

import logging
import os
import tomllib
from pathlib import Path
from typing import Any

from pydantic import BaseModel, Field

from . import DEFAULT_PORT

log = logging.getLogger(__name__)


def home_dir() -> Path:
    return Path(os.environ.get("DESKPANEL_HOME", Path.home() / ".deskpanel"))


class ServerCfg(BaseModel):
    port: int = DEFAULT_PORT
    bind: str = "0.0.0.0"
    tls: bool = True
    mdns: bool = True
    adb_reverse: bool = True
    adb_path: str | None = None
    # The desk web page (a browser on this Mac): plain http on 127.0.0.1 only.
    web: bool = True
    web_port: int = 8766


class CustomShortcut(BaseModel):
    id: str
    label: str
    icon: str = "bolt"
    color: str | None = None
    # argv list, executed without a shell. Never received from the phone.
    command: list[str]


class ShortcutsCfg(BaseModel):
    custom: list[CustomShortcut] = Field(default_factory=list)


class NetworkCfg(BaseModel):
    ping_host: str = "1.1.1.1"
    ping_port: int = 443


class ClaudeCfg(BaseModel):
    # Keep the plan's weekly limit fresh without a terminal session: when you've used
    # Claude since the last check (and at most every `ping_every_min`), run one tiny
    # headless Haiku request and read the rate-limit info Claude Code reports.
    limit_pings: bool = True
    ping_every_min: int = 5
    ping_model: str = "haiku"


class GithubCfg(BaseModel):
    token: str | None = None


class GitlabCfg(BaseModel):
    token: str | None = None
    base_url: str = "https://gitlab.com"


class SlackCfg(BaseModel):
    app_token: str | None = None   # xapp-... (Socket Mode, scope connections:write)
    user_token: str | None = None  # xoxp-... (your user: reads DMs/mentions sent to you)


class BambuCfg(BaseModel):
    """Bambu printer (the Printer page was replaced by Hotspot; kept for the collector)."""
    host: str | None = None
    serial: str | None = None
    access_code: str | None = None
    name: str = "X1 Carbon"


class HotspotCfg(BaseModel):
    """Hotspot Monitor Server. `deskpanel-agent hotspot-login` fills in token/expires."""
    server_url: str | None = None   # https://<your-server>.onrender.com
    token: str | None = None        # session token (secret; never logged)
    expires: str | None = None      # ISO time the session token expires
    device_id: str | None = None    # which phone; default: the first one


class CalendarCfg(BaseModel):
    ics_urls: list[str] = Field(default_factory=list)


class Config(BaseModel):
    server: ServerCfg = Field(default_factory=ServerCfg)
    network: NetworkCfg = Field(default_factory=NetworkCfg)
    claude: ClaudeCfg = Field(default_factory=ClaudeCfg)
    shortcuts: ShortcutsCfg = Field(default_factory=ShortcutsCfg)
    github: GithubCfg = Field(default_factory=GithubCfg)
    gitlab: GitlabCfg = Field(default_factory=GitlabCfg)
    slack: SlackCfg = Field(default_factory=SlackCfg)
    hotspot: HotspotCfg = Field(default_factory=HotspotCfg)
    calendar: CalendarCfg = Field(default_factory=CalendarCfg)


TEMPLATE = """\
# DeskPanel agent configuration. Every section is optional.
# Restart the agent after editing.

[server]
# port = 8765
# tls = true          # wss:// with a self-signed cert pinned by the phone at pairing
# mdns = true         # advertise _deskpanel._tcp on the LAN
# adb_reverse = true  # auto-run `adb reverse` when the phone is plugged in over USB

[network]
# ping_host = "1.1.1.1"
# ping_port = 443

[claude]
# limit_pings = true    # refresh the weekly limit with a tiny Haiku request after you use Claude
# ping_every_min = 5

[github]
# token = "ghp_..."   # classic PAT with read:user (add repo for private contribution details)

[gitlab]
# token = "glpat-..."  # personal access token with read_api (gitlab.com → Preferences → Access tokens)
# base_url = "https://gitlab.com"

[slack]
# Your DMs and @mentions on the phone. Create the app from shared/slack-app-manifest.yaml
# (README section 8), then paste its two tokens here.
# app_token = "xapp-..."   # Basic Information → App-Level Tokens (connections:write)
# user_token = "xoxp-..."  # OAuth & Permissions → User OAuth Token

[hotspot]
# Hotspot Monitor (the roof phone). Don't paste a token here: run
#   deskpanel-agent hotspot-login
# and sign in with a viewer account (password + authenticator code). Sign-ins last 30 days.
# server_url = "https://your-server.onrender.com"
# device_id = "d_..."   # only if the Server has more than one phone

[calendar]
# ics_urls = ["https://calendar.google.com/calendar/ical/.../basic.ics"]

# Custom shortcut tiles. The phone can only trigger these by id.
# [[shortcuts.custom]]
# id = "open-vscode"
# label = "VS Code"
# icon = "code"
# command = ["open", "-a", "Visual Studio Code"]
"""


def load_config(path: Path | None = None) -> Config:
    path = path or home_dir() / "config.toml"
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(TEMPLATE)
        log.info("Wrote config template to %s", path)
    # It holds API tokens: readable by this user only.
    try:
        if path.stat().st_mode & 0o077:
            os.chmod(path, 0o600)
    except OSError:
        pass
    if path.read_text() == TEMPLATE:
        return Config()
    try:
        data: dict[str, Any] = tomllib.loads(path.read_text())
    except tomllib.TOMLDecodeError as e:
        log.error("Config %s is invalid (%s); using defaults", path, e)
        return Config()
    return Config.model_validate(data)
