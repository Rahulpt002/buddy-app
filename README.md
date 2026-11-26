# DeskPanel

An always-on desk dashboard: an Android phone in landscape showing live data from your Mac
(system stats, Claude Code usage, music, the roof hotspot phone, GitHub, Slack…) plus shortcut keys that
control the Mac. The phone connects over a USB cable **or** Wi‑Fi and uses whichever is
available, preferring the cable.

```
agent/   Python service that runs on the Mac (FastAPI WebSocket, collectors, actions)
app/     Flutter app for the phone (Android first; iOS stays buildable)
shared/  protocol.md (message schema) and fixtures/ (one sample payload per topic)
screens sample/   design references: original screenshots + the theme concepts
```

Thirteen switchable themes (**Settings → Theme**), each a full design with its own navigation
and page layouts: **Slate** (rounded cards, icon rail; matches the reference screenshots),
**Glow**, **Panel**, **Ink**, **Mosaic**, **Cockpit**, **Blueprint**, **Terminal**, **Departures**,
**Expressive**, **Sketch**, **Diorama** and **Liquid** (Liquid Glass over a living wallpaper, with
a Clear / Tinted switch in its top bar) (concepts in `screens sample/`).

> Status: all 7 build steps done. Every page reads real data from the Mac or the phone;
> GitHub, Slack and Hotspot show a setup message until they're set up (section 8).
> The Printer page was replaced by Hotspot (the Bambu collector code is kept but not used). Every page also runs on
> mock data (`deskpanel-agent run --mock`) or the app's built-in demo mode.

---

## 1. Install the agent (macOS)

Requires Python 3.11+ (`brew install python@3.11`).

```sh
cd agent
python3.11 -m venv .venv
.venv/bin/pip install -e ".[dev]"
.venv/bin/deskpanel-agent run --mock     # fake data for every page, no accounts needed
```

On first run the agent creates `~/.deskpanel/`:

| File | Purpose |
|---|---|
| `config.toml` | settings and API keys (a commented template is written for you) |
| `pairing.json` | agent id + pairing token (mode 600) |
| `tls_cert.pem`, `tls_key.pem` | self-signed certificate; the phone pins its fingerprint |

Flags: `--mock`, `--port 8765`, `--qr` (print the pairing QR at start), `--no-tls` (debug only), `-v`.

### What the agent reads on macOS (no sudo)

| Page | Source |
|---|---|
| System | `psutil` (CPU, RAM, network throughput), `ioreg` IOAccelerator stats (Apple GPU load and GPU memory; memory is unified, so the gauge reads "GPU MEM"), the Data volume for disk %. CPU/GPU temperatures need private SMC APIs and are not shown. |
| Internet | Latency = TCP connect time to 1.1.1.1:443 every second (no root needed), jitter/loss over the last minute, uptime/last drop kept across agent restarts, data used per day in `~/.deskpanel/deskpanel.db`. **Run test** measures against speed.cloudflare.com (ping, 4 parallel downloads, uploads measured from the interface counters). |
| Music | AppleScript to **Spotify** and **Apple Music** (whichever is playing). Album art is sent once per track. |
| Shortcuts | AppleScript volume/mic, `screencapture`, `open`, `pmset displaysleepnow` (locks when "Require password immediately" is on). Custom tiles: `[[shortcuts.custom]]` in config, run without a shell. |

**Claude page.** Usage (tokens, messages, 7 days, models) is read from Claude Code's local
history in `~/.claude/projects`, so VS Code and terminal chats both count. Plan limits come from
two places, merged into `~/.deskpanel/claude_limits.json`:
- the status line (`deskpanel-agent install-statusline`, undo with `uninstall-statusline`): both
  windows, whenever a *terminal* Claude Code session replies;
- automatic checks: after you've used Claude (at most every 5 min; every 30 min when idle) the
  agent runs Claude Code's built-in `/usage` headlessly. It's answered locally (0 tokens) and
  reports both the 5-hour ("current session") and weekly %. If its wording ever changes, it falls
  back to one tiny Haiku request (no tools, no transcript, your user hooks skipped) and reads the
  `rate_limit_event`. Turn off with `[claude] limit_pings = false`.

**macOS permissions** — the first time, macOS asks to allow your terminal (or Python) to:
- control **Spotify** / **Music** (Automation): needed for the Music page;
- record the screen (**Screen Recording**): needed only for the Screenshot tile.

If you denied a prompt: System Settings → Privacy & Security → Automation / Screen Recording.

## 2. Pair the phone

```sh
.venv/bin/deskpanel-agent pair          # prints the QR in the terminal, saves ~/.deskpanel/pair.png
.venv/bin/deskpanel-agent pair --open   # also opens the PNG in Preview
.venv/bin/deskpanel-agent pair --reset  # rotate the token; every phone must scan again
```

In the app, tap **Scan QR code** (or tap the connection icon → Settings → Re-pair). The QR holds
the Mac's LAN addresses, port, a random 256-bit token and the certificate fingerprint. The token
is stored in Android's Keystore-backed secure storage. The agent rejects any connection without
it, and the app only trusts the exact certificate it scanned, so nothing on your network can
read or impersonate the link.

## 3. USB connection (recommended)

The cable path uses `adb reverse`, so the phone reaches the agent at `127.0.0.1:8765` without
Wi‑Fi. The agent watches `adb devices` and applies the reverse automatically whenever the phone
is plugged in. You need:

1. **Android platform-tools** on the Mac (`brew install --cask android-platform-tools`, or the
   Android SDK). The agent also looks in `~/Library/Android/sdk/platform-tools`.
2. **USB debugging** on the phone: Settings → About phone → tap *Build number* 7 times →
   back to Settings → System → Developer options → enable **USB debugging**.
3. Plug in and accept the **Allow USB debugging?** prompt on the phone (tick *Always allow*).

The agent logs `USB: phone … connected (adb reverse tcp:8765)` when it's ready. While the app is
on Wi‑Fi it checks for the cable every 5 s and switches over without a gap.

*USB tethering* also works as a fallback: it shows up as a normal network and uses the Wi‑Fi path.

## 4. Wi‑Fi connection

Both devices on the same network. The agent advertises `_deskpanel._tcp` over mDNS and the app
finds it automatically. If your network blocks mDNS, set the Mac's IP in **Settings → Manual IP**.
The app tries, in order: USB → last working Wi‑Fi address → mDNS → addresses from the QR →
manual IP, with backoff 1 s → 2 s → 4 s … 15 s between rounds.

## 5. Build and run the app

```sh
brew install --cask flutter
cd app
flutter pub get
flutter run                  # with the phone plugged in
flutter test                 # unit tests (connection fallback, protocol models, pairing)
tool/deploy.sh               # build + install over USB or Wi-Fi (wireless debugging)
```

`tool/deploy.sh` uses the phone on USB if plugged in, otherwise finds it over Wi-Fi when
**Developer options → Wireless debugging** is on (same network as the Mac). It installs, and
launches only if the phone isn't in a call or locked. The agent ignores wireless-debugging
connections, so the app keeps talking to it directly over Wi-Fi rather than through adb.

No laptop handy? **Settings → Demo mode** (or *Try demo* on the pairing screen) runs the whole
app on built-in sample data.

## 6. Screenshots of every page

```sh
cd app
SCREENS=1 flutter test test/screens_test.dart                 # all themes × pages
SCREENS=1 ONLY=glow PAGE=music flutter test test/screens_test.dart
```

Renders each page at the design size (915×412, 2x) with the shared fixtures to
`app/build/screens/<theme>-<page>.png`, so layouts can be checked without a phone.

## 7. Tests

```sh
cd agent && .venv/bin/pytest            # handshake/auth, hub, adb parsing, fixture schema
cd app && flutter test
```

`shared/fixtures/*.json` are generated from the agent's models
(`cd agent && .venv/bin/python -m tests.gen_fixtures`, then `app/tool/sync_fixtures.sh`) and
parsed by both test suites, so the Python and Dart models can't drift apart.

## 8. Integrations (optional)

Each one is optional: until it's set up, its page shows a short "how to set this up" message.
All keys go in `~/.deskpanel/config.toml` on the Mac (never on the phone). Restart the agent after
editing (Remote Trackpad menu → **Restart DeskPanel Agent**).

### Claude
Nothing to configure. Usage comes from Claude Code's local history; both plan limits come from
Claude Code's own `/usage`, checked automatically (see "What the agent reads" above). Optional:
`deskpanel-agent install-statusline` also captures limits whenever a terminal session replies.
On the phone, **tap a bar** in the 7-day chart to see that day's token count.

### GitHub
1. github.com → Settings → Developer settings → Personal access tokens → **Tokens (classic)** →
   Generate new token. Tick **`read:user`** (and **`repo`** to include private repos in Top repos).
2. For the private-contributions count, turn on **Private contributions** in your profile's
   Contribution settings.
3. Add it and restart the agent:
   ```toml
   [github]
   token = "ghp_..."
   ```
Refreshed every 15 minutes; the last result is cached so the page fills instantly at startup.

### GitLab (switch on the GitHub page)
The GitHub page has a **GitHub | GitLab** switch; both use the same layout (heatmap, streak, this
week, top projects). GitLab data comes from GitLab's documented REST API (your contribution events
for the last year, cached locally, refreshed every 15 minutes).
1. gitlab.com → avatar → **Edit profile → Access tokens → Add new token**. Scope: **`read_api`**.
   Pick an expiry and copy the token (starts with `glpat-`).
2. ```toml
   [gitlab]
   token = "glpat-..."
   # base_url = "https://gitlab.com"   # only for a self-hosted GitLab
   ```
Counts follow GitLab's own calendar idea of a contribution (pushes, issues, merge requests,
comments, approvals); "commits" sums the commits in your pushes, "private" counts events in
private projects. Heatmap colours use GitLab's thresholds (1–9, 10–19, 20–29, 30+ per day).

### Calendar
- **Phone calendars:** allow calendar access when the app asks. Everything synced to the phone
  (Google, Samsung, Exchange…) appears, refreshed every 10 minutes.
- **Optional extra feeds on the Mac** (e.g. a Google Calendar not on the phone): Google Calendar →
  ⚙ Settings → your calendar → *Integrate calendar* → **Secret address in iCal format**:
  ```toml
  [calendar]
  ics_urls = ["https://calendar.google.com/calendar/ical/.../basic.ics"]
  ```
  Repeating events are expanded; the same event from both sources shows once. Treat the secret
  address like a password (the agent never logs it).

### Slack (Slack page)
Your DMs, group DMs and @mentions (including @here / @channel), live. A new one wakes the
phone and opens the Slack page; page rotation pauses there until you touch the screen.
Tapping a message opens that conversation in Slack on the Mac and marks it read; replying
anywhere marks that conversation read too.

1. https://api.slack.com/apps → **Create New App → From a manifest** → pick your workspace →
   paste `shared/slack-app-manifest.yaml` → **Create**. (Work workspaces may need an admin to
   approve the app.)
2. **Basic Information → App-Level Tokens → Generate Token and Scopes**: name it `socket`, add
   scope `connections:write`, **Generate**, copy the `xapp-…` token.
3. **Install App → Install to Workspace → Allow**, then copy the **User OAuth Token** (`xoxp-…`).
4. ```toml
   [slack]
   app_token = "xapp-..."
   user_token = "xoxp-..."
   ```
   Restart the agent (Remote Trackpad menu → **Restart DeskPanel Agent**).

It uses Socket Mode (the Mac connects out to Slack; no public URL or open port) and only
documented user events. Messages stay on the Mac (last 50, in `~/.deskpanel/deskpanel.db`) and
the phone; the agent never logs message text. Slack doesn't tell apps when you read something
in the Slack app itself, so items clear when you reply, tap them, or tap *Mark all read*.

### Hotspot Monitor (Hotspot page)
The Hotspot page is the Overview screen of the Hotspot Monitor project
(`~/Downloads/phone-monitor`): the roof phone's status, signal score, speed, battery, heat,
data used this cycle, uptime and latest events. The agent reads it from your Hotspot Monitor
Server's REST API every 30 s. It doesn't open the Dashboard socket, so the roof phone stays on
its slow (60 s) reporting rate and doesn't use extra mobile data for DeskPanel.

1. In the Hotspot Monitor Dashboard (as admin): **Settings → Users → add a viewer** (e.g.
   `deskpanel`), then sign in as that viewer once to set up its authenticator code. A viewer can
   read everything here but can't send commands to the phone.
2. On the Mac, sign in once (it asks for the password and the 6-digit code; only the session
   token is saved, in `~/.deskpanel/config.toml`):
   ```sh
   cd agent && .venv/bin/deskpanel-agent hotspot-login --server https://<your-server>.onrender.com
   ```
3. Restart the agent. Sessions last 30 days (`SESSION_TTL_DAYS` on the Server); the page warns
   5 days before and asks you to run `hotspot-login` again when it expires.

With more than one phone on the Server, set `device_id = "d_…"` under `[hotspot]`.

### Laptop mouse on the phone
On the phone: **Settings → Laptop mouse** → turn it on, then **Phone position → Arrange…**. Like
macOS Displays → Arrange, it draws your Mac's screens and the phone to scale: drag the phone to
where it really sits (it snaps to the nearest screen edge). Push the mouse off your screen where
the phone touches and it continues onto the phone (click = tap, drag = swipe, wheel = scroll);
move back out where it touches, or press **Esc**, to return. It only works inside DeskPanel and
the keyboard stays on the Mac. The agent needs **Accessibility** permission for the app that
runs it (System Settings → Privacy & Security → Accessibility → Remote Trackpad, or Terminal
when run by hand); the setting shows an error if it's missing.

### Watch on phone
The **Watch on phone** shortcut tile sends what's open in the Mac's browser to the phone, which
plays it itself at full quality: a YouTube video opens in the phone's YouTube app at the same
moment (and pauses on the Mac); any other page opens in the phone's browser. Works with Chrome,
Safari, Arc, Brave and Edge. The first time, macOS asks to let Remote Trackpad control the
browser (Automation). For the same moment and the pause, turn on **Allow JavaScript from Apple
Events** once (Chrome: **View → Developer**; Safari: **Develop** menu); without it the video
starts from the beginning.

## 9. Running at login

**Recommended: inside Remote Trackpad.** Remote Trackpad (`~/Downloads/trackpad mac`) already starts at
login, so it also starts and supervises the DeskPanel agent (restarting it if it crashes) and adds a
DeskPanel section to its menu: status, **Run DeskPanel Agent** on/off, **Show DeskPanel Pairing QR**,
**Restart DeskPanel Agent**, **Edit DeskPanel Settings…**, **Show DeskPanel Log**. The agent's log is
`~/.deskpanel/agent.log`. If the agent folder moves:
`defaults write com.remotetrackpad.mac deskPanelAgentDir "/new/path/agent"`.
Because the agent runs under Remote Trackpad, macOS asks once to let *Remote Trackpad* control
Spotify / Music, and Screen Recording (for the Screenshot tile) is Remote Trackpad's grant.

**Standalone alternative:** `deskpanel-agent install-startup` installs a launchd login item with
its own menu-bar icon (`uninstall-startup` removes it). Don't use both at once (same port).
