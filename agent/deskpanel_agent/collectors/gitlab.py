"""`gitlab` topic: GitLab contributions in the same shape as GitHub (`GithubData`), so the
phone's GitHub page can show either with one layout.

Documented REST API only (https://docs.gitlab.com/api/events/), with a personal access token
(scope `read_api`, or `read_user` + `read_api`): the user's contribution events for the last
year, cached locally so each refresh only fetches new events. Project names/visibility are
looked up once per project. Refreshed every 15 minutes.
"""
from __future__ import annotations

import asyncio
import datetime as dt
import logging
import time
from collections import Counter
from typing import Any

import httpx

from ..config import GitlabCfg
from ..protocol import ContribDay, GithubData, GithubYear, RepoCount
from ..storage import Store
from .base import BaseProvider
from .github import best_day, current_streak, longest_streak, week_split, week_start

log = logging.getLogger(__name__)

REFRESH_S = 15 * 60
EVENTS_KEY = "gitlab.events"      # {event_id: [iso_date, commits, kind, project_id]}
PROJECTS_KEY = "gitlab.projects"  # {project_id: [name, visibility]}
CACHE_KEY = "gitlab.cache"
UNCONFIGURED_MSG = ("Add a GitLab token under [gitlab] in ~/.deskpanel/config.toml "
                    "(personal access token with read_api).")
REJECTED_MSG = "GitLab rejected the token (401). Check token under [gitlab] in ~/.deskpanel/config.toml."
NOT_CONTRIBUTIONS = {"joined", "left", "expired", "imported"}
# GitLab's push events carry a commit_count that, for branch creations and syncs/merges of
# others' work, counts whole branch histories (thousands of commits in one push). GitLab offers
# no cheap way to dedupe commits, so each push contributes at most this many.
MAX_COMMITS_PER_PUSH = 20


def level_of(count: int) -> int:
    """GitLab's calendar legend: 0, 1-9, 10-19, 20-29, 30+."""
    return 0 if count <= 0 else 1 if count < 10 else 2 if count < 20 else 3 if count < 30 else 4


def classify(ev: dict) -> tuple[str, int] | None:
    """Event -> (kind, commits), or None if it isn't a contribution."""
    action = (ev.get("action_name") or "").lower()
    if action in NOT_CONTRIBUTIONS:
        return None
    target = (ev.get("target_type") or "")
    if action.startswith("pushed"):
        return "push", int((ev.get("push_data") or {}).get("commit_count") or 0)
    if action == "opened" and target == "Issue":
        return "issue", 0
    if action == "opened" and target == "MergeRequest":
        return "mr", 0
    if action in ("approved",) or (target == "MergeRequest" and action in ("accepted", "merged")):
        return "review", 0
    return "other", 0


def build(events: dict[str, list], projects: dict[str, list], today: dt.date,
          user: str | None, fetched_at: int | None = None) -> GithubData:
    start = week_start(today) - dt.timedelta(weeks=52)
    counts: Counter[dt.date] = Counter()
    commits = issues = mrs = reviews = private = 0
    per_project: Counter[str] = Counter()
    for date_s, n_commits, kind, pid in events.values():
        d = dt.date.fromisoformat(date_s)
        if d < start or d > today:
            continue
        counts[d] += 1
        commits += min(n_commits, MAX_COMMITS_PER_PUSH)
        issues += kind == "issue"
        mrs += kind == "mr"
        reviews += kind == "review"
        per_project[str(pid)] += 1
        if (projects.get(str(pid)) or [None, None])[1] == "private":
            private += 1
    weeks: list[list[ContribDay]] = []
    for w in range(53):
        col = []
        for i in range(7):
            d = start + dt.timedelta(days=w * 7 + i)
            if d > today:
                break
            c = counts.get(d, 0)
            col.append(ContribDay(date=d.isoformat(), count=c, level=level_of(c)))
        if col:
            weeks.append(col)
    days = [d for col in weeks for d in col]
    top = [RepoCount(name=(projects.get(pid) or [f"project {pid}"])[0], count=n)
           for pid, n in sorted(per_project.items(), key=lambda kv: (-kv[1], kv[0]))[:4]]
    from ..protocol import Streak

    return GithubData(
        user=user, fetched_at=fetched_at,
        year=GithubYear(total=sum(counts.values()), commits=commits, private=private, issues=issues,
                        prs=mrs, reviews=reviews, weeks=weeks),
        streak=Streak(current=current_streak(days, today), longest=longest_streak(days),
                      best_day=best_day(days)),
        week=week_split(days, today),
        top_repos=top,
    )


class GitlabError(Exception):
    pass


class GitlabCollector(BaseProvider):
    topics = ("gitlab",)

    def __init__(self, store: Store, cfg: GitlabCfg, client: httpx.AsyncClient | None = None,
                 interval: float = REFRESH_S, clock=None):
        super().__init__()
        self.store, self.cfg, self.client, self.interval = store, cfg, client, interval
        self.clock = clock or (lambda: dt.datetime.now().astimezone())
        self.user: dict | None = None

    @property
    def token(self) -> str | None:
        t = (self.cfg.token or "").strip()
        return t or None

    @property
    def base(self) -> str:
        return (self.cfg.base_url or "https://gitlab.com").rstrip("/") + "/api/v4"

    async def setup(self) -> None:
        if not self.token:
            self.publish("gitlab", {"status": "unconfigured", "message": UNCONFIGURED_MSG})
            return
        cached = self.store.get(CACHE_KEY)
        if cached:
            self.publish("gitlab", cached)

    def loops(self) -> list[str]:
        return ["run"] if self.token else []

    async def run(self) -> None:
        while True:
            await self.refresh()
            await asyncio.sleep(self.interval)

    async def _get(self, client: httpx.AsyncClient, path: str, **params) -> httpx.Response:
        r = await client.get(self.base + path, params=params, headers={"PRIVATE-TOKEN": self.token or ""})
        if r.status_code == 401:
            raise GitlabError(REJECTED_MSG)
        if r.status_code == 403:
            raise GitlabError("GitLab refused the request (403): the token needs the read_api scope.")
        r.raise_for_status()
        return r

    async def refresh(self) -> None:
        client = self.client or httpx.AsyncClient(timeout=20)
        try:
            data = await self._fetch(client)
        except GitlabError as e:
            self.publish("gitlab", {"status": "error", "message": str(e)})
            return
        except (httpx.HTTPError, ValueError) as e:
            log.warning("gitlab: refresh failed (%s); keeping last data", type(e).__name__)
            if not self.store.get(CACHE_KEY):
                self.publish("gitlab", {"status": "error", "message": "Can't reach GitLab. Retrying…"})
            return
        finally:
            if self.client is None:
                await client.aclose()
        payload = data.model_dump(mode="json")
        self.store.set(CACHE_KEY, payload)
        self.publish("gitlab", data)

    async def _fetch(self, client: httpx.AsyncClient) -> GithubData:
        if self.user is None:
            self.user = (await self._get(client, "/user")).json()
        uid = self.user["id"]
        now = self.clock()
        today = now.date()
        events: dict[str, list] = dict(self.store.get(EVENTS_KEY) or {})
        newest = max((v[0] for v in events.values()), default=None)
        # First run: a year back. Later: re-read the last 2 days (late events, edits) onward.
        after = (dt.date.fromisoformat(newest) - dt.timedelta(days=2)) if newest else today - dt.timedelta(days=372)
        page: str | None = "1"
        while page:
            r = await self._get(client, f"/users/{uid}/events", after=after.isoformat(), per_page=100,
                                page=page, sort="asc")
            for ev in r.json():
                c = classify(ev)
                if c is None or "created_at" not in ev:
                    continue
                when = dt.datetime.fromisoformat(ev["created_at"].replace("Z", "+00:00")).astimezone(now.tzinfo)
                events[str(ev["id"])] = [when.date().isoformat(), c[1], c[0], ev.get("project_id")]
            page = r.headers.get("x-next-page") or None
        cutoff = (today - dt.timedelta(days=372)).isoformat()
        events = {k: v for k, v in events.items() if v[0] >= cutoff}
        self.store.set(EVENTS_KEY, events)

        projects: dict[str, list] = dict(self.store.get(PROJECTS_KEY) or {})
        for pid in {str(v[3]) for v in events.values() if v[3] is not None} - projects.keys():
            try:
                p = (await self._get(client, f"/projects/{pid}")).json()
                projects[pid] = [p.get("name") or p.get("path") or f"project {pid}", p.get("visibility")]
            except httpx.HTTPStatusError:
                projects[pid] = [f"project {pid}", None]  # no longer accessible
        self.store.set(PROJECTS_KEY, projects)
        return build(events, projects, today, self.user.get("username"), int(time.time() * 1000))

    # Keeps the signature in line with other collectors.
    def snapshot(self) -> Any:  # pragma: no cover
        return self.store.get(CACHE_KEY)
