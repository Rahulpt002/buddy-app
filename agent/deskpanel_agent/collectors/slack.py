"""`slack` topic: your Slack DMs, group DMs and @mentions, pushed live.

Documented APIs only: a private Slack app in your workspace (shared/slack-app-manifest.yaml)
with Socket Mode, so Slack pushes events down an outbound WebSocket and no public URL or open
port is needed. Events are the app's *user* events (message.im / .mpim / .channels / .groups),
i.e. what you can see. Channel messages are kept only when they mention you (or @here /
@channel). Your own messages mark that conversation read (you replied somewhere).

Slack's Events API doesn't report "read in the Slack app", so items also clear when you tap
them on the phone (`slack.read`) or open them on the Mac (`slack.open`).

The last 50 items survive restarts (SQLite). Tokens are never logged.
"""
from __future__ import annotations

import asyncio
import hashlib
import html
import json
import logging
import re
import time
from collections.abc import Awaitable, Callable
from typing import Any

import emoji
import httpx

from ..config import SlackCfg
from ..hub import ActionError
from ..protocol import SlackData, SlackMsg
from ..storage import Store
from .base import BaseProvider, run_cmd

log = logging.getLogger(__name__)

API = "https://slack.com/api/"
ITEMS_KEY = "slack.items"      # list of SlackMsg dicts, newest first
USERS_KEY = "slack.users"      # {user_id: name}
CHANNELS_KEY = "slack.channels"  # {channel_id: name}
MAX_ITEMS = 50
MAX_TEXT = 400
UNCONFIGURED_MSG = ("Add your Slack app and user tokens under [slack] in ~/.deskpanel/config.toml "
                    "(see README → Slack).")
# Subtypes that are real messages; everything else (joins, topic changes, ...) is ignored.
MESSAGE_SUBTYPES = {None, "thread_broadcast", "file_share", "me_message", "bot_message"}
COLORS = ["#E8912D", "#2EB67D", "#36C5F0", "#E01E5A", "#9B6BF2", "#ECB22E", "#1D9BD1", "#D85A9B"]
BROADCASTS = ("<!here", "<!channel", "<!everyone")

Connect = Callable[[str], Any]  # url -> async context manager yielding a websocket


# Slack-only shortcodes the emoji library doesn't know.
SLACK_ALIASES = {"simple_smile": "🙂", "thumbsup_all": "👍", "slack": "💬"}
SKIN_TONE = re.compile(r"::skin-tone-([2-6]):")


def emojize(text: str) -> str:
    """':+1::skin-tone-3: :tada:' -> '👍🏼 🎉'. Unknown (custom workspace) emoji keep their :name:."""
    text = SKIN_TONE.sub(lambda m: ": " + chr(0x1F3FB + int(m.group(1)) - 2) + " ", text)  # split, tone after
    text = re.sub(r":([a-z0-9_+-]+):", lambda m: SLACK_ALIASES.get(m.group(1), m.group(0)), text)
    text = emoji.emojize(text, language="alias")
    return re.sub(r"(\S) ([\U0001F3FB-\U0001F3FF]) ", r"\1\2", text)  # re-attach skin tones


def color_for(user_id: str) -> str:
    return COLORS[int(hashlib.sha1(user_id.encode()).hexdigest(), 16) % len(COLORS)]


def mpim_label(name: str, me: str | None) -> str:
    """'mpdm-alex--sam--me-1' -> 'alex, sam'."""
    core = re.sub(r"-\d+$", "", name.removeprefix("mpdm-"))
    people = [p for p in core.split("--") if p and p != me]
    return ", ".join(people) or name


class SlackError(Exception):
    pass


class SlackCollector(BaseProvider):
    topics = ("slack",)

    def __init__(self, store: Store, cfg: SlackCfg, client: httpx.AsyncClient | None = None,
                 connect: Connect | None = None, opener: Callable[[str], Awaitable[Any]] | None = None):
        super().__init__()
        self.store, self.cfg = store, cfg
        self.client = client
        self._connect = connect
        self._open = opener or (lambda url: run_cmd("open", url))
        self.me: str | None = None          # user id
        self.me_name: str | None = None     # username (for mpim names)
        self.team: str | None = None
        self.team_id: str | None = None
        self.status, self.message = "starting", None
        self.items: list[dict] = list(store.get(ITEMS_KEY) or [])
        for i in self.items:  # items saved before emoji conversion
            i["text"] = emojize(i["text"])
        self.users: dict[str, str] = dict(store.get(USERS_KEY) or {})
        self.channels: dict[str, str] = dict(store.get(CHANNELS_KEY) or {})
        self.actions = {"slack.read": self.mark_read, "slack.open": self.open_in_slack}

    @property
    def configured(self) -> bool:
        return bool((self.cfg.app_token or "").strip() and (self.cfg.user_token or "").strip())

    # ------------------------------------------------------------------ lifecycle

    async def setup(self) -> None:
        if not self.configured:
            self.status, self.message = "unconfigured", UNCONFIGURED_MSG
        self._publish()

    def loops(self) -> list[str]:
        return ["run"] if self.configured else []

    async def run(self) -> None:
        backoff = 2.0
        while True:
            try:
                if self.me is None:
                    await self._auth()
                url = (await self._api("apps.connections.open", token=self.cfg.app_token))["url"]
                await self._listen(url)
                backoff = 2.0  # clean disconnect (Slack refreshes the socket every few hours)
            except SlackError as e:
                self.status, self.message = "error", str(e)
                self._publish()
                await asyncio.sleep(300)  # bad token / missing scope: retry rarely
                continue
            except asyncio.CancelledError:
                raise
            except Exception as e:  # noqa: BLE001 - network: keep the last items, retry
                log.warning("slack: connection lost (%s); retrying in %.0fs", type(e).__name__, backoff)
            await asyncio.sleep(backoff)
            backoff = min(backoff * 2, 60)

    async def _listen(self, url: str) -> None:
        connect = self._connect
        if connect is None:
            import websockets

            connect = lambda u: websockets.connect(u, max_size=2**22)  # noqa: E731
        async with connect(url) as ws:
            async for raw in ws:
                env = json.loads(raw)
                if "envelope_id" in env:  # ack first: Slack retries after 3 s
                    await ws.send(json.dumps({"envelope_id": env["envelope_id"]}))
                kind = env.get("type")
                if kind == "hello":
                    if self.status != "ok":
                        log.info("slack: connected to %s", self.team or "workspace")
                    self.status, self.message = "ok", None
                    self._publish()
                elif kind == "events_api":
                    try:
                        await self.on_event((env.get("payload") or {}).get("event") or {})
                    except Exception:  # noqa: BLE001 - one bad event mustn't drop the socket
                        log.exception("slack: event handling failed")
                elif kind == "disconnect":
                    return

    # ------------------------------------------------------------------ web api

    async def _api(self, method: str, token: str | None = None, **params: Any) -> dict:
        client = self.client or httpx.AsyncClient(timeout=15)
        try:
            for _ in range(3):
                r = await client.post(API + method, data=params,
                                      headers={"Authorization": f"Bearer {token or self.cfg.user_token}"})
                if r.status_code == 429:
                    await asyncio.sleep(float(r.headers.get("retry-after", "5")))
                    continue
                r.raise_for_status()
                j = r.json()
                if j.get("ok"):
                    return j
                err = j.get("error", "unknown_error")
                if err in ("invalid_auth", "not_authed", "token_revoked", "account_inactive"):
                    which = "app" if method == "apps.connections.open" else "user"
                    raise SlackError(f"Slack rejected the {which} token ({err}). "
                                     "Check [slack] in ~/.deskpanel/config.toml.")
                if err == "missing_scope":
                    raise SlackError(f"Slack app is missing a scope ({j.get('needed', '?')}). "
                                     "Recreate it from shared/slack-app-manifest.yaml and reinstall.")
                raise SlackError(f"Slack {method} failed: {err}")
            raise SlackError(f"Slack {method}: rate limited")
        finally:
            if self.client is None:
                await client.aclose()

    async def _auth(self) -> None:
        j = await self._api("auth.test")
        self.me, self.me_name = j.get("user_id"), j.get("user")
        self.team, self.team_id = j.get("team"), j.get("team_id")

    async def user_name(self, uid: str) -> str:
        if uid not in self.users:
            try:
                u = (await self._api("users.info", user=uid)).get("user") or {}
                p = u.get("profile") or {}
                self.users[uid] = p.get("display_name") or p.get("real_name") or u.get("name") or uid
            except SlackError:
                self.users[uid] = uid
            self.store.set(USERS_KEY, self.users)
        return self.users[uid]

    async def channel_name(self, cid: str) -> str:
        if cid not in self.channels:
            try:
                self.channels[cid] = (await self._api("conversations.info", channel=cid))["channel"].get("name") or cid
            except SlackError:
                self.channels[cid] = cid
            self.store.set(CHANNELS_KEY, self.channels)
        return self.channels[cid]

    async def plain_text(self, text: str) -> str:
        """Slack mrkdwn -> readable text (mentions, channels, links resolved)."""
        async def sub_user(m: re.Match) -> str:
            return "@" + (m.group(2) or await self.user_name(m.group(1)))

        out, last = [], 0
        for m in re.finditer(r"<@([UW][A-Z0-9]+)(?:\|([^>]+))?>", text):
            out += [text[last:m.start()], await sub_user(m)]
            last = m.end()
        text = "".join(out) + text[last:]
        text = re.sub(r"<#[A-Z0-9]+\|([^>]*)>", r"#\1", text)
        text = re.sub(r"<#[A-Z0-9]+>", "#channel", text)
        text = re.sub(r"<!subteam\^[A-Z0-9]+\|([^>]+)>", r"\1", text)
        text = re.sub(r"<!(here|channel|everyone)(?:\|[^>]*)?>", r"@\1", text)
        text = re.sub(r"<![^|>]+\|([^>]+)>", r"\1", text)  # <!date^...|fallback>
        text = re.sub(r"<(?:https?|mailto):[^|>]+\|([^>]+)>", r"\1", text)
        text = re.sub(r"<((?:https?|mailto):[^>]+)>", r"\1", text)
        text = emojize(html.unescape(text)).strip()
        return text if len(text) <= MAX_TEXT else text[: MAX_TEXT - 1].rstrip() + "…"

    # ------------------------------------------------------------------ events

    def _is_mention(self, text: str) -> bool:
        return (self.me is not None and f"<@{self.me}" in text) or any(b in text for b in BROADCASTS)

    async def on_event(self, ev: dict) -> None:
        if ev.get("type") != "message":
            return
        sub, cid = ev.get("subtype"), ev.get("channel") or ""
        if sub == "message_deleted":
            self._remove(f"{cid}:{ev.get('deleted_ts')}")
            return
        if sub == "message_changed":
            new = ev.get("message") or {}
            item = self._find(f"{cid}:{new.get('ts')}")
            if item is not None:
                item["text"] = await self.plain_text(new.get("text") or "")
                self._save()
            return
        if sub not in MESSAGE_SUBTYPES:
            return
        uid = ev.get("user") or ""
        if uid and uid == self.me:  # you wrote here: you've seen this conversation
            if any(i["channel_id"] == cid and i["unread"] for i in self.items):
                for i in self.items:
                    if i["channel_id"] == cid:
                        i["unread"] = False
                self._save()
            return
        ctype, raw = ev.get("channel_type"), ev.get("text") or ""
        if ctype == "im":
            kind = "dm"
        elif ctype == "mpim":
            kind = "group"
        elif self._is_mention(raw):
            kind = "mention"
        else:
            return

        if uid:
            sender = await self.user_name(uid)
        else:
            sender = (ev.get("bot_profile") or {}).get("name") or ev.get("username") or "Slack"
        if kind == "dm":
            channel = sender
        elif kind == "group":
            channel = mpim_label(await self.channel_name(cid), self.me_name)
        else:
            channel = "#" + await self.channel_name(cid)
        text = await self.plain_text(raw)
        if not text:
            files = ev.get("files") or []
            text = f"[file] {files[0].get('name', '')}".strip() if files else "(no text)"
        ts = ev.get("ts") or "0"
        item = SlackMsg(
            id=f"{cid}:{ts}", ts=int(float(ts) * 1000), channel_id=cid, channel=channel, kind=kind,
            sender=sender, sender_color=color_for(uid or sender), text=text,
            thread=bool(ev.get("thread_ts")) and ev.get("thread_ts") != ts,
        ).model_dump()
        self.items = [item] + [i for i in self.items if i["id"] != item["id"]]
        self.items.sort(key=lambda i: -i["ts"])
        del self.items[MAX_ITEMS:]
        log.info("slack: new %s", kind)  # never the text or sender
        self._save()

    # ------------------------------------------------------------------ actions

    async def mark_read(self, params: dict, _progress) -> dict:
        mid, cid, every = params.get("id"), params.get("channel_id"), params.get("all")
        if not (mid or cid or every):
            raise ActionError("bad_request", "id, channel_id or all required")
        n = 0
        for i in self.items:
            if i["unread"] and (every or i["id"] == mid or i["channel_id"] == cid):
                i["unread"] = False
                n += 1
        if n:
            self._save()
        return {"marked": n}

    async def open_in_slack(self, params: dict, progress) -> dict:
        cid = params.get("channel_id")
        if not isinstance(cid, str) or not re.fullmatch(r"[A-Z0-9]+", cid):
            raise ActionError("bad_request", "channel_id required")
        url = f"slack://channel?id={cid}" + (f"&team={self.team_id}" if self.team_id else "")
        await self._open(url)
        await self.mark_read({"channel_id": cid}, progress)
        return {"message": "Opened in Slack"}

    # ------------------------------------------------------------------ state

    def _find(self, mid: str) -> dict | None:
        return next((i for i in self.items if i["id"] == mid), None)

    def _remove(self, mid: str) -> None:
        if self._find(mid) is not None:
            self.items = [i for i in self.items if i["id"] != mid]
            self._save()

    def _save(self) -> None:
        self.store.set(ITEMS_KEY, self.items)
        self._publish()

    def snapshot(self) -> SlackData:
        return SlackData(
            status=self.status if self.status != "starting" or not self.items else "ok",
            message=self.message, team=self.team, user=self.me_name,
            unread=sum(1 for i in self.items if i["unread"]),
            messages=[SlackMsg.model_validate(i) for i in self.items],
        )

    def _publish(self) -> None:
        if self.hub is not None:
            self.publish("slack", self.snapshot())
