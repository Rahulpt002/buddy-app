"""`network` topic: latency (TCP connect timing, unprivileged), online/offline tracking,
daily/monthly data usage (persisted), and an on-demand speed test."""
from __future__ import annotations

import asyncio
import datetime as dt
import logging
import os
import statistics
import time
from collections import deque

from ..hub import ActionError, Progress, now_ms
from ..protocol import (
    Latency, LatencyHistory, NetworkData, SpeedProgress, SpeedResult, Speedtest, Usage,
)
from ..storage import Store
from .base import BaseProvider
from .system import net_totals

log = logging.getLogger(__name__)

OFFLINE_AFTER = 3  # consecutive lost pings


async def tcp_ping(host: str, port: int, timeout: float = 1.0) -> float | None:
    """Milliseconds to complete a TCP handshake, or None if it failed / timed out."""
    t0 = time.perf_counter()
    try:
        _, w = await asyncio.wait_for(asyncio.open_connection(host, port), timeout)
    except (OSError, asyncio.TimeoutError):
        return None
    ms = (time.perf_counter() - t0) * 1000
    w.close()
    try:
        await w.wait_closed()
    except OSError:
        pass
    return ms


def jitter(samples: list[float | None]) -> float | None:
    """Mean absolute difference between consecutive successful samples."""
    ok = [s for s in samples if s is not None]
    if len(ok) < 2:
        return None
    return sum(abs(a - b) for a, b in zip(ok, ok[1:])) / (len(ok) - 1)


class NetworkCollector(BaseProvider):
    topics = ("network",)

    def __init__(self, store: Store, host: str = "1.1.1.1", port: int = 443) -> None:
        super().__init__()
        self.store, self.host, self.port = store, host, port
        self.hist: deque[float | None] = deque(maxlen=120)
        self.speed = Speedtest()
        self.actions = {"speedtest.run": self.speedtest}
        self._fails = 0
        self.online = True

    async def setup(self) -> None:
        now = now_ms()
        last_seen = self.store.get("net.last_seen", 0)
        # Keep uptime across agent restarts if the agent was running recently.
        if now - last_seen < 5 * 60_000 and self.store.get("net.online_since"):
            self.online_since = self.store.get("net.online_since")
        else:
            self.online_since = now
            self.store.set("net.online_since", now)
        self.last_drop = self.store.get("net.last_drop")
        last = self.store.last_speedtest()
        if last:
            self.speed = Speedtest(last=SpeedResult(**last))
        self._counters = net_totals()

    def loops(self) -> list[str]:
        return ["ping_loop", "usage_loop"]

    # ---------------------------------------------------------------- latency

    async def ping_loop(self) -> None:
        n = 0
        while True:
            t0 = time.monotonic()
            ms = await tcp_ping(self.host, self.port)
            self.hist.append(round(ms, 1) if ms is not None else None)
            self._track(ms)
            n += 1
            if n % 30 == 0:
                self.store.set("net.last_seen", now_ms())
            self.publish("network", self.snapshot())
            await asyncio.sleep(max(0.0, 1 - (time.monotonic() - t0)))

    def _track(self, ms: float | None) -> None:
        now = now_ms()
        if ms is None:
            self._fails += 1
            if self.online and self._fails >= OFFLINE_AFTER:
                self.online = False
                self.last_drop = now
                self.store.set("net.last_drop", now)
                log.info("network: offline")
        else:
            self._fails = 0
            if not self.online:
                self.online = True
                self.online_since = now
                self.store.set("net.online_since", now)
                log.info("network: back online")

    def snapshot(self) -> NetworkData:
        recent = list(self.hist)[-60:]
        lost = sum(1 for s in recent if s is None)
        last20 = list(self.hist)[-20:]
        j = jitter(last20)
        return NetworkData(
            latency=Latency(
                target=f"{self.host}:{self.port}",
                ms=self.hist[-1] if self.hist else None,
                jitter_ms=round(j, 1) if j is not None else None,
                loss_pct=round(100 * lost / len(recent), 1) if recent else 0.0,
                history=LatencyHistory(ms=list(self.hist)),
            ),
            online=self.online,
            online_since=self.online_since if self.online else None,
            last_drop=self.last_drop,
            usage=Usage(today=self.store.usage_day(), month=self.store.usage_month()),
            speedtest=self.speed,
        )

    # ---------------------------------------------------------------- usage

    async def usage_loop(self) -> None:
        day = dt.date.today()
        while True:
            await asyncio.sleep(10)
            rx, tx = net_totals()
            prx, ptx = self._counters
            # Counters reset on reboot / interface reset: count from zero then.
            drx = rx - prx if rx >= prx else rx
            dtx = tx - ptx if tx >= ptx else tx
            self._counters = (rx, tx)
            today = dt.date.today()
            if today != day:
                day = today
            self.store.add_usage(drx, dtx, day)

    # ---------------------------------------------------------------- speed test

    async def speedtest(self, params: dict, progress: Progress) -> dict:
        if self.speed.state == "running":
            raise ActionError("busy", "A speed test is already running")
        last = self.speed.last
        self.speed = Speedtest(state="running", last=last, progress=SpeedProgress(phase="ping", pct=0))
        self.publish("network", self.snapshot())

        async def report(phase: str, pct: float, down: float | None = None, up: float | None = None) -> None:
            self.speed.progress = SpeedProgress(phase=phase, pct=round(pct, 1), down_bps=down, up_bps=up)
            await progress(self.speed.progress.model_dump(mode="json"))
            self.publish("network", self.snapshot())

        try:
            result = await run_speedtest(report)
        except Exception as e:  # noqa: BLE001
            self.speed = Speedtest(last=last)
            self.publish("network", self.snapshot())
            raise ActionError("failed", f"Speed test failed: {e}") from e
        self.store.add_speedtest(result.at, result.down_bps, result.up_bps, result.ping_ms)
        self.speed = Speedtest(last=result)
        self.publish("network", self.snapshot())
        return result.model_dump(mode="json")


# -------------------------------------------------------------------- speed test engine

CF = "speed.cloudflare.com"


async def run_speedtest(report, down_s: float = 7.0, up_s: float = 5.0) -> SpeedResult:
    """Ping, download and upload against Cloudflare's speed test endpoints (the same ones
    speed.cloudflare.com uses). Phases map to progress 0-10 / 10-60 / 60-100 %."""
    import httpx

    pings = []
    for i in range(5):
        ms = await tcp_ping(CF, 443, timeout=2)
        if ms is not None:
            pings.append(ms)
        await report("ping", (i + 1) * 2)
    if not pings:
        raise RuntimeError("speed.cloudflare.com is unreachable")
    ping = statistics.median(pings)

    async with httpx.AsyncClient(timeout=httpx.Timeout(15.0), http2=False) as client:
        # Download: parallel streams of large objects until the time budget is spent.
        got = 0
        t0 = time.perf_counter()
        stop = t0 + down_s

        async def dl() -> None:
            nonlocal got
            while time.perf_counter() < stop:
                async with client.stream("GET", f"https://{CF}/__down", params={"bytes": 25_000_000}) as r:
                    async for chunk in r.aiter_bytes(65536):
                        got += len(chunk)
                        if time.perf_counter() >= stop:
                            break

        async def dl_progress() -> None:
            while time.perf_counter() < stop:
                await asyncio.sleep(0.3)
                el = time.perf_counter() - t0
                await report("download", 10 + 50 * min(1, el / down_s), down=got / max(el, 1e-3))

        await asyncio.gather(dl(), dl(), dl(), dl_progress())
        down = got / (time.perf_counter() - t0)

        # Upload: the server can answer before it has read a whole body, so neither "bytes
        # handed to the client" nor "bytes in finished POSTs" is trustworthy. Measure what
        # actually left the machine: the interfaces' transmit counters.
        t1 = time.perf_counter()
        ustop = t1 + up_s
        block = os.urandom(4 << 20)
        tx0 = net_totals()[1]

        def sent_rate() -> float:
            return max(0, net_totals()[1] - tx0) / max(time.perf_counter() - t1, 1e-3)

        async def ul() -> None:
            while time.perf_counter() < ustop:
                try:
                    await client.post(f"https://{CF}/__up", content=block)
                except httpx.HTTPError:
                    await asyncio.sleep(0.2)

        async def ul_progress() -> None:
            while time.perf_counter() < ustop:
                await asyncio.sleep(0.3)
                el = time.perf_counter() - t1
                await report("upload", 60 + 40 * min(1, el / up_s), down=down, up=sent_rate())

        await asyncio.gather(ul(), ul(), ul_progress())
        up = sent_rate()

    await report("upload", 100, down=down, up=up)
    return SpeedResult(down_bps=down, up_bps=up, ping_ms=round(ping, 1), at=now_ms())
