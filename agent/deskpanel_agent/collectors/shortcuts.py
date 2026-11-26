"""`shortcuts` topic + `shortcut.run`. The phone only ever sends a tile id; ids map to
built-in actions or to `[[shortcuts.custom]]` argv commands from the agent config
(executed without a shell). Anything else is rejected."""
from __future__ import annotations

import asyncio
import datetime as dt
import logging
import os
import platform
import re
from pathlib import Path

from ..config import CustomShortcut
from ..hub import ActionError, Progress
from ..protocol import ShortcutsData, Tile, TileState
from ..shortcuts_catalog import BUILTIN_TILES
from ..storage import Store
from .base import BaseProvider, osascript, run_cmd

log = logging.getLogger(__name__)


class AudioState:
    def __init__(self, out_vol: int, in_vol: int, muted: bool):
        self.out_vol, self.in_vol, self.muted = out_vol, in_vol, muted


class ShortcutBackend:
    supported: set[str] = set()

    async def audio(self) -> AudioState | None:
        return None

    async def run(self, tile_id: str, audio: AudioState | None) -> str:
        raise ActionError("unsupported", "Not supported on this OS yet")

    async def set_volume(self, pct: int) -> None:
        raise ActionError("unsupported", "Not supported on this OS yet")


_VOL = re.compile(r"output volume:([^,]+), input volume:([^,]+), alert volume:[^,]+, output muted:(\w+)")


class MacShortcuts(ShortcutBackend):
    supported = {"mic.toggle", "sound.toggle", "volume.down", "volume.up", "screenshot", "terminal",
                 "downloads", "lock"}
    STEP = 6  # ~ one keyboard volume notch

    def __init__(self, store: Store):
        self.store = store

    async def audio(self) -> AudioState | None:
        rc, out = await osascript("get volume settings")
        m = _VOL.search(out)
        if rc != 0 or not m:
            return None
        num = lambda s: int(s) if s.isdigit() else 0  # noqa: E731  ("missing value" on some outputs)
        return AudioState(num(m.group(1)), num(m.group(2)), m.group(3) == "true")

    async def set_volume(self, pct: int) -> None:
        await osascript(f"set volume output volume {pct} without output muted")

    async def run(self, tile_id: str, a: AudioState | None) -> str:
        if tile_id == "mic.toggle":
            if a and a.in_vol > 0:
                self.store.set("mic.restore", a.in_vol)
                await osascript("set volume input volume 0")
                return "Microphone muted"
            await osascript(f"set volume input volume {self.store.get('mic.restore', 60)}")
            return "Microphone on"
        if tile_id == "sound.toggle":
            muted = bool(a and a.muted)
            await osascript(f"set volume output muted {'false' if muted else 'true'}")
            return "Sound on" if muted else "Sound muted"
        if tile_id in ("volume.up", "volume.down"):
            cur = a.out_vol if a else 50
            v = max(0, min(100, cur + (self.STEP if tile_id == "volume.up" else -self.STEP)))
            await osascript(f"set volume output volume {v} without output muted")
            return f"Volume {v}%"
        if tile_id == "screenshot":
            rc, loc = await run_cmd("defaults", "read", "com.apple.screencapture", "location")
            folder = Path(os.path.expanduser(loc.strip())) if rc == 0 and loc.strip() else Path.home() / "Desktop"
            path = folder / f"DeskPanel {dt.datetime.now():%Y-%m-%d at %H.%M.%S}.png"
            rc, out = await run_cmd("screencapture", "-x", str(path), timeout=10)
            if rc != 0 or not path.exists():
                raise ActionError("failed", "Screenshot failed. Allow Screen Recording for the agent in "
                                            "System Settings → Privacy & Security.")
            return f"Saved {path.name}"
        if tile_id == "terminal":
            await run_cmd("open", "-a", "Terminal")
            return "Terminal opened"
        if tile_id == "downloads":
            await run_cmd("open", str(Path.home() / "Downloads"))
            return "Downloads opened"
        if tile_id == "lock":
            # Sleeps the display; locks when "Require password immediately" is set
            # (System Settings → Lock Screen), which is the macOS default.
            await run_cmd("pmset", "displaysleepnow")
            return "Laptop locked"
        raise ActionError("unsupported", f"{tile_id} isn't available on macOS")


class ShortcutsCollector(BaseProvider):
    topics = ("shortcuts",)

    def __init__(self, store: Store, custom: list[CustomShortcut], backend: ShortcutBackend | None = None):
        super().__init__()
        self.backend = backend or (MacShortcuts(store) if platform.system() == "Darwin" else ShortcutBackend())
        self.custom = {c.id: c for c in custom if c.id not in {t.id for t in BUILTIN_TILES}}
        self.audio: AudioState | None = None
        self.actions = {"shortcut.run": self.run_tile, "volume.set": self.set_volume}
        # "Watch on phone" reads the Mac's browser (AppleScript), so only with the Mac backend.
        self._browser = isinstance(self.backend, MacShortcuts)
        self._kick = asyncio.Event()

    def tiles(self) -> list[Tile]:
        a = self.audio
        out = []
        for t in BUILTIN_TILES:
            if t.id not in self.backend.supported and not (t.id == "phone.watch" and self._browser):
                continue
            t = t.model_copy(deep=True)
            if t.id == "mic.toggle":
                t.state = TileState(active=bool(a and a.in_vol == 0))
            elif t.id == "sound.toggle":
                t.state = TileState(active=bool(a and a.muted))
            elif t.id in ("volume.up", "volume.down") and a:
                t.state = TileState(detail=f"Volume {a.out_vol}%")
            out.append(t)
        out += [Tile(id=c.id, label=c.label, icon=c.icon, color=c.color) for c in self.custom.values()]
        return out

    async def run(self) -> None:
        while True:
            self.audio = await self.backend.audio()
            self.publish("shortcuts", ShortcutsData(tiles=self.tiles(), volume_pct=self.audio.out_vol if self.audio else None))
            self._kick.clear()
            try:
                await asyncio.wait_for(self._kick.wait(), 3.0)
            except asyncio.TimeoutError:
                pass

    async def run_tile(self, params: dict, progress: Progress) -> dict:
        tid = params.get("id")
        if not isinstance(tid, str):
            raise ActionError("bad_request", "id required")
        if tid == "phone.watch" and self._browser:
            return await self._watch_on_phone()
        if tid in self.custom:
            c = self.custom[tid]
            rc, out = await run_cmd(*c.command, timeout=20)
            if rc != 0:
                raise ActionError("failed", out.strip()[:200] or f"{c.label} failed")
            msg = f"{c.label} done"
        elif tid in self.backend.supported:
            msg = await self.backend.run(tid, self.audio)
        else:
            raise ActionError("forbidden", f"{tid!r} is not an allowed shortcut")
        self._kick.set()
        return {"message": msg}

    async def _watch_on_phone(self) -> dict:
        """Find the Mac browser's video/page; the phone opens `open_url` itself."""
        from ..browser_tab import find_for_phone, fmt_time

        try:
            r = await find_for_phone()
        except PermissionError as e:
            raise ActionError("failed", str(e)) from None
        except LookupError as e:
            raise ActionError("failed", str(e)) from None
        title = r.get("title") or "the page"
        at = f" from {fmt_time(r['position_s'])}" if r.get("position_s") else ""
        msg = f"Playing “{title}” on the phone{at}"
        if r.get("hint"):
            msg += ". " + r["hint"]
        log.info("phone.watch: sent a %s link to the phone", "YouTube" if "youtu" in r["open_url"] else "web")
        return {"message": msg, "open_url": r["open_url"]}

    async def set_volume(self, params: dict, progress: Progress) -> dict:
        """`volume.set {pct}`: the laptop's output volume to an exact level (a volume slider)."""
        pct = params.get("pct")
        if not isinstance(pct, (int, float)) or isinstance(pct, bool):
            raise ActionError("bad_request", "pct (0-100) required")
        v = max(0, min(100, round(pct)))
        await self.backend.set_volume(v)
        self._kick.set()
        return {"volume_pct": v}
