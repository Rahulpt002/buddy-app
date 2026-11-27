"""`media` + `media.art` topics from the laptop's now-playing app.

macOS: AppleScript against Spotify and Apple Music (the system MediaRemote framework is
closed to third-party apps on current macOS). The first call triggers macOS's "allow
<terminal/python> to control Spotify/Music" Automation prompt. Other OSes: interface only.
"""
from __future__ import annotations

import asyncio
import base64
import hashlib
import io
import logging
import platform
import tempfile
from dataclasses import dataclass
from pathlib import Path

from ..hub import ActionError, Progress, now_ms
from ..protocol import MediaArt, MediaCan, MediaData
from .base import BaseProvider, osascript

log = logging.getLogger(__name__)

SEP = "␟"  # unit separator unlikely to appear in titles
ART_RETRY_S = 30  # how long to keep asking for a cover that isn't there yet
ART_RETRY_EVERY_S = 2


@dataclass
class Track:
    app: str  # "Spotify" | "Music"
    playing: bool
    title: str
    artist: str
    album: str
    duration_ms: int
    position_ms: int
    art_url: str | None
    track_id: str


class MediaBackend:
    async def now_playing(self) -> Track | None:
        return None

    async def command(self, app: str, cmd: str, position_ms: int | None = None) -> None:
        raise ActionError("unsupported", "Media control isn't supported on this OS yet")

    async def artwork(self, t: Track) -> bytes | None:
        return None


_QUERY = f'''
set out to ""
if application "Spotify" is running then
  tell application "Spotify"
    try
      set pstate to player state as string
      if pstate is not "stopped" then
        set trk to current track
        set out to out & "Spotify{SEP}" & pstate & "{SEP}" & (name of trk) & "{SEP}" & (artist of trk) & "{SEP}" & (album of trk) & "{SEP}" & (duration of trk) & "{SEP}" & ((player position * 1000) as integer) & "{SEP}" & (artwork url of trk) & "{SEP}" & (id of trk) & linefeed
      end if
    end try
  end tell
end if
if application "Music" is running then
  tell application "Music"
    try
      set pstate to player state as string
      if pstate is not "stopped" then
        set trk to current track
        set out to out & "Music{SEP}" & pstate & "{SEP}" & (name of trk) & "{SEP}" & (artist of trk) & "{SEP}" & (album of trk) & "{SEP}" & ((duration of trk) * 1000 as integer) & "{SEP}" & ((player position * 1000) as integer) & "{SEP}{SEP}" & (persistent ID of trk) & linefeed
      end if
    end try
  end tell
end if
return out
'''


def parse_tracks(out: str) -> list[Track]:
    tracks = []
    for line in out.splitlines():
        p = line.split(SEP)
        if len(p) < 9:
            continue
        try:
            tracks.append(Track(
                app=p[0], playing=p[1] == "playing", title=p[2], artist=p[3], album=p[4],
                duration_ms=int(float(p[5] or 0)), position_ms=int(float(p[6] or 0)),
                art_url=p[7] or None, track_id=f"{p[0]}:{p[8]}",
            ))
        except ValueError:
            continue
    return tracks


def pick(tracks: list[Track]) -> Track | None:
    """Prefer whatever is playing; Spotify wins ties."""
    if not tracks:
        return None
    playing = [t for t in tracks if t.playing]
    return (playing or tracks)[0]


class MacMedia(MediaBackend):
    _last_err: str | None = None

    def __init__(self) -> None:
        self._catalog: dict[str, bytes | None] = {}  # track id -> catalogue cover (or None)

    async def now_playing(self) -> Track | None:
        rc, out = await osascript(_QUERY, timeout=4)
        if rc != 0:
            if "not allowed" in out.lower() or "-1743" in out:
                raise PermissionError(
                    "macOS blocked DeskPanel from controlling Spotify/Music. Allow it in System Settings → "
                    "Privacy & Security → Automation.")
            if out != self._last_err:  # log each distinct failure once
                log.warning("now-playing query failed: %s", out.strip()[:200])
                self._last_err = out
            return None
        self._last_err = None
        return pick(parse_tracks(out))

    async def command(self, app: str, cmd: str, position_ms: int | None = None) -> None:
        verb = {"play_pause": "playpause", "next": "next track", "prev": "previous track"}.get(cmd)
        if cmd == "seek":
            verb = f"set player position to {max(0, position_ms or 0) / 1000:.3f}"
        if verb is None or app not in ("Spotify", "Music"):
            raise ActionError("bad_request", "unknown media command")
        rc, out = await osascript(f'tell application "{app}" to {verb}')
        if rc != 0:
            raise ActionError("failed", out.strip() or "media command failed")

    async def artwork(self, t: Track) -> bytes | None:
        if t.app == "Spotify" and t.art_url:
            import httpx

            async with httpx.AsyncClient(timeout=8) as c:
                r = await c.get(t.art_url)
                return r.content if r.status_code == 200 else None
        if t.app == "Music":
            path = Path(tempfile.gettempdir()) / "deskpanel-art.bin"
            script = f'''
tell application "Music"
  try
    set d to data of artwork 1 of current track
  on error
    return "none"
  end try
end tell
set f to open for access (POSIX file "{path}") with write permission
set eof f to 0
write d to f
close access f
return "ok"'''
            rc, out = await osascript(script)
            if rc == 0 and out.strip() == "ok" and path.exists():
                return path.read_bytes()
            # Some streamed Apple Music songs never get artwork in the app's scripting
            # interface; look the cover up in Apple's public catalogue instead.
            return await self._catalog_art(t)
        return None

    async def _catalog_art(self, t: Track) -> bytes | None:
        if t.track_id in self._catalog:
            return self._catalog[t.track_id]
        import httpx

        art = None
        try:
            async with httpx.AsyncClient(timeout=8) as c:
                r = await c.get("https://itunes.apple.com/search", params={
                    "term": f"{t.artist} {t.title}", "entity": "song", "limit": 10})
                url = catalog_art_url(r.json().get("results", []), t) if r.status_code == 200 else None
                if url:
                    img = await c.get(url)
                    art = img.content if img.status_code == 200 else None
        except Exception:  # noqa: BLE001
            log.debug("catalogue artwork lookup failed", exc_info=True)
            return None  # network trouble: try again on the next retry
        if len(self._catalog) > 200:
            self._catalog.clear()
        self._catalog[t.track_id] = art
        return art


def _norm(s: str | None) -> str:
    return "".join(ch for ch in (s or "").casefold() if ch.isalnum())


def catalog_art_url(results: list[dict], t: Track, size: int = 600) -> str | None:
    """Best cover from iTunes Search results: same title and artist, same album if any."""
    same = [r for r in results if _norm(r.get("trackName")) == _norm(t.title)
            and _norm(t.artist) in _norm(r.get("artistName")) and r.get("artworkUrl100")]
    if not same:
        return None
    best = next((r for r in same if _norm(r.get("collectionName")) == _norm(t.album)), same[0])
    return best["artworkUrl100"].replace("100x100bb", f"{size}x{size}bb")


def to_jpeg_b64(raw: bytes, size: int = 512) -> str | None:
    from PIL import Image

    try:
        im = Image.open(io.BytesIO(raw)).convert("RGB")
    except Exception:  # noqa: BLE001
        return None
    im.thumbnail((size, size))
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=80)
    return base64.b64encode(buf.getvalue()).decode()


class MediaCollector(BaseProvider):
    topics = ("media", "media.art")

    def __init__(self, backend: MediaBackend | None = None) -> None:
        super().__init__()
        self.backend = backend or (MacMedia() if platform.system() == "Darwin" else MediaBackend())
        self.track: Track | None = None
        self.art_id: str | None = None
        self._art_ok = False  # the current track's cover has been sent
        self._art_retry_until = 0.0  # keep asking until then while it's missing
        self._art_next = 0.0
        self._last_pub = 0.0
        self._kick = asyncio.Event()
        self.actions = {
            "media.play_pause": self._cmd("play_pause"),
            "media.next": self._cmd("next"),
            "media.prev": self._cmd("prev"),
            "media.seek": self._seek,
        }

    async def setup(self) -> None:
        if type(self.backend) is MediaBackend:
            self.publish("media", {"status": "unsupported", "message": "Now playing isn't supported on this OS yet."})

    async def run(self) -> None:
        if type(self.backend) is MediaBackend:
            return
        while True:
            try:
                t = await self.backend.now_playing()
            except PermissionError as e:
                self.publish("media", {"status": "error", "message": str(e)})
                await asyncio.sleep(10)
                continue
            await self._update(t)
            self._kick.clear()
            try:
                await asyncio.wait_for(self._kick.wait(), 1.0)
            except asyncio.TimeoutError:
                pass

    async def _update(self, t: Track | None) -> None:
        prev = self.track
        self.track = t
        changed = (prev is None) != (t is None) or (t and prev and (
            t.track_id != prev.track_id or t.playing != prev.playing
            or abs(t.position_ms - self._expected(prev)) > 2500))
        loop = asyncio.get_running_loop()
        if changed or loop.time() - self._last_pub >= 5:
            self._last_pub = loop.time()
            self.publish("media", self._data(t))
        new_art = f"art-{hashlib.sha1(t.track_id.encode()).hexdigest()[:12]}" if t else None
        now = loop.time()
        if new_art != self.art_id:
            self.art_id, self._art_ok = new_art, False
            self._art_retry_until, self._art_next = now + ART_RETRY_S, now
            if not t:
                self.publish("media.art", MediaArt(art_id=None, b64=None))
                return
            b64 = await self._fetch_art(t)
            self._art_ok = b64 is not None
            self.publish("media.art", MediaArt(art_id=new_art, b64=b64))
            self._art_next = now + ART_RETRY_EVERY_S
        elif t and not self._art_ok and now < self._art_retry_until and now >= self._art_next:
            # Streamed Apple Music songs often have no cover yet in the first second after a
            # track change (it is still downloading); ask again until it turns up.
            self._art_next = now + ART_RETRY_EVERY_S
            b64 = await self._fetch_art(t)
            if b64 is not None:
                self._art_ok = True
                self.publish("media.art", MediaArt(art_id=new_art, b64=b64))

    async def _fetch_art(self, t: Track) -> str | None:
        try:
            raw = await self.backend.artwork(t)
            return to_jpeg_b64(raw) if raw else None
        except Exception:  # noqa: BLE001
            log.debug("artwork fetch failed", exc_info=True)
            return None

    def _expected(self, t: Track) -> int:
        # Position we'd expect now if it kept playing since the last publish.
        return t.position_ms + (1000 if t.playing else 0)

    def _data(self, t: Track | None) -> MediaData:
        if t is None:
            return MediaData(playing=False)
        return MediaData(
            playing=t.playing, source=t.app, title=t.title, artist=t.artist, album=t.album,
            duration_ms=t.duration_ms, position_ms=t.position_ms, position_at=now_ms(),
            art_id=self.art_id if self.art_id else None, can=MediaCan(),
        )

    def _cmd(self, cmd: str):
        async def handler(params: dict, progress: Progress) -> dict:
            if self.track is None:
                raise ActionError("unsupported", "Nothing is playing on the laptop")
            await self.backend.command(self.track.app, cmd)
            await asyncio.sleep(0.15)
            self._kick.set()
            return {}
        return handler

    async def _seek(self, params: dict, progress: Progress) -> dict:
        pos = params.get("position_ms")
        if not isinstance(pos, int) or pos < 0:
            raise ActionError("bad_request", "position_ms must be a non-negative integer")
        if self.track is None:
            raise ActionError("unsupported", "Nothing is playing on the laptop")
        await self.backend.command(self.track.app, "seek", pos)
        self._kick.set()
        return {}
