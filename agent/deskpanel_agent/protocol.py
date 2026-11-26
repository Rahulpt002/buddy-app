"""Typed protocol models. Source of truth for shared/protocol.md and shared/fixtures."""
from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

TOPICS = (
    "system",
    "network",
    "claude",
    "media",
    "media.art",
    "hotspot",
    "slack",
    "github",
    "gitlab",
    "shortcuts",
    "calendar",
)

ACTIONS = (
    "media.play_pause",
    "media.next",
    "media.prev",
    "media.seek",
    "shortcut.run",
    "speedtest.run",
    "slack.read",
    "slack.open",
    "mouse.setup",
    "volume.set",
    "mouse.displays",
)

Status = Literal["ok", "unconfigured", "error", "unsupported", "starting"]


class M(BaseModel):
    model_config = ConfigDict(extra="ignore")


class TopicData(M):
    status: Status = "ok"
    message: str | None = None


# ------------------------------------------------------------------ client frames


class ClientInfo(M):
    name: str = "unknown"
    platform: str = "unknown"
    app_version: str = "0"


class Hello(M):
    t: Literal["hello"]
    proto: int
    token: str | None = None
    client: ClientInfo = Field(default_factory=ClientInfo)


class Sub(M):
    t: Literal["sub"]
    topics: list[str]


class Req(M):
    t: Literal["req"]
    id: str = Field(min_length=1, max_length=64)
    action: str
    params: dict = Field(default_factory=dict)


# ------------------------------------------------------------------ topics


class Cpu(M):
    pct: float
    model: str
    cores: int | None = None
    threads: int | None = None
    temp_c: float | None = None


class Gpu(M):
    available: bool
    pct: float | None = None
    temp_c: float | None = None
    model: str | None = None
    vram_used: int | None = None
    vram_total: int | None = None
    vram_label: str = "VRAM"  # "GPU MEM" on Apple Silicon (unified memory)


class Ram(M):
    used: int
    total: int


class Disk(M):
    pct: float


class NetRate(M):
    down_bps: float
    up_bps: float


class SysHistory(M):
    interval_ms: int = 1000
    cpu: list[float]
    gpu: list[float | None]
    down: list[float] = Field(default_factory=list)  # bytes/sec
    up: list[float] = Field(default_factory=list)


class SystemData(TopicData):
    cpu: Cpu
    gpu: Gpu
    ram: Ram
    disk: Disk
    net: NetRate
    history: SysHistory


class LatencyHistory(M):
    interval_ms: int = 1000
    ms: list[float | None]


class Latency(M):
    target: str
    method: Literal["tcp", "icmp"] = "tcp"
    ms: float | None
    jitter_ms: float | None
    loss_pct: float
    history: LatencyHistory


class Usage(M):
    today: int
    month: int


class SpeedResult(M):
    down_bps: float
    up_bps: float
    ping_ms: float
    at: int


class SpeedProgress(M):
    phase: Literal["ping", "download", "upload"]
    pct: float
    down_bps: float | None = None
    up_bps: float | None = None


class Speedtest(M):
    state: Literal["idle", "running"] = "idle"
    last: SpeedResult | None = None
    progress: SpeedProgress | None = None


class NetworkData(TopicData):
    latency: Latency
    online: bool
    online_since: int | None
    last_drop: int | None
    usage: Usage
    speedtest: Speedtest


class LimitWindow(M):
    used_pct: float
    resets_at: int | None
    expired: bool = False


class Limits(M):
    source: str = "statusline"
    updated_at: int
    five_hour: LimitWindow | None = None
    seven_day: LimitWindow | None = None


class ClaudeToday(M):
    tokens: int
    output_tokens: int
    messages: int
    last_hour_tokens: int


class ClaudeDay(M):
    date: str  # YYYY-MM-DD, laptop local time
    tokens: int


class ModelUsage(M):
    family: str
    model: str
    tokens: int


class ClaudeData(TopicData):
    limits: Limits | None = None
    today: ClaudeToday
    days: list[ClaudeDay]
    models_today: list[ModelUsage]


class MediaCan(M):
    play_pause: bool = True
    next: bool = True
    prev: bool = True
    seek: bool = True


class MediaData(TopicData):
    playing: bool = False
    source: str | None = None
    title: str | None = None
    artist: str | None = None
    album: str | None = None
    duration_ms: int | None = None
    position_ms: int | None = None
    position_at: int | None = None
    rate: float = 1.0
    art_id: str | None = None
    can: MediaCan = Field(default_factory=MediaCan)


class MediaArt(TopicData):
    art_id: str | None
    mime: str = "image/jpeg"
    b64: str | None = None


# --- printer: not a topic any more (the Printer page became Hotspot); the Bambu
# collector under collectors/printer/ still builds these, so they stay.
class PrinterJob(M):
    name: str | None = None
    progress_pct: float = 0.0
    remaining_min: int | None = None
    layer: int | None = None
    total_layers: int | None = None
    speed: str | None = None


class PrinterTemps(M):
    nozzle: float | None = None
    nozzle_target: float | None = None
    bed: float | None = None
    bed_target: float | None = None
    chamber: float | None = None


class AmsSlot(M):
    slot: int
    type: str | None = None
    color: str | None = None
    name: str | None = None
    active: bool = False


class PrinterData(TopicData):
    kind: str = "bambu"
    name: str
    model: str | None = None
    state: Literal["printing", "idle", "paused", "finished", "error", "offline"]
    job: PrinterJob | None = None
    temps: PrinterTemps = Field(default_factory=PrinterTemps)
    ams: list[AmsSlot] = Field(default_factory=list)
    error: str | None = None


Grade = Literal["excellent", "good", "fair", "poor"]


class HotspotEvent(M):
    ts: int                                   # epoch ms
    kind: str                                 # Hotspot Monitor EventKind, e.g. "connectivity"
    severity: Literal["info", "warning", "critical"] = "info"
    message: str


class HotspotData(TopicData):
    """The Hotspot Monitor Overview for one phone (read from its Server)."""
    name: str | None = None                   # the phone's name on the Server
    model: str | None = None                  # "samsung SM-M526B · Android 14"
    online: bool = False                      # phone connected to the Server
    last_seen: int | None = None              # epoch ms
    updated: int | None = None                # newest telemetry, epoch ms
    # internet on the phone
    internet: bool | None = None
    down_since: int | None = None             # epoch ms, while the internet is down
    net_type: str | None = None               # "4G LTE", "5G NSA", ...
    band: str | None = None                   # "B40", "n78"
    operator: str | None = None
    # signal
    score: float | None = None                # 0..100
    grade: Grade | None = None
    rsrp: float | None = None                 # dBm
    sinr: float | None = None                 # dB
    rsrq: float | None = None                 # dB
    # speed now
    rx_bps: float | None = None
    tx_bps: float | None = None
    ping_ms: float | None = None
    loss_pct: float | None = None
    jitter_ms: float | None = None
    # sharing
    tether_on: bool | None = None             # USB tethering or Wi-Fi hotspot on
    clients: int | None = None
    # battery
    battery_pct: float | None = None
    current_ma: float | None = None           # + charging, - draining
    charge_status: str | None = None          # "charging", "discharging", "full", "not charging"
    plug: str | None = None
    charge_note: str | None = None            # "charging paused (heat)", "limit 80%"
    low_battery: bool = False
    # heat
    battery_c: float | None = None
    cpu_c: float | None = None
    modem_c: float | None = None
    thermal: str | None = None                # "None", "Light", ... "Shutdown"
    heat: Literal["ok", "warm", "hot"] = "ok"  # battery vs the phone's warn / stop-charge limits
    radio_resting: bool = False
    # data
    cycle_used: float | None = None           # bytes this billing cycle
    quota: float | None = None                # bytes, null = no quota set
    today_used: float | None = None
    cycle_start: str | None = None            # ISO date
    # uptime
    uptime_s: float | None = None
    agent_uptime_s: float | None = None
    boot_count: int | None = None
    boot_reason: str | None = None
    events: list[HotspotEvent] = Field(default_factory=list)  # newest first, at most 8
    session_expires: int | None = None        # epoch ms: DeskPanel's sign-in to the Server


class SlackMsg(M):
    id: str                 # "<channel_id>:<ts>"
    ts: int                 # epoch ms
    channel_id: str
    channel: str            # "#general", or the person / people for DMs
    kind: Literal["dm", "group", "mention"]
    sender: str
    sender_color: str       # stable per-person colour, "#RRGGBB"
    text: str               # plain text: mentions/links resolved, at most ~400 chars
    thread: bool = False    # a reply inside a thread
    unread: bool = True


class SlackData(TopicData):
    team: str | None = None
    user: str | None = None
    unread: int = 0
    messages: list[SlackMsg] = Field(default_factory=list)  # newest first


class ContribDay(M):
    date: str
    count: int
    level: int


class GithubYear(M):
    total: int
    commits: int
    private: int
    issues: int
    prs: int = 0
    reviews: int = 0
    weeks: list[list[ContribDay]]


class BestDay(M):
    date: str
    count: int


class Streak(M):
    current: int
    longest: int
    best_day: BestDay | None


class Week(M):
    this: list[int | None]  # Sun..Sat, None for future days
    last: list[int]
    this_total: int
    delta: int


class RepoCount(M):
    name: str
    count: int


class GithubData(TopicData):
    user: str | None = None
    fetched_at: int | None = None
    year: GithubYear | None = None
    streak: Streak | None = None
    week: Week | None = None
    top_repos: list[RepoCount] = Field(default_factory=list)


class TileState(M):
    active: bool = False
    detail: str | None = None


class Tile(M):
    id: str
    label: str
    icon: str
    color: str | None = None
    state: TileState = Field(default_factory=TileState)


class ShortcutsData(TopicData):
    tiles: list[Tile]
    volume_pct: int | None = None


class CalEvent(M):
    id: str
    title: str
    start: int
    end: int
    all_day: bool = False
    location: str | None = None
    calendar: str | None = None
    color: str | None = None


class CalendarData(TopicData):
    events: list[CalEvent] = Field(default_factory=list)


TOPIC_MODELS: dict[str, type[M]] = {
    "system": SystemData,
    "network": NetworkData,
    "claude": ClaudeData,
    "media": MediaData,
    "media.art": MediaArt,
    "hotspot": HotspotData,
    "slack": SlackData,
    "github": GithubData,
    "gitlab": GithubData,  # same shape: the phone shows either with one layout
    "shortcuts": ShortcutsData,
    "calendar": CalendarData,
}
