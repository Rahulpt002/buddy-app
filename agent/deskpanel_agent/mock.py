"""--mock: realistic fake data for every topic (values from the reference screenshots)."""
from __future__ import annotations

import asyncio
import datetime as dt
import math
import random
from collections import deque

from .hub import ActionError, Hub, Progress, now_ms
from .protocol import (
    BestDay, CalendarData, CalEvent, ClaudeData, ClaudeDay, ClaudeToday, ContribDay,
    Cpu, Disk, GithubData, GithubYear, Gpu, Latency, LatencyHistory, LimitWindow,
    Limits, MediaArt, MediaData, ModelUsage, NetRate, NetworkData,
    HotspotData, HotspotEvent, Ram, RepoCount, ShortcutsData, SlackData, SlackMsg, SpeedProgress,
    SpeedResult, Speedtest, Streak, SysHistory, SystemData, TileState, Usage, Week,
)
from .shortcuts_catalog import BUILTIN_TILES

GB = 1024**3
TRACKS = [
    ("Midnight City Lights", "Synth Dreams", "Neon Skyline", 241),
    ("Low Tide Radio", "Harbor Static", "Salt & Signal", 214),
    ("Paper Planets", "Juno Vale", "Orbit Season", 192),
    ("Afterglow Freeway", "The Night Shift", "Overpass", 265),
]


def _clamp(v: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, v))


class MockProvider:
    topics = ("system", "network", "claude", "media", "media.art", "hotspot", "slack",
              "github", "gitlab", "shortcuts", "calendar")

    def __init__(self) -> None:
        self.r = random.Random(42)
        self.hub: Hub | None = None
        self._task: asyncio.Task | None = None
        t0 = now_ms()
        # system
        self.cpu, self.gpu, self.gpu_temp = 30.0, 48.0, 52.0
        self.ram, self.vram = 18.4, 6.2
        self.down, self.up = 1.8e6, 220e3
        self.cpu_hist = deque((30 + 6 * math.sin(i / 4) for i in range(60)), maxlen=60)
        self.gpu_hist = deque((48 + 7 * math.sin(i / 5) for i in range(60)), maxlen=60)
        self.down_hist = deque((1.8e6 + 0.6e6 * math.sin(i / 3) for i in range(60)), maxlen=60)
        self.up_hist = deque((220e3 + 80e3 * math.sin(i / 4) for i in range(60)), maxlen=60)
        # network
        self.lat_hist = deque((16 + self.r.random() * 3 + (14 if i in (40, 96) else 0) for i in range(120)),
                              maxlen=120)
        self.online_since = t0 - (3 * 86400 + 5 * 3600) * 1000
        self.speed_last = SpeedResult(down_bps=942e6 / 8, up_bps=38e6 / 8, ping_ms=9, at=t0 - 2 * 3600_000)
        self.speed: Speedtest = Speedtest(last=self.speed_last)
        # media
        self.track, self.playing = 0, True
        self.pos_ms, self.pos_at = 75_000, t0
        # hotspot (the roof phone)
        self.hs_score, self.hs_rx, self.hs_bat = 68.0, 18.4e6, 82.0
        # shortcuts
        self.mic_muted, self.sound_muted, self.volume = True, False, 40
        # slack: (minutes ago, channel id, channel, kind, sender, text, thread, unread)
        self.slack = [
            (2, "D01", "Maya Chen", "dm", "Maya Chen", "Are you free for a quick call about the release notes? 10 min max", False, True),
            (9, "C01", "#deploys", "mention", "Jonas Weber", "@you staging is green, can you approve the prod deploy when you get a sec?", False, True),
            (24, "G01", "Priya, Leo", "group", "Leo Martins", "Pushed the new onboarding screens, thoughts welcome", False, True),
            (51, "C02", "#design", "mention", "Priya Nair", "@you I left comments on the settings mockups", True, False),
            (95, "D02", "Sam Okafor", "dm", "Sam Okafor", "Thanks for the review yesterday!", False, False),
            (180, "C03", "#general", "mention", "Ana Ruiz", "@here lunch order closes at 12:30", False, False),
        ]
        self.slack_t0 = t0

        self.actions = {
            "media.play_pause": self._play_pause,
            "media.next": self._next,
            "media.prev": self._prev,
            "media.seek": self._seek,
            "shortcut.run": self._shortcut,
            "speedtest.run": self._speedtest,
            "slack.read": self._slack_read,
            "slack.open": self._slack_read,
        }

    # -------------------------------------------------------------- lifecycle

    async def start(self, hub: Hub) -> None:
        self.hub = hub
        for fn in (self._pub_system, self._pub_network, self._pub_claude, self._pub_media,
                   self._pub_art, self._pub_hotspot, self._pub_slack, self._pub_github, self._pub_gitlab,
                   self._pub_shortcuts, self._pub_calendar):
            fn()
        self._task = asyncio.create_task(self._loop())

    async def stop(self) -> None:
        if self._task:
            self._task.cancel()

    def on_demand(self, topic: str, wanted: bool) -> None:
        pass

    async def _loop(self) -> None:
        n = 0
        while True:
            await asyncio.sleep(1)
            n += 1
            self._tick()
            self._pub_system()
            self._pub_network()
            if n % 5 == 0:
                self._pub_claude()
                self._pub_media()
                self._pub_hotspot()
                self._pub_shortcuts()
            if n % 180 == 0:  # a new DM every 3 minutes, to exercise the phone's auto-open
                self.slack_t0 = now_ms()
                self.slack.insert(0, (0, "D01", "Maya Chen", "dm", "Maya Chen", f"Ping #{n // 180}: still around?", False, True))
                del self.slack[12:]
                self._pub_slack()

    def _tick(self) -> None:
        w = lambda v, a, lo, hi: _clamp(v + (self.r.random() - 0.5) * a, lo, hi)  # noqa: E731
        self.cpu = w(self.cpu, 9, 12, 72)
        self.gpu = w(self.gpu, 8, 30, 80)
        self.gpu_temp = _clamp(44 + self.gpu * 0.2 + (self.r.random() - 0.5), 40, 70)
        self.ram = w(self.ram, 0.2, 17.6, 19.6)
        self.vram = w(self.vram, 0.1, 5.8, 6.8)
        self.down = w(self.down, 0.6e6, 0.2e6, 4.2e6)
        self.up = w(self.up, 60e3, 60e3, 480e3)
        self.cpu_hist.append(self.cpu)
        self.down_hist.append(self.down)
        self.up_hist.append(self.up)
        self.gpu_hist.append(self.gpu)
        spike = self.r.random() < 0.03
        self.lat_hist.append(30 + self.r.random() * 10 if spike else 15 + self.r.random() * 4)
        if self.r.random() < 0.2:
            self.hs_score = max(40, min(86, self.hs_score + self.r.uniform(-2, 2)))
            self.hs_rx = max(2e6, min(60e6, self.hs_rx * self.r.uniform(.8, 1.25)))
            self.hs_bat = max(60, min(90, self.hs_bat + self.r.uniform(-.3, .3)))
        if self.playing and self._pos() >= TRACKS[self.track][3] * 1000:
            self._set_track((self.track + 1) % len(TRACKS))

    # -------------------------------------------------------------- publishers

    def _pub(self, topic: str, data) -> None:
        assert self.hub
        self.hub.publish(topic, data)

    def _pub_system(self) -> None:
        self._pub("system", SystemData(
            cpu=Cpu(pct=round(self.cpu, 1), model="Ryzen 7 7800X3D 8-Core", cores=8, threads=16),
            gpu=Gpu(available=True, pct=round(self.gpu, 1), temp_c=round(self.gpu_temp),
                    model="GeForce RTX 4070", vram_used=int(self.vram * GB), vram_total=12 * GB),
            ram=Ram(used=int(self.ram * GB), total=32 * GB),
            disk=Disk(pct=58.0),
            net=NetRate(down_bps=self.down, up_bps=self.up),
            history=SysHistory(cpu=[round(v, 1) for v in self.cpu_hist],
                               gpu=[round(v, 1) for v in self.gpu_hist],
                               down=[round(v) for v in self.down_hist], up=[round(v) for v in self.up_hist]),
        ))

    def _pub_network(self) -> None:
        hist = list(self.lat_hist)
        last20 = hist[-20:]
        jitter = sum(abs(a - b) for a, b in zip(last20, last20[1:])) / (len(last20) - 1)
        self._pub("network", NetworkData(
            latency=Latency(target="1.1.1.1:443", ms=round(hist[-1], 1), jitter_ms=round(jitter, 1),
                            loss_pct=0.0, history=LatencyHistory(ms=[round(v, 1) for v in hist])),
            online=True, online_since=self.online_since, last_drop=self.online_since,
            usage=Usage(today=int(3.2 * GB), month=int(412.0 * GB)),
            speedtest=self.speed,
        ))

    def _pub_claude(self) -> None:
        now = dt.datetime.now()
        reset5 = int((now + dt.timedelta(hours=2, minutes=12)).timestamp() * 1000)
        sat = now + dt.timedelta(days=(5 - now.weekday()) % 7 or 7)
        reset7 = int(sat.replace(hour=14, minute=1, second=0, microsecond=0).timestamp() * 1000)
        days = [28.4, 6.9, 21.5, 55.3, 43.1, 62.0, 48.2]
        self._pub("claude", ClaudeData(
            limits=Limits(updated_at=now_ms(),
                          five_hour=LimitWindow(used_pct=38.0, resets_at=reset5),
                          seven_day=LimitWindow(used_pct=61.0, resets_at=reset7)),
            today=ClaudeToday(tokens=48_200_000, output_tokens=182_000, messages=214,
                              last_hour_tokens=6_100_000),
            days=[ClaudeDay(date=(now.date() - dt.timedelta(days=6 - i)).isoformat(),
                            tokens=int(v * 1e6)) for i, v in enumerate(days)],
            models_today=[ModelUsage(family="opus", model="claude-opus-5-5", tokens=31_000_000),
                          ModelUsage(family="sonnet", model="claude-sonnet-5-5", tokens=15_100_000),
                          ModelUsage(family="haiku", model="claude-haiku-5-5", tokens=2_100_000)],
        ))

    def _pos(self) -> int:
        if not self.playing:
            return self.pos_ms
        return self.pos_ms + (now_ms() - self.pos_at)

    def _pub_media(self) -> None:
        title, artist, album, length = TRACKS[self.track]
        self._pub("media", MediaData(
            playing=self.playing, source="Spotify", title=title, artist=artist, album=album,
            duration_ms=length * 1000, position_ms=self._pos(), position_at=now_ms(),
            art_id=f"mock-{self.track}",
        ))

    def _pub_art(self) -> None:
        # No real image in mock mode: the app draws its generated fallback artwork.
        self._pub("media.art", MediaArt(art_id=f"mock-{self.track}", b64=None))

    def _pub_hotspot(self) -> None:
        t = now_ms()
        sc = round(self.hs_score)
        ev = [(4, "connectivity", "info", "Internet back after 42 s"),
              (5, "watchdog_action", "warning", "Watchdog: mobile data cycled, internet recovered"),
              (38, "cell_change", "info", "Serving cell changed: PCI 211 to 87 (B40)"),
              (95, "temp_normal", "info", "Battery back to 36 °C"),
              (130, "temp_warning", "warning", "Battery at 41 °C"),
              (300, "charging_resumed", "info", "Charging resumed (below 75%)"),
              (720, "boot", "info", "Phone booted (boot #214, reason: watchdog)"),
              (1440, "agent_start", "info", "Agent started after boot")]
        self._pub("hotspot", HotspotData(
            name="Roof phone", model="samsung SM-M526B · Android 14", online=True,
            last_seen=t - 12_000, updated=t - 20_000, internet=True, net_type="5G NSA", band="B40 + n78",
            operator="Jio 5G", score=sc, grade="excellent" if sc >= 75 else "good" if sc >= 55 else "fair",
            rsrp=-86, sinr=14.5, rsrq=-11, rx_bps=self.hs_rx, tx_bps=self.hs_rx * .18, ping_ms=34,
            loss_pct=0, jitter_ms=4.2, tether_on=True, clients=1, battery_pct=round(self.hs_bat),
            current_ma=-180, charge_status="discharging", plug="usb", charge_note="limit 80%",
            battery_c=37.5, cpu_c=44.0, modem_c=41.5, thermal="Light", heat="ok",
            cycle_used=148.6e9, quota=300e9, today_used=6.2e9, cycle_start="2026-11-05",
            uptime_s=4 * 86400 + 7 * 3600, agent_uptime_s=4 * 86400 + 7 * 3600 - 40, boot_count=214,
            boot_reason="watchdog",
            events=[HotspotEvent(ts=t - m * 60_000, kind=k, severity=sv, message=msg) for (m, k, sv, msg) in ev],
            session_expires=t + 21 * 86400_000,
        ))

    def _pub_slack(self) -> None:
        msgs = [SlackMsg(id=f"{c}:{self.slack_t0 - m * 60_000}", ts=self.slack_t0 - m * 60_000, channel_id=c,
                         channel=ch, kind=k, sender=who, sender_color=["#E8912D", "#2EB67D", "#36C5F0", "#E01E5A",
                                                                       "#9B6BF2", "#ECB22E"][len(who) % 6],
                         text=txt, thread=th, unread=u)
                for (m, c, ch, k, who, txt, th, u) in self.slack]
        self._pub("slack", SlackData(team="Acme", user="you", unread=sum(m.unread for m in msgs), messages=msgs))

    def _pub_github(self) -> None:
        today = dt.date.today()
        sun = today - dt.timedelta(days=(today.weekday() + 1) % 7)  # start of this week
        first = sun - dt.timedelta(weeks=52)
        r = random.Random(7)
        busy = {1: .35, 2: .3, 3: .15, 4: .35, 5: .6, 6: .75, 7: .5, 8: .45, 9: .55, 10: .8, 11: .85, 12: .3}
        this_w = [0, 75, 68, 48, 58, 32, 0]
        last_w = [0, 28, 14, 20, 24, 10, 5]

        def level(c: int) -> int:
            return 0 if c == 0 else 1 if c < 4 else 2 if c < 9 else 3 if c < 15 else 4

        weeks: list[list[ContribDay]] = []
        for w in range(53):
            col = []
            for d in range(7):
                day = first + dt.timedelta(days=w * 7 + d)
                if day > today:
                    break
                if w == 52:
                    c = this_w[d]
                elif w == 51:
                    c = last_w[d]
                else:
                    p = busy[day.month] * (0.5 if d in (0, 6) else 1)
                    c = math.ceil(r.random() ** 2 * 22) if r.random() < p else 0
                col.append(ContribDay(date=day.isoformat(), count=c, level=level(c)))
            weeks.append(col)
        dow = (today.weekday() + 1) % 7
        this = [v if i <= dow else None for i, v in enumerate(this_w)]
        self._pub("github", GithubData(
            user="octocat", fetched_at=now_ms(),
            year=GithubYear(total=1033, commits=120, private=907, issues=1, weeks=weeks),
            streak=Streak(current=5, longest=10,
                          best_day=BestDay(date=f"{today.year}-11-16", count=75)),
            week=Week(this=this, last=last_w, this_total=281, delta=180),
            top_repos=[RepoCount(name=n, count=c) for n, c in
                       [("pixel-garden", 222), ("tide-engine", 201), ("deskhub", 111), ("lumen-notes", 88)]],
        ))

    def _pub_gitlab(self) -> None:
        # Same shape as GitHub; different, sparser activity so the switch visibly changes.
        today = dt.date.today()
        sun = today - dt.timedelta(days=(today.weekday() + 1) % 7)
        first = sun - dt.timedelta(weeks=52)
        r = random.Random(11)
        weeks = []
        for w in range(53):
            col = []
            for d in range(7):
                day = first + dt.timedelta(days=w * 7 + d)
                if day > today:
                    break
                c = math.ceil(r.random() ** 3 * 35) if r.random() < (0.35 if d not in (0, 6) else 0.1) else 0
                lvl = 0 if c == 0 else 1 if c < 10 else 2 if c < 20 else 3 if c < 30 else 4
                col.append(ContribDay(date=day.isoformat(), count=c, level=lvl))
            weeks.append(col)
        dow = (today.weekday() + 1) % 7
        this_w, last_w = [0, 12, 4, 9, 0, 6, 0], [0, 7, 3, 0, 5, 2, 0]
        self._pub("gitlab", GithubData(
            user="octolab", fetched_at=now_ms(),
            year=GithubYear(total=642, commits=388, private=410, issues=23, prs=31, weeks=weeks),
            streak=Streak(current=2, longest=7, best_day=BestDay(date=f"{today.year}-09-03", count=41)),
            week=Week(this=[v if i <= dow else None for i, v in enumerate(this_w)], last=last_w,
                      this_total=31, delta=14),
            top_repos=[RepoCount(name=n, count=c) for n, c in
                       [("infra-pipelines", 141), ("billing-api", 96), ("design-tokens", 52), ("ops-runbooks", 30)]],
        ))

    def _pub_shortcuts(self) -> None:
        tiles = []
        for t in BUILTIN_TILES:
            t = t.model_copy(deep=True)
            if t.id == "mic.toggle":
                t.state = TileState(active=self.mic_muted)
            elif t.id == "sound.toggle":
                t.state = TileState(active=self.sound_muted)
            elif t.id in ("volume.up", "volume.down"):
                t.state = TileState(detail=f"Volume {self.volume}%")
            tiles.append(t)
        self._pub("shortcuts", ShortcutsData(tiles=tiles, volume_pct=self.volume))

    def _pub_calendar(self) -> None:
        # Mock ICS events relative to now: one finished, one in ~25 min, one later today,
        # three later this week. On the phone these merge with device-calendar events.
        now = dt.datetime.now().replace(second=0, microsecond=0)
        work, personal = ("Work", "#5AA9FF"), ("Personal", "#C18CFF")

        def rel(minutes: int) -> dt.datetime:
            t = now + dt.timedelta(minutes=minutes)
            return t.replace(minute=(t.minute // 5) * 5)

        def on(weekday: int, h: int, m: int) -> dt.datetime:  # next given weekday (Mon=0)
            days = (weekday - now.weekday()) % 7 or 7
            return (now + dt.timedelta(days=days)).replace(hour=h, minute=m)

        ev = [
            ("Team standup", rel(-150), 15, "Zoom", work),
            ("Lunch with Sam", rel(25), 60, "Corner Cafe", personal),
            ("Design review", rel(210), 45, "Google Meet", work),
            ("Filament pickup", on(5, 10, 0), 30, "Maker Supply Co.", personal),
            ("Team standup", on(0, 9, 0), 15, "Zoom", work),
            ("Game night", on(1, 19, 30), 120, "Discord", personal),
        ]
        ms = lambda t: int(t.timestamp() * 1000)  # noqa: E731
        self._pub("calendar", CalendarData(events=[
            CalEvent(id=f"mock-{i}", title=t, start=ms(st), end=ms(st) + mins * 60_000,
                     location=loc, calendar=cal, color=col)
            for i, (t, st, mins, loc, (cal, col)) in enumerate(ev)
        ]))

    # -------------------------------------------------------------- actions

    def _set_track(self, i: int) -> None:
        self.track = i
        self.pos_ms, self.pos_at = 0, now_ms()
        self._pub_media()
        self._pub_art()

    async def _play_pause(self, params: dict, progress: Progress) -> dict:
        self.pos_ms, self.pos_at = self._pos(), now_ms()
        self.playing = not self.playing
        self._pub_media()
        return {"playing": self.playing}

    async def _next(self, params: dict, progress: Progress) -> None:
        self._set_track((self.track + 1) % len(TRACKS))

    async def _prev(self, params: dict, progress: Progress) -> None:
        if self._pos() > 5000:
            self.pos_ms, self.pos_at = 0, now_ms()
            self._pub_media()
        else:
            self._set_track((self.track - 1) % len(TRACKS))

    async def _seek(self, params: dict, progress: Progress) -> None:
        pos = params.get("position_ms")
        if not isinstance(pos, int) or pos < 0:
            raise ActionError("bad_request", "position_ms must be a non-negative integer")
        self.pos_ms, self.pos_at = min(pos, TRACKS[self.track][3] * 1000), now_ms()
        self._pub_media()

    async def _shortcut(self, params: dict, progress: Progress) -> dict:
        sid = params.get("id")
        if sid == "mic.toggle":
            self.mic_muted = not self.mic_muted
        elif sid == "sound.toggle":
            self.sound_muted = not self.sound_muted
        elif sid == "volume.up":
            self.volume, self.sound_muted = min(100, self.volume + 10), False
        elif sid == "volume.down":
            self.volume, self.sound_muted = max(0, self.volume - 10), False
        elif sid not in {t.id for t in BUILTIN_TILES}:
            raise ActionError("forbidden", f"{sid!r} is not an allowed shortcut")
        self._pub_shortcuts()
        return {"id": sid}

    async def _speedtest(self, params: dict, progress: Progress) -> dict:
        if self.speed.state == "running":
            raise ActionError("busy", "A speed test is already running")
        self.speed = Speedtest(state="running", last=self.speed_last,
                               progress=SpeedProgress(phase="ping", pct=0))
        self._pub_network()
        steps = 40
        for i in range(1, steps + 1):
            await asyncio.sleep(0.2)
            p = i / steps
            phase = "ping" if p < 0.1 else "download" if p < 0.6 else "upload"
            down = 920e6 / 8 * min(1, p / 0.3) + self.r.uniform(-4e6, 4e6) if p >= 0.1 else None
            up = 38e6 / 8 * min(1, (p - 0.6) / 0.25) if p >= 0.6 else None
            self.speed.progress = SpeedProgress(phase=phase, pct=round(p * 100), down_bps=down, up_bps=up)
            await progress(self.speed.progress.model_dump(mode="json"))
            self._pub_network()
        self.speed_last = SpeedResult(down_bps=936e6 / 8, up_bps=39e6 / 8, ping_ms=8, at=now_ms())
        self.speed = Speedtest(last=self.speed_last)
        self._pub_network()
        return self.speed_last.model_dump(mode="json")

    async def _slack_read(self, params: dict, progress: Progress) -> dict:
        mid, cid, every = params.get("id"), params.get("channel_id"), params.get("all")
        t0 = self.slack_t0
        self.slack = [(m, c, ch, k, who, txt, th, u and not (every or c == cid or f"{c}:{t0 - m * 60_000}" == mid))
                      for (m, c, ch, k, who, txt, th, u) in self.slack]
        self._pub_slack()
        return {"message": "Opened in Slack"} if cid and not mid else {}
