import pytest

from deskpanel_agent import browser_tab as bt
from deskpanel_agent.browser_tab import SEP, Tab, candidates, fmt_time, is_youtube_video, parse_tabs, with_time


def test_youtube_links_get_the_same_moment():
    assert with_time("https://www.youtube.com/watch?v=abc123&list=PL1", 192.7) == \
        "https://www.youtube.com/watch?v=abc123&list=PL1&t=192s"
    assert with_time("https://www.youtube.com/watch?v=abc&t=10s", 75) == "https://www.youtube.com/watch?v=abc&t=75s"
    assert with_time("https://youtu.be/abc123", 61) == "https://youtu.be/abc123?t=61s"
    assert with_time("https://www.youtube.com/shorts/xyz", 30) == "https://www.youtube.com/shorts/xyz"
    assert with_time("https://example.com/page", 30) == "https://example.com/page"
    assert with_time("https://www.youtube.com/watch?v=abc", 1) == "https://www.youtube.com/watch?v=abc"


def test_what_counts_as_a_video():
    assert is_youtube_video("https://m.youtube.com/watch?v=a")
    assert is_youtube_video("https://youtu.be/a")
    assert not is_youtube_video("https://www.youtube.com/")
    assert not is_youtube_video("https://www.youtube.com/results?search_query=x")


def test_parse_and_choose_tabs():
    out = "\n".join([
        f"1{SEP}1{SEP}false{SEP}https://www.youtube.com/watch?v=old{SEP}Old video - YouTube",
        f"1{SEP}2{SEP}true{SEP}https://news.example.com/{SEP}News",
        f"2{SEP}1{SEP}true{SEP}https://www.youtube.com/watch?v=vis{SEP}Visible - YouTube",
        f"2{SEP}2{SEP}false{SEP}chrome://settings{SEP}Settings",
    ])
    tabs = parse_tabs("Google Chrome", out)
    assert len(tabs) == 3  # chrome:// skipped
    order = [t.url.rsplit("=", 1)[-1] for t in candidates(tabs)]
    assert order == ["vis", "old", "https://news.example.com/"]


def test_fmt_time():
    assert fmt_time(192.4) == "3:12" and fmt_time(3725) == "1:02:05"


async def test_prefers_the_playing_video_and_pauses_it(monkeypatch):
    tabs = (f"1{SEP}1{SEP}true{SEP}https://www.youtube.com/watch?v=paused{SEP}Paused - YouTube\n"
            f"1{SEP}2{SEP}false{SEP}https://www.youtube.com/watch?v=live{SEP}Playing one - YouTube")
    calls = []

    async def fake_osascript(script, timeout=5):
        calls.append(script)
        if "repeat with w in windows" in script:
            return 0, tabs
        return 0, '{"t":12.5,"p":true}' if "tab 1 of" in script else '{"t":200.2,"p":false}'

    monkeypatch.setattr(bt, "osascript", fake_osascript)
    monkeypatch.setattr(bt, "running_browsers", lambda: ["Google Chrome"])
    r = await bt.find_for_phone()
    assert r == {"open_url": "https://www.youtube.com/watch?v=live&t=200s", "title": "Playing one",
                 "position_s": 200.2}


async def test_javascript_turned_off_still_opens_with_a_hint(monkeypatch):
    async def fake_osascript(script, timeout=5):
        if "repeat with w in windows" in script:
            return 0, f"1{SEP}1{SEP}true{SEP}https://www.youtube.com/watch?v=a{SEP}A - YouTube"
        return 1, "execution error: Executing JavaScript through AppleScript is turned off."

    monkeypatch.setattr(bt, "osascript", fake_osascript)
    monkeypatch.setattr(bt, "running_browsers", lambda: ["Google Chrome"])
    r = await bt.find_for_phone()
    assert r["open_url"] == "https://www.youtube.com/watch?v=a" and "Allow JavaScript" in r["hint"]


async def test_no_browser_is_a_clear_message(monkeypatch):
    monkeypatch.setattr(bt, "running_browsers", lambda: [])
    with pytest.raises(LookupError):
        await bt.find_for_phone()
