"""`hotspot` topic: the Hotspot Monitor Overview (the roof phone that shares mobile data),
read from the Hotspot Monitor Server's REST API.

It polls `GET /api/device` and `GET /api/events` every 30 s, and the phone's settings
(data quota, temperature limits) every 10 minutes. It deliberately does NOT open the
Dashboard WebSocket: a subscribed Dashboard switches the roof phone to its fast telemetry
rate (every 5 s instead of 60 s), and DeskPanel is on all day.

Auth: a normal Dashboard session token (password + TOTP), created once with
`deskpanel-agent hotspot-login` and stored in ~/.deskpanel/config.toml (0600). Use a
*viewer* account: it can read everything here and can't send commands. Sessions last 30
days; when it expires the page asks you to sign in again. The token is never logged.

The last good payload is cached in the Store and published on startup; network failures
keep showing it (the phone app marks the topic stale on its own).
"""
from __future__ import annotations

import asyncio
import datetime as dt
import logging
from typing import Any

import httpx

from ..config import HotspotCfg
from ..protocol import HotspotData, HotspotEvent
from ..storage import Store
from .base import BaseProvider

log = logging.getLogger(__name__)

POLL_S = 30
SETTINGS_EVERY_S = 10 * 60
CACHE_KEY = "hotspot.cache"
EVENTS = 8

UNCONFIGURED_MSG = ("Sign in to your Hotspot Monitor Server: run `deskpanel-agent hotspot-login` "
                    "on the laptop (a viewer account is enough).")
EXPIRED_MSG = ("The Hotspot Monitor sign-in expired or was revoked. Run "
               "`deskpanel-agent hotspot-login` on the laptop again.")
ENROLL_MSG = ("That Hotspot Monitor account has no authenticator app yet. Sign in to the "
              "Dashboard once to set it up, then run `deskpanel-agent hotspot-login` again.")

NET_TYPE = {
    "LTE": "4G LTE", "NR_NSA": "5G NSA", "NR_SA": "5G SA", "WCDMA": "3G WCDMA",
    "GSM": "2G GSM", "CDMA": "CDMA", "TDSCDMA": "3G TD-SCDMA", "UNKNOWN": "Unknown",
}
THERMAL = ("None", "Light", "Moderate", "Severe", "Critical", "Emergency", "Shutdown")


class AuthError(Exception):
    def __init__(self, msg: str):
        super().__init__(msg)
        self.msg = msg


def iso_ms(s: Any) -> int | None:
    if not isinstance(s, str) or not s:
        return None
    try:
        return int(dt.datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp() * 1000)
    except ValueError:
        return None


def grade(score: float | None) -> str | None:
    """Same thresholds as @hsm/shared gradeScore."""
    if score is None:
        return None
    return "excellent" if score >= 75 else "good" if score >= 55 else "fair" if score >= 35 else "poor"


def _num(v: Any) -> float | None:
    return float(v) if isinstance(v, (int, float)) and not isinstance(v, bool) else None


def _sum(a: Any, b: Any) -> float | None:
    x, y = _num(a), _num(b)
    return None if x is None and y is None else (x or 0) + (y or 0)


def build(snap: dict, settings: dict | None, events: list[dict], expires_ms: int | None) -> HotspotData:
    """Pure: the Dashboard Overview's numbers from GET /device (+ settings and events)."""
    st = snap.get("state") or {}
    radio, net = st.get("radio") or {}, st.get("net") or {}
    power, heat = st.get("power") or {}, st.get("heat") or {}
    traffic, system, tether = st.get("traffic") or {}, st.get("system") or {}, st.get("tether") or {}
    s = settings or {}
    watchdog, alerts, plan = s.get("watchdog") or {}, s.get("alerts") or {}, s.get("plan") or {}
    info = snap.get("info") or {}

    nr = radio.get("nr") or {}
    band = None
    if radio.get("net_type") == "NR_SA" and radio.get("band"):
        band = f"n{radio['band']}"
    elif radio.get("band"):
        band = f"B{radio['band']}"
        if radio.get("net_type") == "NR_NSA" and nr.get("band"):
            band += f" + n{nr['band']}"

    score = _num(radio.get("score"))
    pct = _num(power.get("percent"))
    bat_c = _num(heat.get("battery_c"))
    warn_c, stop_c = _num(watchdog.get("temp_warn_c")) or 40, _num(watchdog.get("temp_stop_charge_c")) or 45
    low_pct = _num(alerts.get("low_battery_pct")) or 20
    quota_gb = _num(plan.get("quota_gb")) or 0

    notes = []
    if power.get("charging_enabled") is False:
        notes.append(f"charging paused ({power.get('stop_reason') or 'manual'})")
    if _num(power.get("charge_limit_pct")) is not None:
        notes.append(f"limit {int(power['charge_limit_pct'])}%")

    therm = heat.get("thermal_status")
    clients = tether.get("clients")
    tether_on = None
    if tether.get("usb_tether_on") is not None or tether.get("hotspot_on") is not None:
        tether_on = bool(tether.get("usb_tether_on") or tether.get("hotspot_on"))

    model = None
    if info:
        model = f"{info.get('manufacturer', '')} {info.get('model', '')}".strip()
        if info.get("android_version"):
            model += f" · Android {info['android_version']}"

    stamps = [iso_ms(v) for v in (snap.get("state_ts") or {}).values()]
    stamps = [v for v in stamps if v]
    online_net = net.get("online") if isinstance(net.get("online"), bool) else None
    return HotspotData(
        name=snap.get("name"),
        model=model or None,
        online=bool(snap.get("online")),
        last_seen=iso_ms(snap.get("last_seen")),
        updated=max(stamps) if stamps else None,
        internet=online_net,
        down_since=iso_ms(net.get("internet_down_since")) if online_net is False else None,
        net_type=NET_TYPE.get(radio.get("net_type"), radio.get("net_type")) if radio.get("net_type") else None,
        band=band,
        operator=radio.get("operator"),
        score=round(score) if score is not None else None,
        grade=grade(score),
        rsrp=_num(radio.get("rsrp")),
        sinr=_num(radio.get("sinr")),
        rsrq=_num(radio.get("rsrq")),
        rx_bps=_num(net.get("rx_bps")),
        tx_bps=_num(net.get("tx_bps")),
        ping_ms=_num(net.get("ping_ms")),
        loss_pct=_num(net.get("ping_loss_pct")),
        jitter_ms=_num(net.get("jitter_ms")),
        tether_on=tether_on,
        clients=len(clients) if isinstance(clients, list) else None,
        battery_pct=pct,
        current_ma=_num(power.get("current_ma")),
        charge_status=(power.get("status") or "").replace("_", " ") or None,
        plug=power.get("plug"),
        charge_note=", ".join(notes) or None,
        low_battery=pct is not None and pct <= low_pct,
        battery_c=bat_c,
        cpu_c=_num(heat.get("cpu_c")),
        modem_c=_num(heat.get("modem_c")),
        thermal=THERMAL[therm] if isinstance(therm, int) and 0 <= therm < len(THERMAL) else None,
        heat="hot" if bat_c is not None and bat_c >= stop_c else "warm" if bat_c is not None and bat_c >= warn_c else "ok",
        radio_resting=bool(heat.get("radio_resting")),
        cycle_used=_sum(traffic.get("cycle_rx"), traffic.get("cycle_tx")),
        quota=quota_gb * 1e9 if quota_gb > 0 else None,
        today_used=_sum(traffic.get("today_rx"), traffic.get("today_tx")),
        cycle_start=traffic.get("cycle_start"),
        uptime_s=_num(system.get("uptime_s")),
        agent_uptime_s=_num(system.get("agent_uptime_s")),
        boot_count=system.get("boot_count") if isinstance(system.get("boot_count"), int) else None,
        boot_reason=system.get("boot_reason"),
        events=[
            HotspotEvent(ts=iso_ms(e.get("ts")) or 0, kind=str(e.get("kind", "")),
                         severity=e.get("severity") if e.get("severity") in ("info", "warning", "critical") else "info",
                         message=str(e.get("message", ""))[:200])
            for e in events[:EVENTS]
        ],
        session_expires=expires_ms,
    )


class HotspotCollector(BaseProvider):
    topics = ("hotspot",)

    def __init__(self, store: Store, cfg: HotspotCfg, client: httpx.AsyncClient | None = None):
        super().__init__()
        self.store, self.cfg = store, cfg
        self.client = client
        self.device_id = cfg.device_id
        self.settings: dict | None = None
        self.settings_at = 0.0

    @property
    def base(self) -> str:
        return (self.cfg.server_url or "").rstrip("/")

    async def setup(self) -> None:
        if not (self.cfg.server_url and self.cfg.token):
            self.publish("hotspot", {"status": "unconfigured", "message": UNCONFIGURED_MSG})
            return
        raw = self.store.get(CACHE_KEY)
        if raw:
            try:
                self.publish("hotspot", HotspotData.model_validate(raw))
            except Exception:  # noqa: BLE001
                pass

    def loops(self) -> list[str]:
        return ["run"] if self.cfg.server_url and self.cfg.token else []

    async def _get(self, path: str, **params: Any) -> Any:
        assert self.client
        r = await self.client.get(f"{self.base}/api{path}", params=params,
                                  headers={"Authorization": f"Bearer {self.cfg.token}"})
        if r.status_code == 401:
            raise AuthError(EXPIRED_MSG)
        if r.status_code == 403:
            code = (r.json() if r.headers.get("content-type", "").startswith("application/json") else {}).get("error")
            raise AuthError(ENROLL_MSG if code == "totp_enrollment_required" else EXPIRED_MSG)
        r.raise_for_status()
        return r.json()

    async def poll_once(self) -> HotspotData:
        if not self.device_id:
            devices = await self._get("/devices")
            if not devices:
                raise LookupError("No phone is paired with the Hotspot Monitor Server yet.")
            self.device_id = devices[0]["device_id"]
        loop = asyncio.get_running_loop()
        snap_t = self._get("/device", device_id=self.device_id)
        ev_t = self._get("/events", device_id=self.device_id, limit=EVENTS)
        if self.settings is None or loop.time() - self.settings_at > SETTINGS_EVERY_S:
            s = await self._get("/settings", device_id=self.device_id)
            self.settings = s.get("settings", s) if isinstance(s, dict) else None
            self.settings_at = loop.time()
        snap, events = await asyncio.gather(snap_t, ev_t)
        return build(snap, self.settings, events if isinstance(events, list) else [], iso_ms(self.cfg.expires))

    async def run(self) -> None:
        own = self.client is None
        if own:
            self.client = httpx.AsyncClient(timeout=20, headers={"User-Agent": "DeskPanel"})
        last_err = None
        try:
            while True:
                try:
                    data = await self.poll_once()
                    self.publish("hotspot", data)
                    self.store.set(CACHE_KEY, data.model_dump(mode="json"))
                    if last_err:
                        log.info("hotspot: reading the Server again")
                    last_err = None
                except AuthError as e:
                    if last_err != "auth":
                        log.warning("hotspot: the Server rejected DeskPanel's sign-in")
                    last_err = "auth"
                    self.publish("hotspot", {"status": "error", "message": e.msg})
                except LookupError as e:
                    last_err = "none"
                    self.publish("hotspot", {"status": "error", "message": str(e)})
                except (httpx.HTTPError, ValueError) as e:
                    # Offline / Render waking up: keep the cached page; the app shows it stale.
                    if last_err != "net":
                        log.info("hotspot: Server unreachable (%s)", type(e).__name__)
                    last_err = "net"
                await asyncio.sleep(POLL_S)
        finally:
            if own and self.client:
                await self.client.aclose()
