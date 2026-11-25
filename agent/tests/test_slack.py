import json
from contextlib import asynccontextmanager

import httpx
import pytest

from deskpanel_agent.collectors.slack import (
    ITEMS_KEY, UNCONFIGURED_MSG, SlackCollector, SlackError, color_for, mpim_label)
from deskpanel_agent.config import SlackCfg
from deskpanel_agent.hub import ActionError, Hub
from deskpanel_agent.protocol import SlackData
from deskpanel_agent.storage import Store

CFG = SlackCfg(app_token="xapp-test", user_token="xoxp-test")
USERS = {"U1": "Maya", "U2": "Jonas", "UME": "me"}
CHANNELS = {"C1": "deploys", "G1": "mpdm-maya--jonas--me-1", "D1": "D1"}


def api(calls: list | None = None, auth_ok=True):
    def handler(req: httpx.Request) -> httpx.Response:
        method = req.url.path.rsplit("/", 1)[-1]
        form = dict(httpx.QueryParams(req.content.decode()))
        if calls is not None:
            calls.append(method)
        if method == "auth.test":
            if not auth_ok:
                return httpx.Response(200, json={"ok": False, "error": "invalid_auth"})
            return httpx.Response(200, json={"ok": True, "user_id": "UME", "user": "me", "team": "Acme", "team_id": "T1"})
        if method == "users.info":
            return httpx.Response(200, json={"ok": True, "user": {"name": USERS[form["user"]], "profile": {}}})
        if method == "conversations.info":
            return httpx.Response(200, json={"ok": True, "channel": {"name": CHANNELS[form["channel"]]}})
        if method == "apps.connections.open":
            return httpx.Response(200, json={"ok": True, "url": "wss://example.invalid/socket"})
        return httpx.Response(404)

    return httpx.AsyncClient(transport=httpx.MockTransport(handler))


async def collector(tmp_path, **kw):
    c = SlackCollector(Store(tmp_path / "db.sqlite"), kw.pop("cfg", CFG), client=api(**kw))
    hub = Hub()
    c.hub = hub
    await c._auth()
    return c, hub


def msg(text, channel="C1", ctype="channel", user="U1", ts="1700000000.000100", **extra):
    return {"type": "message", "channel": channel, "channel_type": ctype, "user": user, "text": text,
            "ts": ts, **extra}


async def test_dms_groups_and_mentions_are_kept_other_channel_chatter_is_not(tmp_path):
    c, _ = await collector(tmp_path)
    await c.on_event(msg("hey there", channel="D1", ctype="im"))
    await c.on_event(msg("lunch?", channel="G1", ctype="mpim", user="U2", ts="1700000001.0"))
    await c.on_event(msg("<@UME> please approve", user="U2", ts="1700000002.0"))
    await c.on_event(msg("<!here> standup moved", ts="1700000003.0"))
    await c.on_event(msg("just chatting", ts="1700000004.0"))           # not for me
    await c.on_event(msg("joined", subtype="channel_join", ts="1700000005.0"))
    d = c.snapshot()
    SlackData.model_validate(d.model_dump())
    assert [m.kind for m in d.messages] == ["mention", "mention", "group", "dm"]  # newest first
    dm = d.messages[-1]
    assert (dm.channel, dm.sender, dm.text, dm.ts) == ("Maya", "Maya", "hey there", 1700000000000)
    assert d.messages[2].channel == "maya, jonas"
    assert d.messages[1].channel == "#deploys" and d.messages[1].text == "@me please approve"
    assert d.unread == 4


async def test_text_is_made_readable(tmp_path):
    c, _ = await collector(tmp_path)
    t = await c.plain_text("<@U2> see <#C9|ops> and <https://x.io/a|the doc> &amp; <https://y.io> <!channel>")
    assert t == "@Jonas see #ops and the doc & https://y.io @channel"
    assert len(await c.plain_text("x" * 1000)) == 400


async def test_my_reply_marks_that_conversation_read(tmp_path):
    c, _ = await collector(tmp_path)
    await c.on_event(msg("hey", channel="D1", ctype="im"))
    await c.on_event(msg("<@UME> ping", ts="1700000001.0"))
    await c.on_event(msg("on it", channel="D1", ctype="im", user="UME", ts="1700000002.0"))
    d = c.snapshot()
    assert d.unread == 1 and len(d.messages) == 2  # my own message isn't listed


async def test_edits_deletes_and_persistence(tmp_path):
    c, _ = await collector(tmp_path)
    await c.on_event(msg("tpyo", channel="D1", ctype="im"))
    await c.on_event({"type": "message", "subtype": "message_changed", "channel": "D1",
                      "message": {"ts": "1700000000.000100", "text": "typo"}})
    assert c.snapshot().messages[0].text == "typo"
    again = SlackCollector(Store(tmp_path / "db.sqlite"), CFG, client=api())
    assert again.snapshot().messages[0].text == "typo"  # survives a restart
    await c.on_event({"type": "message", "subtype": "message_deleted", "channel": "D1",
                      "deleted_ts": "1700000000.000100"})
    assert c.snapshot().messages == []


async def test_read_and_open_actions(tmp_path):
    opened = []

    async def opener(url):
        opened.append(url)

    c, _ = await collector(tmp_path)
    c._open = opener
    await c.on_event(msg("a", channel="D1", ctype="im"))
    await c.on_event(msg("<@UME> b", ts="1700000001.0"))
    assert (await c.mark_read({"id": "D1:1700000000.000100"}, None)) == {"marked": 1}
    assert c.snapshot().unread == 1
    await c.open_in_slack({"channel_id": "C1"}, None)
    assert opened == ["slack://channel?id=C1&team=T1"] and c.snapshot().unread == 0
    with pytest.raises(ActionError):
        await c.open_in_slack({"channel_id": "C1; rm -rf"}, None)
    with pytest.raises(ActionError):
        await c.mark_read({}, None)


async def test_socket_mode_acks_and_dispatches(tmp_path):
    sent = []

    class FakeWS:
        def __init__(self, frames):
            self.frames = frames

        async def send(self, s):
            sent.append(json.loads(s))

        def __aiter__(self):
            return self._gen()

        async def _gen(self):
            for f in self.frames:
                yield json.dumps(f)

    frames = [
        {"type": "hello"},
        {"type": "events_api", "envelope_id": "e1",
         "payload": {"event": msg("hi", channel="D1", ctype="im")}},
        {"type": "disconnect", "reason": "refresh_requested"},
    ]

    @asynccontextmanager
    async def connect(url):
        assert url == "wss://example.invalid/socket"
        yield FakeWS(frames)

    c, _ = await collector(tmp_path)
    c._connect = connect
    await c._listen("wss://example.invalid/socket")
    assert sent == [{"envelope_id": "e1"}]
    assert c.status == "ok" and c.snapshot().unread == 1


async def test_unconfigured_and_rejected(tmp_path):
    c = SlackCollector(Store(tmp_path / "db.sqlite"), SlackCfg(), client=api())
    c.hub = Hub()
    await c.setup()
    assert c.loops() == [] and c.snapshot().status == "unconfigured"
    assert c.snapshot().message == UNCONFIGURED_MSG
    bad = SlackCollector(Store(tmp_path / "db2.sqlite"), CFG, client=api(auth_ok=False))
    with pytest.raises(SlackError, match="rejected the user token"):
        await bad._auth()


def test_helpers():
    assert color_for("U1") == color_for("U1") and color_for("U1").startswith("#")
    assert mpim_label("mpdm-alex--sam--me-1", "me") == "alex, sam"
    assert ITEMS_KEY == "slack.items"


async def test_emoji_shortcodes_become_emoji(tmp_path):
    c, _ = await collector(tmp_path)
    t = await c.plain_text(":+1::skin-tone-3: thanks :tada: at 12:30:45 :partyparrot: :simple_smile:")
    assert t == "👍🏼 thanks 🎉 at 12:30:45 :partyparrot: 🙂"
