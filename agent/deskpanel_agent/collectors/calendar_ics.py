"""`calendar` topic from optional ICS feeds (e.g. Google Calendar's "secret address in iCal
format"). The phone also reads its own device calendars; the app merges both.
Repeating events are expanded with `recurring_ical_events`. Fetched every 15 minutes.
"""
from __future__ import annotations

import asyncio
import datetime as dt
import hashlib
import logging

from ..protocol import CalendarData, CalEvent
from .base import BaseProvider

log = logging.getLogger(__name__)

PALETTE = ["#5AA9FF", "#C18CFF", "#3DD68C", "#F2A93B", "#F472B6", "#4FD6C3"]


def _ms(v) -> tuple[int, bool]:
    """date / datetime (aware or naive=local) -> (epoch ms, all_day)."""
    if isinstance(v, dt.datetime):
        if v.tzinfo is None:
            v = v.astimezone()  # floating time = laptop local
        return int(v.timestamp() * 1000), False
    d = dt.datetime(v.year, v.month, v.day).astimezone()
    return int(d.timestamp() * 1000), True


def parse_ics(text: str | bytes, color: str, start: dt.datetime, end: dt.datetime,
              fallback_name: str = "Calendar") -> list[CalEvent]:
    import icalendar
    import recurring_ical_events

    cal = icalendar.Calendar.from_ical(text)
    name = str(cal.get("X-WR-CALNAME") or fallback_name)
    out: list[CalEvent] = []
    for ev in recurring_ical_events.of(cal).between(start, end):
        if str(ev.get("STATUS", "")).upper() == "CANCELLED":
            continue
        s = ev.get("DTSTART")
        if s is None:
            continue
        s_ms, all_day = _ms(s.dt)
        e = ev.get("DTEND")
        if e is not None:
            e_ms, _ = _ms(e.dt)
        elif ev.get("DURATION") is not None:
            e_ms = s_ms + int(ev["DURATION"].dt.total_seconds() * 1000)
        else:
            e_ms = s_ms + (86_400_000 if all_day else 0)
        uid = str(ev.get("UID", "")) or str(ev.get("SUMMARY", ""))
        loc = str(ev.get("LOCATION") or "").strip() or None
        out.append(CalEvent(
            id="ics-" + hashlib.sha1(f"{uid}|{s_ms}".encode()).hexdigest()[:16],
            title=str(ev.get("SUMMARY") or "(No title)").strip(),
            start=s_ms, end=e_ms, all_day=all_day, location=loc, calendar=name, color=color,
        ))
    return out


class IcsCalendarCollector(BaseProvider):
    topics = ("calendar",)

    def __init__(self, urls: list[str], client=None, interval: float = 900):
        super().__init__()
        self.urls = [u for u in urls if u.strip()]
        self.client = client
        self.interval = interval

    async def setup(self) -> None:
        # No feeds is normal: the phone shows its own calendars. Publish an empty list.
        self.publish("calendar", CalendarData(events=[]))

    def loops(self) -> list[str]:
        return ["run"] if self.urls else []

    async def run(self) -> None:
        while True:
            await self.refresh()
            await asyncio.sleep(self.interval)

    async def refresh(self) -> None:
        import httpx

        now = dt.datetime.now().astimezone()
        start = now.replace(hour=0, minute=0, second=0, microsecond=0)
        end = start + dt.timedelta(days=8)
        events: list[CalEvent] = []
        failed = 0
        client = self.client or httpx.AsyncClient(timeout=20, follow_redirects=True)
        try:
            for i, url in enumerate(self.urls):
                u = url.replace("webcal://", "https://", 1)
                try:
                    r = await client.get(u)
                    r.raise_for_status()
                    events += await asyncio.to_thread(
                        parse_ics, r.content, PALETTE[i % len(PALETTE)], start, end, f"Calendar {i + 1}")
                except Exception as e:  # noqa: BLE001
                    failed += 1
                    # Feed URLs are secrets (anyone with them can read the calendar): don't log them.
                    log.warning("calendar: feed %d failed: %s", i + 1, type(e).__name__)
        finally:
            if self.client is None:
                await client.aclose()
        if failed == len(self.urls):
            return  # keep whatever was published last
        events.sort(key=lambda e: e.start)
        self.publish("calendar", CalendarData(events=events))
