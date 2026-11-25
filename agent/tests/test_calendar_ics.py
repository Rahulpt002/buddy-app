import datetime as dt

import httpx

from deskpanel_agent.collectors.calendar_ics import IcsCalendarCollector, parse_ics

ICS = """BEGIN:VCALENDAR
VERSION:2.0
X-WR-CALNAME:Work
BEGIN:VEVENT
UID:standup@x
DTSTART;TZID=Asia/Kolkata:20261116T090000
DTEND;TZID=Asia/Kolkata:20261116T091500
RRULE:FREQ=WEEKLY;BYDAY=MO,WE
SUMMARY:Team standup
LOCATION:Zoom
END:VEVENT
BEGIN:VEVENT
UID:holiday@x
DTSTART;VALUE=DATE:20261125
DTEND;VALUE=DATE:20261126
SUMMARY:Holiday
END:VEVENT
BEGIN:VEVENT
UID:cancelled@x
DTSTART:20261124T100000Z
DTEND:20261124T110000Z
SUMMARY:Gone
STATUS:CANCELLED
END:VEVENT
BEGIN:VEVENT
UID:old@x
DTSTART:20261101T100000Z
DTEND:20261101T110000Z
SUMMARY:Old
END:VEVENT
END:VCALENDAR
"""


def _window():
    from zoneinfo import ZoneInfo

    s = dt.datetime(2026, 11, 23, tzinfo=ZoneInfo("Asia/Kolkata"))
    return s, s + dt.timedelta(days=8)


def test_parse_expands_recurring_skips_cancelled_and_out_of_range():
    s, e = _window()
    evs = parse_ics(ICS, "#5AA9FF", s, e)
    titles = sorted((x.title, dt.datetime.fromtimestamp(x.start / 1000, dt.timezone.utc).isoformat()) for x in evs)
    standups = [t for t in titles if t[0] == "Team standup"]
    assert len(standups) == 3  # Mon 23, Wed 25, Mon 30 (window ends Dec 1; 09:00 IST = 03:30 UTC)
    assert standups[0][1] == "2026-11-23T03:30:00+00:00"
    assert not any(t[0] in ("Gone", "Old") for t in titles)
    hol = next(x for x in evs if x.title == "Holiday")
    assert hol.all_day and hol.end - hol.start == 86_400_000
    st = next(x for x in evs if x.title == "Team standup")
    assert st.calendar == "Work" and st.location == "Zoom" and st.end - st.start == 15 * 60_000


async def test_collector_publishes_and_survives_bad_feed():
    published = []

    def handler(req: httpx.Request) -> httpx.Response:
        if "good" in str(req.url):
            return httpx.Response(200, text=ICS)
        return httpx.Response(404)

    c = IcsCalendarCollector(["https://cal/good.ics", "webcal://cal/bad.ics"],
                             client=httpx.AsyncClient(transport=httpx.MockTransport(handler)))
    c.publish = lambda topic, data: published.append(data)  # type: ignore[method-assign]
    await c.refresh()
    assert published and all(e.title != "Gone" for e in published[-1].events)
    c.urls = ["https://cal/bad.ics"]
    n = len(published)
    await c.refresh()
    assert len(published) == n  # all feeds failed: keep the last published events


def test_no_feeds_means_no_loop():
    assert IcsCalendarCollector([]).loops() == []
