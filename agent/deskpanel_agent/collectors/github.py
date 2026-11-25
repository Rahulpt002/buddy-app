"""`github` topic: the viewer's contribution calendar, streaks, this week vs last week and
top repos, from ONE GitHub GraphQL request every 15 minutes.

The last good payload is cached in the Store (`github.cache`) and published on startup so
the phone has data while the first fetch runs. Network failures keep the cached data;
auth / GraphQL errors are surfaced as status "error". The token is never logged.

Derived values (streaks, weeks, top repos) are pure functions of the parsed calendar and
the laptop's local "today", so they are unit-tested without the network.
"""
from __future__ import annotations

import asyncio
import datetime as dt
import logging
from typing import Any, Callable, Iterable

import httpx

from ..config import GithubCfg
from ..hub import now_ms
from ..protocol import (
    BestDay, ContribDay, GithubData, GithubYear, RepoCount, Streak, Week,
)
from ..storage import Store
from .base import BaseProvider

log = logging.getLogger(__name__)

GRAPHQL_URL = "https://api.github.com/graphql"
REFRESH_S = 15 * 60
CACHE_KEY = "github.cache"
TOP_REPOS = 4
MAX_WEEKS = 53

UNCONFIGURED_MSG = ("Add a GitHub token under [github] in ~/.deskpanel/config.toml "
                    "(classic token with read:user; add repo for private repos).")
REJECTED_MSG = ("GitHub rejected the token (401). Check the token under [github] in "
                "~/.deskpanel/config.toml; it may be expired or revoked.")

LEVELS = {
    "NONE": 0,
    "FIRST_QUARTILE": 1,
    "SECOND_QUARTILE": 2,
    "THIRD_QUARTILE": 3,
    "FOURTH_QUARTILE": 4,
}

QUERY = """
query($from: DateTime!, $to: DateTime!) {
  viewer {
    login
    contributionsCollection(from: $from, to: $to) {
      totalCommitContributions
      restrictedContributionsCount
      totalIssueContributions
      totalPullRequestContributions
      totalPullRequestReviewContributions
      contributionCalendar {
        totalContributions
        weeks { contributionDays { date contributionCount contributionLevel } }
      }
      commitContributionsByRepository(maxRepositories: 10) {
        repository { name nameWithOwner isPrivate }
        contributions { totalCount }
      }
    }
  }
}
"""


class GithubError(Exception):
    """An error to show on the phone (bad token, GraphQL error, unexpected response)."""


class GithubTransient(Exception):
    """A temporary failure (network, GitHub 5xx): keep showing the cached data."""


# -------------------------------------------------------------------- pure helpers


def week_start(d: dt.date) -> dt.date:
    """The Sunday that starts d's week (GitHub's grid starts weeks on Sunday)."""
    return d - dt.timedelta(days=(d.weekday() + 1) % 7)


def query_range(now: dt.datetime) -> tuple[dt.datetime, dt.datetime]:
    """(from, to) for the last year. `from` is the Sunday 52 weeks before this week's Sunday
    (53 grid columns), clamped so the span stays within GitHub's one-year limit; the first
    column may then be partial, exactly like GitHub's own profile grid."""
    today = now.date()
    aligned = week_start(today) - dt.timedelta(weeks=52)
    start = max(aligned, today - dt.timedelta(days=364))
    return dt.datetime.combine(start, dt.time(0), tzinfo=now.tzinfo), now


def level_of(name: str | None, count: int = 0) -> int:
    """GitHub contributionLevel -> 0..4 (unknown values fall back on the count)."""
    if name in LEVELS:
        return LEVELS[name]
    return 0 if count <= 0 else 1


def _counts(days: Iterable[ContribDay]) -> dict[dt.date, int]:
    out: dict[dt.date, int] = {}
    for d in days:
        try:
            out[dt.date.fromisoformat(d.date)] = d.count
        except ValueError:
            continue
    return out


def current_streak(days: Iterable[ContribDay], today: dt.date) -> int:
    """Consecutive days with contributions ending today. If today has none yet, count up to
    yesterday, so the streak stays alive during the day."""
    counts = _counts(days)
    d = today if counts.get(today, 0) > 0 else today - dt.timedelta(days=1)
    n = 0
    while counts.get(d, 0) > 0:
        n += 1
        d -= dt.timedelta(days=1)
    return n


def longest_streak(days: Iterable[ContribDay]) -> int:
    best = run = 0
    prev: dt.date | None = None
    for d, c in sorted(_counts(days).items()):
        if c > 0:
            run = run + 1 if prev is not None and d - prev == dt.timedelta(days=1) else 1
            prev = d
            best = max(best, run)
        else:
            run, prev = 0, None
    return best


def best_day(days: Iterable[ContribDay]) -> BestDay | None:
    """Highest count (most recent on ties); None if there were no contributions."""
    top: tuple[int, dt.date] | None = None
    for d, c in _counts(days).items():
        if c > 0 and (top is None or (c, d) > top):
            top = (c, d)
    return None if top is None else BestDay(date=top[1].isoformat(), count=top[0])


def week_split(days: Iterable[ContribDay], today: dt.date) -> Week:
    """This week Sun..Sat (None after today) vs last week, with the total and delta."""
    counts = _counts(days)
    sun = week_start(today)
    this: list[int | None] = []
    for i in range(7):
        d = sun + dt.timedelta(days=i)
        this.append(counts.get(d, 0) if d <= today else None)
    last = [counts.get(sun - dt.timedelta(days=7 - i), 0) for i in range(7)]
    total = sum(c for c in this if c is not None)
    return Week(this=this, last=last, this_total=total, delta=total - sum(last))


def top_repos(items: list[dict] | None, n: int = TOP_REPOS) -> list[RepoCount]:
    """commitContributionsByRepository -> the n repos with the most commits."""
    repos = []
    for it in items or []:
        repo = (it or {}).get("repository") or {}
        name = repo.get("name") or repo.get("nameWithOwner")
        count = int(((it or {}).get("contributions") or {}).get("totalCount") or 0)
        if name:
            repos.append(RepoCount(name=name, count=count))
    repos.sort(key=lambda r: (-r.count, r.name.lower()))
    return repos[:n]


def parse_response(body: Any, today: dt.date, fetched_at: int | None = None) -> GithubData:
    """A GraphQL response body -> GithubData. Raises GithubError on GraphQL errors or an
    unexpected shape."""
    if not isinstance(body, dict):
        raise GithubError("Unexpected response from GitHub")
    errors = body.get("errors")
    if errors:
        msgs = [str(e.get("message", e)) if isinstance(e, dict) else str(e) for e in errors]
        raise GithubError("GitHub: " + "; ".join(msgs))
    try:
        viewer = body["data"]["viewer"]
        cc = viewer["contributionsCollection"]
        cal = cc["contributionCalendar"]
        weeks: list[list[ContribDay]] = []
        for w in cal["weeks"]:
            col = []
            for d in w["contributionDays"]:
                count = int(d["contributionCount"])
                col.append(ContribDay(date=d["date"], count=count,
                                      level=level_of(d.get("contributionLevel"), count)))
            if col:
                weeks.append(col)
        weeks = weeks[-MAX_WEEKS:]
        year = GithubYear(
            total=int(cal["totalContributions"]),
            commits=int(cc.get("totalCommitContributions") or 0),
            private=int(cc.get("restrictedContributionsCount") or 0),
            issues=int(cc.get("totalIssueContributions") or 0),
            prs=int(cc.get("totalPullRequestContributions") or 0),
            reviews=int(cc.get("totalPullRequestReviewContributions") or 0),
            weeks=weeks,
        )
        repos = top_repos(cc.get("commitContributionsByRepository"))
        login = viewer.get("login")
    except (KeyError, TypeError, ValueError) as e:
        raise GithubError("Unexpected response from GitHub") from e

    days = [d for w in weeks for d in w]
    return GithubData(
        user=login,
        fetched_at=fetched_at if fetched_at is not None else now_ms(),
        year=year,
        streak=Streak(current=current_streak(days, today), longest=longest_streak(days),
                      best_day=best_day(days)),
        week=week_split(days, today),
        top_repos=repos,
    )


# -------------------------------------------------------------------- collector


def _local_now() -> dt.datetime:
    return dt.datetime.now().astimezone()


class GithubCollector(BaseProvider):
    topics = ("github",)

    def __init__(
        self,
        store: Store,
        cfg: GithubCfg,
        client: httpx.AsyncClient | None = None,
        interval: float = REFRESH_S,
        clock: Callable[[], dt.datetime] = _local_now,
    ) -> None:
        super().__init__()
        self.store, self.cfg = store, cfg
        self._client = client  # injectable for tests; otherwise one per fetch
        self.interval = interval
        self.clock = clock

    @property
    def token(self) -> str | None:
        t = (self.cfg.token or "").strip()
        return t or None

    async def setup(self) -> None:
        if not self.token:
            self.publish("github", {"status": "unconfigured", "message": UNCONFIGURED_MSG})
            return
        cached = self.cached()
        if cached is not None:
            self.publish("github", cached)

    def loops(self) -> list[str]:
        return ["run"] if self.token else []

    async def run(self) -> None:
        while True:
            await self.refresh()
            await asyncio.sleep(self.interval)

    def cached(self) -> GithubData | None:
        raw = self.store.get(CACHE_KEY)
        if not raw:
            return None
        try:
            return GithubData.model_validate(raw)
        except Exception:  # noqa: BLE001 - a stale/corrupt cache is just ignored
            log.warning("github: ignoring unreadable cache")
            return None

    async def refresh(self) -> GithubData | dict:
        """Fetch once and publish the result (or an error / the cache). Returns what was
        published."""
        now = self.clock()
        try:
            body = await self.fetch(now)
            data = parse_response(body, now.date())
        except GithubTransient as e:
            log.warning("github: fetch failed (%s); keeping last data", e)
            cached = self.cached()
            out: GithubData | dict = cached if cached is not None else {
                "status": "error", "message": f"Can't reach GitHub: {e}"}
            self.publish("github", out)
            return out
        except GithubError as e:
            log.warning("github: %s", e)
            out = {"status": "error", "message": str(e)}
            self.publish("github", out)
            return out
        self.store.set(CACHE_KEY, data.model_dump(mode="json"))
        self.publish("github", data)
        return data

    async def fetch(self, now: dt.datetime) -> Any:
        """POST the GraphQL query; returns the decoded JSON body. Raises GithubError /
        GithubTransient."""
        frm, to = query_range(now)
        payload = {"query": QUERY, "variables": {"from": frm.isoformat(timespec="seconds"),
                                                 "to": to.isoformat(timespec="seconds")}}
        headers = {"Authorization": f"bearer {self.token}", "User-Agent": "deskpanel-agent",
                   "Accept": "application/json"}
        try:
            if self._client is not None:
                r = await self._client.post(GRAPHQL_URL, json=payload, headers=headers)
            else:
                async with httpx.AsyncClient(timeout=httpx.Timeout(20.0)) as client:
                    r = await client.post(GRAPHQL_URL, json=payload, headers=headers)
        except httpx.HTTPError as e:
            # httpx messages carry the URL at most, never request headers.
            raise GithubTransient(type(e).__name__ if not str(e) else str(e)) from None

        if r.status_code == 401:
            raise GithubError(REJECTED_MSG)
        if r.status_code >= 500 or r.status_code == 429:
            raise GithubTransient(f"HTTP {r.status_code}")
        if r.status_code >= 400:
            raise GithubError(f"GitHub refused the request (HTTP {r.status_code}): {_api_message(r)}")
        try:
            return r.json()
        except ValueError:
            raise GithubError("Unexpected response from GitHub") from None


def _api_message(r: httpx.Response) -> str:
    try:
        msg = r.json().get("message")
    except (ValueError, AttributeError):
        msg = None
    return str(msg or r.reason_phrase or "error")[:200]
