""""Watch on phone": find the video (or page) open in the Mac's browser so the phone can
open it itself, at full quality: a YouTube link opens in the phone's YouTube app at the same
moment, anything else in the phone's browser.

macOS only, via AppleScript (Chrome, Safari, Arc, Brave, Edge). The first use asks "allow
<the agent's app> to control <browser>" (Automation). Reading the playback position and
pausing the Mac's video also needs the browser's "Allow JavaScript from Apple Events"
(Chrome: View → Developer; Safari: Develop menu); without it the link opens from the start.
"""
from __future__ import annotations

import json
import logging
import re
from dataclasses import dataclass
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

from .collectors.base import osascript

log = logging.getLogger(__name__)

SEP = "␟"
CHROMIUM = ("Google Chrome", "Arc", "Brave Browser", "Microsoft Edge", "Chromium")
BROWSERS = (*CHROMIUM, "Safari")

# Returns {"t": seconds, "p": paused} for the page's main <video>, and pauses it.
PAUSE_JS = ("(function(){var v=document.querySelector('video');if(!v)return '';"
            "var r=JSON.stringify({t:v.currentTime,p:v.paused});v.pause();return r;})()")
JS_OFF_HINT = ("For the same moment and to pause it here, turn on {app} → {menu} → "
               "Allow JavaScript from Apple Events.")


@dataclass
class Tab:
    app: str
    window: int  # 1-based, front window first
    index: int   # 1-based
    active: bool
    url: str
    title: str


def is_youtube(url: str) -> bool:
    host = (urlsplit(url).hostname or "").lower()
    return host in ("youtu.be", "www.youtube.com", "youtube.com", "m.youtube.com", "music.youtube.com")


def is_youtube_video(url: str) -> bool:
    u = urlsplit(url)
    host = (u.hostname or "").lower()
    if host == "youtu.be":
        return len(u.path) > 1
    return is_youtube(url) and (u.path == "/watch" or u.path.startswith(("/shorts/", "/live/")))


def with_time(url: str, seconds: float | None) -> str:
    """The same YouTube link starting at [seconds] (whole seconds, ≥ 2 s in); others unchanged."""
    if seconds is None or seconds < 2 or not is_youtube_video(url) or "/shorts/" in url:
        return url
    u = urlsplit(url)
    q = [(k, v) for k, v in parse_qsl(u.query, keep_blank_values=True) if k not in ("t", "start")]
    q.append(("t", f"{int(seconds)}s"))
    return urlunsplit((u.scheme, u.netloc, u.path, urlencode(q), u.fragment))


def parse_tabs(app: str, out: str) -> list[Tab]:
    tabs = []
    for line in out.splitlines():
        parts = line.split(SEP)
        if len(parts) < 5 or not parts[3].startswith(("http://", "https://")):
            continue
        try:
            tabs.append(Tab(app, int(parts[0]), int(parts[1]), parts[2] == "true", parts[3], SEP.join(parts[4:])))
        except ValueError:
            continue
    return tabs


def candidates(tabs: list[Tab]) -> list[Tab]:
    """Best first: YouTube videos (the visible one first), then the front window's tab."""
    vids = sorted((t for t in tabs if is_youtube_video(t.url)), key=lambda t: (not t.active, t.window, t.index))
    front = [t for t in tabs if t.active and t.window == 1 and t not in vids]
    return vids + front


def fmt_time(s: float) -> str:
    s = int(s)
    return f"{s // 3600}:{s % 3600 // 60:02d}:{s % 60:02d}" if s >= 3600 else f"{s // 60}:{s % 60:02d}"


# ------------------------------------------------------------------ AppleScript

def _list_script(app: str) -> str:
    tab_index = "index of current tab of w" if app == "Safari" else "active tab index of w"
    title = "name of t" if app == "Safari" else "title of t"
    act = "(ti = ai)"
    return f'''
tell application "{app}"
  set out to ""
  set wi to 0
  repeat with w in windows
    set wi to wi + 1
    set ai to {tab_index}
    set ti to 0
    repeat with t in tabs of w
      set ti to ti + 1
      set out to out & wi & "{SEP}" & ti & "{SEP}" & {act} & "{SEP}" & (URL of t) & "{SEP}" & ({title}) & linefeed
    end repeat
  end repeat
  return out
end tell'''


def _js_script(t: Tab) -> str:
    js = PAUSE_JS.replace("\\", "\\\\").replace('"', '\\"')
    if t.app == "Safari":
        return f'tell application "Safari" to do JavaScript "{js}" in tab {t.index} of window {t.window}'
    return f'tell application "{t.app}" to execute tab {t.index} of window {t.window} javascript "{js}"'


def running_browsers() -> list[str]:
    """Running browsers, the frontmost app first."""
    try:
        from AppKit import NSWorkspace

        ws = NSWorkspace.sharedWorkspace()
        running = {a.localizedName() for a in ws.runningApplications()}
        front = ws.frontmostApplication()
        first = front.localizedName() if front else None
    except Exception:  # noqa: BLE001
        return []
    found = [b for b in BROWSERS if b in running]
    return sorted(found, key=lambda b: b != first)


async def find_for_phone() -> dict:
    """{"open_url", "title", "position_s"?, "hint"?} for the best tab, or raise LookupError."""
    apps = running_browsers()
    if not apps:
        raise LookupError("Open the video in Chrome (or Safari) on the Mac first.")
    tabs: list[Tab] = []
    denied = []
    for app in apps:
        rc, out = await osascript(_list_script(app), timeout=6)
        if rc != 0:
            if "-1743" in out or "not allowed" in out.lower():
                denied.append(app)
            log.info("browser: couldn't list %s tabs (rc %s)", app, rc)
            continue
        tabs += parse_tabs(app, out)
    if not tabs:
        if denied:
            raise PermissionError(f"macOS blocked DeskPanel from reading {denied[0]}. Allow it in System Settings → "
                                  "Privacy & Security → Automation (under Remote Trackpad).")
        raise LookupError("No open web page found in your browser.")

    best = candidates(tabs)
    if not best:
        raise LookupError("No open web page found in your browser.")
    hint = None
    # Ask each YouTube candidate for its time (and pause it); prefer one that was playing.
    timed: list[tuple[Tab, dict]] = []
    for t in best[:6]:
        if not is_youtube_video(t.url):
            continue
        rc, out = await osascript(_js_script(t), timeout=5)
        if rc != 0:
            if "JavaScript" in out or "Apple Events" in out or "-1743" in out:
                menu = "Develop" if t.app == "Safari" else "View → Developer"
                hint = JS_OFF_HINT.format(app=t.app, menu=menu)
                break
            continue
        try:
            info = json.loads(out.strip() or "null")
        except ValueError:
            info = None
        if isinstance(info, dict):
            timed.append((t, info))
            if not info.get("p"):
                break  # this one was playing: it's the one
    playing = next(((t, i) for t, i in timed if not i.get("p")), None)
    chosen, info = playing or (timed[0] if timed else (best[0], None))
    pos = float(info["t"]) if info and isinstance(info.get("t"), (int, float)) else None
    out = {"open_url": with_time(chosen.url, pos), "title": re.sub(r" - YouTube$", "", chosen.title).strip()}
    if pos is not None:
        out["position_s"] = round(pos, 1)
    if hint and is_youtube_video(chosen.url):
        out["hint"] = hint
    return out
