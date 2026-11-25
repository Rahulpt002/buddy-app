import datetime as dt

import httpx

from deskpanel_agent.collectors.gitlab import (
    EVENTS_KEY, REJECTED_MSG, UNCONFIGURED_MSG, GitlabCollector, build, classify, level_of)
from deskpanel_agent.config import GitlabCfg
from deskpanel_agent.protocol import GithubData
from deskpanel_agent.storage import Store

TZ = dt.timezone(dt.timedelta(hours=5, minutes=30))
NOW = dt.datetime(2026, 11, 23, 18, 0, tzinfo=TZ)  # Monday


def ev(i, day, action="pushed to", target=None, commits=1, pid=10):
    e = {"id": i, "project_id": pid, "action_name": action, "target_type": target,
         "created_at": f"{day}T06:00:00.000Z"}
    if action.startswith("pushed"):
        e["push_data"] = {"commit_count": commits}
    return e


def test_classify_and_levels():
    assert classify(ev(1, "2026-11-23", commits=3)) == ("push", 3)
    assert classify(ev(2, "2026-11-23", "opened", "Issue")) == ("issue", 0)
    assert classify(ev(3, "2026-11-23", "opened", "MergeRequest")) == ("mr", 0)
    assert classify(ev(4, "2026-11-23", "joined")) is None
    assert [level_of(n) for n in (0, 1, 9, 10, 25, 30)] == [0, 1, 1, 2, 3, 4]


def test_build_shape_streak_week_top():
    events = {
        "1": ["2026-11-23", 3, "push", 10], "2": ["2026-11-22", 1, "push", 10],
        "3": ["2026-11-21", 0, "issue", 11], "4": ["2026-11-16", 0, "mr", 10],
        "5": ["2026-11-12", 2, "push", 12], "6": ["2025-01-01", 9, "push", 10],  # outside the year
    }
    projects = {"10": ["billing-api", "private"], "11": ["docs", "public"]}
    d = build(events, projects, NOW.date(), "me")
    GithubData.model_validate(d.model_dump())
    assert d.year.total == 5 and d.year.commits == 6 and d.year.issues == 1 and d.year.prs == 1
    assert d.year.private == 3  # events in project 10
    assert len(d.year.weeks) == 53 and d.year.weeks[-1][-1].date == "2026-11-23"
    assert d.streak.current == 3  # Sat, Sun, Mon
    assert d.week.this[1] == 1 and d.week.this[2] is None and d.week.last[1] == 1
    assert d.top_repos[0].name == "billing-api" and d.top_repos[0].count == 3
    assert any(r.name == "project 12" for r in d.top_repos)


def _client(handler):
    return httpx.AsyncClient(transport=httpx.MockTransport(handler))


async def test_fetch_paginates_caches_and_is_incremental(tmp_path):
    calls = []

    def handler(req: httpx.Request) -> httpx.Response:
        assert req.headers["PRIVATE-TOKEN"] == "glpat-x"
        calls.append(str(req.url))
        p = req.url.path
        if p == "/api/v4/user":
            return httpx.Response(200, json={"id": 7, "username": "me"})
        if p == "/api/v4/users/7/events":
            page = req.url.params.get("page")
            if page == "1":
                return httpx.Response(200, json=[ev(1, "2026-11-22", commits=2)], headers={"x-next-page": "2"})
            return httpx.Response(200, json=[ev(2, "2026-11-23", "opened", "Issue", pid=11)], headers={"x-next-page": ""})
        if p == "/api/v4/projects/10":
            return httpx.Response(200, json={"name": "billing-api", "visibility": "private"})
        return httpx.Response(404)

    store = Store(tmp_path / "db")
    c = GitlabCollector(store, GitlabCfg(token="glpat-x"), client=_client(handler), clock=lambda: NOW)
    out = []
    c.publish = lambda t, d: out.append(d)  # type: ignore[method-assign]
    await c.refresh()
    d = out[-1]
    assert d.year.total == 2 and d.year.commits == 2 and d.user == "me"
    assert [r.name for r in d.top_repos] == ["billing-api", "project 11"]
    assert len(store.get(EVENTS_KEY)) == 2
    # Second refresh only asks for events after (newest - 2 days) and doesn't re-fetch projects.
    calls.clear()
    await c.refresh()
    ev_calls = [u for u in calls if "/events" in u]
    assert ev_calls and "after=2026-11-21" in ev_calls[0]
    assert not any("/projects/" in u for u in calls)


async def test_unconfigured_rejected_and_offline(tmp_path):
    store = Store(tmp_path / "db")
    out = []
    c = GitlabCollector(store, GitlabCfg(token=" "))
    c.publish = lambda t, d: out.append(d)  # type: ignore[method-assign]
    c.hub = object()  # type: ignore[assignment]
    await c.setup()
    assert out[-1]["message"] == UNCONFIGURED_MSG and c.loops() == []

    c = GitlabCollector(store, GitlabCfg(token="bad"), client=_client(lambda r: httpx.Response(401)), clock=lambda: NOW)
    c.publish = lambda t, d: out.append(d)  # type: ignore[method-assign]
    await c.refresh()
    assert out[-1] == {"status": "error", "message": REJECTED_MSG}

    def boom(req):
        raise httpx.ConnectError("offline")

    c = GitlabCollector(store, GitlabCfg(token="ok"), client=_client(boom), clock=lambda: NOW)
    c.publish = lambda t, d: out.append(d)  # type: ignore[method-assign]
    await c.refresh()
    assert out[-1]["status"] == "error" and "reach" in out[-1]["message"]


def test_commit_count_is_capped_per_push():
    events = {"1": ["2026-11-23", 4982, "push", 10], "2": ["2026-11-23", 3, "push", 10]}
    d = build(events, {}, NOW.date(), "me")
    assert d.year.commits == 23 and d.year.total == 2
