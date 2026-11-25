"""Real data providers. Each integration is optional: an unconfigured or failing one
publishes a friendly status instead of data, so the phone shows a setup/empty state and
the agent keeps running."""
from __future__ import annotations

from .collectors.calendar_ics import IcsCalendarCollector
from .collectors.claude import ClaudeCollector
from .collectors.github import GithubCollector
from .collectors.hotspot import HotspotCollector
from .collectors.gitlab import GitlabCollector
from .collectors.media import MediaCollector
from .collectors.network import NetworkCollector
from .collectors.shortcuts import ShortcutsCollector
from .collectors.slack import SlackCollector
from .collectors.system import SystemCollector
from .config import Config
from .mouse_share import MouseShare
from .storage import Store

def build_providers(cfg: Config, store: Store | None = None) -> list:
    store = store or Store()
    return [
        SystemCollector(),
        ClaudeCollector(cfg=cfg.claude),
        NetworkCollector(store, cfg.network.ping_host, cfg.network.ping_port),
        MediaCollector(),
        ShortcutsCollector(store, cfg.shortcuts.custom),
        GithubCollector(store, cfg.github),
        GitlabCollector(store, cfg.gitlab),
        SlackCollector(store, cfg.slack),
        IcsCalendarCollector(cfg.calendar.ics_urls),
        HotspotCollector(store, cfg.hotspot),
        MouseShare(),
    ]
