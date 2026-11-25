import datetime as dt
import json

import httpx
import pytest

from deskpanel_agent.collectors.github import (
    CACHE_KEY, GRAPHQL_URL, REJECTED_MSG, UNCONFIGURED_MSG, GithubCollector, best_day,
    current_streak, level_of, longest_streak, parse_response, query_range, top_repos,
    week_split, week_start,
)
from deskpanel_agent.config import GithubCfg
from deskpanel_agent.hub import Hub
from deskpanel_agent.protocol import ContribDay, GithubData
from deskpanel_agent.storage import Store

TODAY = dt.date(2026, 11, 25)  # a Wednesday
SUN = dt.date(2026, 11, 22)
TOKEN = "ghp_SECRETSECRETSECRET"
LEVEL_NAMES = ["NONE", "FIRST_QUARTILE", "SECOND_QUARTILE", "THIRD_QUARTILE", "FOURTH_QUARTILE"]


def _lvl(c: int) -> str:
    return LEVEL_NAMES[0 if c == 0 else 1 if c < 4 else 2 if c < 9 else 3 if c < 15 else 4]


def fake_body(counts: dict[dt.date, int], start: dt.date, end: dt.date, **over) -> dict:
    """A GraphQL response shaped like GitHub's: Sunday-start weeks, first may be partial."""
    weeks, col, d = [], [], start
    while d <= end:
        if d.weekday() == 6 and col:  # Sunday starts a new column
            weeks.append({"contributionDays": col})
            col = []
        c = counts.get(d, 0)
        col.append({"date": d.isoformat(), "contributionCount": c, "contributionLevel": _lvl(c)})
        d += dt.timedelta(days=1)
    if col:
        weeks.append({"contributionDays": col})
    cc = {
        "totalCommitContributions": 40,
        "restrictedContributionsCount": 12,
        "totalIssueContributions": 3,
        "totalPullRequestContributions": 5,
        "totalPullRequestReviewContributions": 2,
        "contributionCalendar": {"totalContributions": sum(counts.values()), "weeks": weeks},
        "commitContributionsByRepository": [
            {"repository": {"name": "small", "nameWithOwner": "me/small", "isPrivate": False},
             "contributions": {"totalCount": 3}},
            {"repository": {"name": "big", "nameWithOwner": "me/big", "isPrivate": True},
             "contributions": {"totalCount": 30}},
            {"repository": {"name": "mid", "nameWithOwner": "org/mid", "isPrivate": False},
             "contributions": {"totalCount": 12}},
            {"repository": {"name": "alpha", "nameWithOwner": "me/alpha", "isPrivate": False},
             "contributions": {"totalCount": 12}},
            {"repository": {"name": "tiny", "nameWithOwner": "me/tiny", "isPrivate": False},
             "contributions": {"totalCount": 1}},
        ],
    }
    cc.update(over)
    return {"data": {"viewer": {"login": "octo", "contributionsCollection": cc}}}


# Three weeks + this week. Last week: Mon..Sat busy. A 4-day streak ending yesterday
# (Sat 21 .. Tue 24); today (Wed 25) has nothing yet. A 6-day streak earlier (Nov 2..7).
COUNTS = {
    dt.date(2026, 11, 2): 1, dt.date(2026, 11, 3): 2, dt.date(2026, 11, 4): 3,
    dt.date(2026, 11, 5): 4, dt.date(2026, 11, 6): 5, dt.date(2026, 11, 7): 6,
    dt.date(2026, 11, 10): 20,
    dt.date(2026, 11, 16): 2, dt.date(2026, 11, 17): 3, dt.date(2026, 11, 21): 4,
    dt.date(2026, 11, 22): 7, dt.date(2026, 11, 23): 9, dt.date(2026, 11, 24): 1,
}
START = dt.date(2026, 10, 29)  # a Thursday: partial first column


def days_of(body: dict) -> list[ContribDay]:
    weeks = body["data"]["viewer"]["contributionsCollection"]["contributionCalendar"]["weeks"]
    return [ContribDay(date=d["date"], count=d["contributionCount"], level=0)
            for w in weeks for d in w["contributionDays"]]


# ------------------------------------------------------------------ pure functions


def test_week_start_and_query_range():
    assert week_start(TODAY) == SUN and week_start(SUN) == SUN
    assert week_start(dt.date(2026, 11, 28)) == SUN  # Saturday
    tz = dt.timezone(dt.timedelta(hours=5, minutes=30))
    for day in range(22, 29):  # every weekday
        now = dt.datetime(2026, 11, day, 15, 0, tzinfo=tz)
        frm, to = query_range(now)
        assert to == now and frm.tzinfo == tz and frm.time() == dt.time(0)
        assert (to - frm) <= dt.timedelta(days=365)  # GitHub's one-year limit
        # 53 Sunday-start columns: from falls in the week 52 weeks before this one.
        assert week_start(frm.date()) == week_start(now.date()) - dt.timedelta(weeks=52)


def test_level_mapping():
    assert [level_of(n) for n in LEVEL_NAMES] == [0, 1, 2, 3, 4]
    assert level_of("SOMETHING_NEW", 0) == 0 and level_of(None, 5) == 1


def test_streak_today_zero_keeps_streak_alive():
    days = days_of(fake_body(COUNTS, START, TODAY))
    assert current_streak(days, TODAY) == 4  # Sat 21 .. Tue 24
    with_today = days + [ContribDay(date=TODAY.isoformat(), count=2, level=1)]
    with_today = [d for d in with_today if not (d.date == TODAY.isoformat() and d.count == 0)]
    assert current_streak(with_today, TODAY) == 5
    # A gap yesterday as well breaks it.
    assert current_streak(days, dt.date(2026, 11, 26)) == 0
    assert current_streak([], TODAY) == 0


def test_longest_streak_and_best_day():
    days = days_of(fake_body(COUNTS, START, TODAY))
    assert longest_streak(days) == 6
    assert best_day(days).model_dump() == {"date": "2026-11-10", "count": 20}
    assert best_day([ContribDay(date="2026-01-01", count=0, level=0)]) is None
    # Ties go to the most recent day.
    tie = [ContribDay(date="2026-01-01", count=5, level=2), ContribDay(date="2026-02-01", count=5, level=2)]
    assert best_day(tie).date == "2026-02-01"


def test_week_split_and_delta():
    days = days_of(fake_body(COUNTS, START, TODAY))
    w = week_split(days, TODAY)
    assert w.this == [7, 9, 1, 0, None, None, None]
    assert w.last == [0, 2, 3, 0, 0, 0, 4]
    assert w.this_total == 17 and w.delta == 17 - 9
    # Saturday: the whole week is in the past.
    sat = week_split(days, dt.date(2026, 11, 28))
    assert None not in sat.this and len(sat.this) == 7


def test_top_repos_ordering():
    items = fake_body(COUNTS, START, TODAY)["data"]["viewer"]["contributionsCollection"][
        "commitContributionsByRepository"]
    assert [(r.name, r.count) for r in top_repos(items)] == [
        ("big", 30), ("alpha", 12), ("mid", 12), ("small", 3)]
    assert top_repos(None) == [] and top_repos([{"repository": None}]) == []


def test_parse_response_validates():
    body = fake_body(COUNTS, START, TODAY)
    data = parse_response(body, TODAY, fetched_at=123)
    again = GithubData.model_validate(json.loads(json.dumps(data.model_dump(mode="json"))))
    assert again.status == "ok" and again.user == "octo" and again.fetched_at == 123
    y = again.year
    assert (y.total, y.commits, y.private, y.issues, y.prs, y.reviews) == (sum(COUNTS.values()), 40, 12, 3, 5, 2)
    assert len(y.weeks) == 5 and len(y.weeks[0]) == 3 and len(y.weeks[-1]) == 4
    assert y.weeks[2][3].model_dump() == {"date": "2026-11-11", "count": 0, "level": 0}
    assert y.weeks[2][2].level == 4  # 20 contributions
    assert again.streak.current == 4 and again.streak.longest == 6
    assert again.streak.best_day.count == 20
    assert again.week.this_total == 17 and again.week.delta == 8
    assert [r.name for r in again.top_repos] == ["big", "alpha", "mid", "small"]


def test_parse_response_caps_weeks_at_53():
    start = week_start(TODAY) - dt.timedelta(weeks=60)
    data = parse_response(fake_body({}, start, TODAY), TODAY)
    assert len(data.year.weeks) == 53 and data.year.weeks[-1][-1].date == TODAY.isoformat()


def test_parse_response_graphql_errors():
    from deskpanel_agent.collectors.github import GithubError
    with pytest.raises(GithubError, match="required scopes"):
        parse_response({"errors": [{"message": "Your token has not been granted the required scopes"}]}, TODAY)
    with pytest.raises(GithubError, match="Unexpected"):
        parse_response({"data": {"viewer": None}}, TODAY)


# ------------------------------------------------------------------ collector


def _now() -> dt.datetime:
    return dt.datetime(2026, 11, 25, 14, 0).astimezone()


def _published(hub: Hub) -> dict:
    return json.loads(hub.latest["github"])["data"]


def _collector(tmp_path, handler, token: str | None = TOKEN):
    seen: list[httpx.Request] = []

    def wrapped(req: httpx.Request) -> httpx.Response:
        seen.append(req)
        return handler(req)

    client = httpx.AsyncClient(transport=httpx.MockTransport(wrapped))
    store = Store(tmp_path / "t.db")
    c = GithubCollector(store, GithubCfg(token=token), client=client, clock=_now)
    hub = Hub()
    c.hub = hub
    return c, hub, store, seen


async def test_unconfigured_publishes_and_does_nothing(tmp_path):
    def handler(req):  # pragma: no cover - must not be called
        raise AssertionError("no request without a token")

    c, hub, _, seen = _collector(tmp_path, handler, token="  ")
    await c.start(hub)
    assert _published(hub) == {"status": "unconfigured", "message": UNCONFIGURED_MSG}
    assert c.loops() == [] and c._tasks == [] and seen == []


async def test_fetch_success_caches_and_sends_query(tmp_path, caplog):
    body = fake_body(COUNTS, START, TODAY)
    c, hub, store, seen = _collector(tmp_path, lambda req: httpx.Response(200, json=body))
    caplog.set_level("DEBUG")
    out = await c.refresh()
    assert isinstance(out, GithubData)
    req = seen[0]
    assert str(req.url) == GRAPHQL_URL and req.method == "POST"
    assert req.headers["authorization"] == f"bearer {TOKEN}"
    sent = json.loads(req.content)
    assert "contributionsCollection(from: $from, to: $to)" in sent["query"]
    assert set(sent["variables"]) == {"from", "to"}
    pub = _published(hub)
    assert pub["status"] == "ok" and pub["user"] == "octo"
    GithubData.model_validate(pub)
    assert store.get(CACHE_KEY)["user"] == "octo"
    assert TOKEN not in caplog.text


async def test_cache_published_on_startup(tmp_path):
    body = fake_body(COUNTS, START, TODAY)
    c, hub, store, _ = _collector(tmp_path, lambda req: httpx.Response(200, json=body))
    store.set(CACHE_KEY, parse_response(body, TODAY, fetched_at=42).model_dump(mode="json"))
    await c.setup()
    pub = _published(hub)
    assert pub["fetched_at"] == 42 and pub["status"] == "ok"


async def test_401_publishes_error(tmp_path, caplog):
    c, hub, store, _ = _collector(tmp_path, lambda req: httpx.Response(401, json={"message": "Bad credentials"}))
    await c.refresh()
    assert _published(hub) == {"status": "error", "message": REJECTED_MSG}
    assert "rejected the token" in REJECTED_MSG
    assert store.get(CACHE_KEY) is None
    assert TOKEN not in caplog.text


async def test_graphql_errors_publish_error(tmp_path):
    err = {"errors": [{"type": "INSUFFICIENT_SCOPES", "message": "Your token has not been granted the required scopes"}]}
    c, hub, _, _ = _collector(tmp_path, lambda req: httpx.Response(200, json=err))
    await c.refresh()
    pub = _published(hub)
    assert pub["status"] == "error" and "required scopes" in pub["message"]


async def test_403_publishes_error(tmp_path):
    c, hub, _, _ = _collector(tmp_path, lambda req: httpx.Response(403, json={"message": "Resource not accessible"}))
    await c.refresh()
    pub = _published(hub)
    assert pub["status"] == "error" and "403" in pub["message"] and "Resource not accessible" in pub["message"]


async def test_network_failure_keeps_cache(tmp_path, caplog):
    def boom(req):
        raise httpx.ConnectError("connection refused", request=req)

    body = fake_body(COUNTS, START, TODAY)
    c, hub, store, _ = _collector(tmp_path, boom)
    store.set(CACHE_KEY, parse_response(body, TODAY, fetched_at=42).model_dump(mode="json"))
    caplog.set_level("WARNING")
    await c.refresh()
    pub = _published(hub)
    assert pub["status"] == "ok" and pub["fetched_at"] == 42
    assert "keeping last data" in caplog.text and TOKEN not in caplog.text


async def test_network_failure_without_cache_and_5xx(tmp_path):
    def boom(req):
        raise httpx.ReadTimeout("timed out", request=req)

    c, hub, _, _ = _collector(tmp_path, boom)
    await c.refresh()
    pub = _published(hub)
    assert pub["status"] == "error" and "reach GitHub" in pub["message"]

    body = fake_body(COUNTS, START, TODAY)
    c, hub, store, _ = _collector(tmp_path / "b", lambda req: httpx.Response(502))
    store.set(CACHE_KEY, parse_response(body, TODAY, fetched_at=7).model_dump(mode="json"))
    await c.refresh()
    assert _published(hub)["fetched_at"] == 7


async def test_run_loop_refreshes(tmp_path):
    import asyncio

    body = fake_body(COUNTS, START, TODAY)
    c, hub, _, seen = _collector(tmp_path, lambda req: httpx.Response(200, json=body))
    c.interval = 0.01
    await c.start(hub)
    for _ in range(100):
        if len(seen) >= 2:
            break
        await asyncio.sleep(0.01)
    await c.stop()
    assert len(seen) >= 2 and _published(hub)["status"] == "ok"
