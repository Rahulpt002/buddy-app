# DeskPanel Protocol — v1

One WebSocket per client: `wss://<host>:8765/ws` (TLS with a self-signed certificate the
phone pins by SHA-256 fingerprint from the pairing QR; `ws://` only with `--no-tls` for debugging). All frames are UTF-8 JSON text.
Every frame has a `t` (type) field. Field names are `snake_case`. Times are Unix epoch
**milliseconds** (UTC) unless noted. Sizes are bytes, rates are bytes/sec, temps °C,
durations ms. The app does all unit/locale formatting.

`PROTO_VERSION = 1`. Additive changes (new optional fields, new topics/actions) do NOT
bump the version; clients must ignore unknown fields/topics. Removing or retyping a
field bumps it.

---

## 1. Handshake & auth

```
client → {"t":"hello","proto":1,"token":"<pair token>",
          "client":{"name":"Pixel 8","platform":"android","app_version":"0.1.0"}}
agent  → {"t":"welcome","proto":1,"agent_id":"a1b2c3","agent_version":"0.1.0",
          "host":"DESKTOP-01","os":"windows","server_time":1763500000000,
          "topics":["system","network","claude",...],          // topics this agent can serve
          "actions":["media.play_pause","shortcut.run",...],    // actions it accepts
          "hosts":["192.168.1.20"]}                             // current LAN IPv4s
```

- `hello` must arrive within 5 s of connect, else close `4408`.
- Bad/missing token → `{"t":"error","code":"auth_failed"}` then close `4401`.
- `proto` mismatch → `{"t":"error","code":"proto_unsupported","supported":[1]}`, close `4426`.
- Nothing else is processed before `welcome`.
- `hosts`: the app stores these on every connection (USB included) and tries them first on
  Wi-Fi, so an IP change since pairing (or wired ↔ wireless) doesn't need a re-pair.
- REST endpoints (`/api/*`) require `Authorization: Bearer <token>`; only `/api/health`
  (returns `{agent_id, proto}`) is open, used for fast reachability probes.

### Pairing QR
`deskpanel://pair?v=1&id=<agent_id>&n=<hostname>&h=<ip1>,<ip2>&p=8765&t=<token>&fp=<sha256 cert fingerprint>`

- `t`: 32 random bytes, base64url. Stored agent-side in `~/.deskpanel/pairing.json` (0600),
  compared with constant-time compare. `deskpanel-agent pair --reset` rotates it (all
  phones must re-pair).
- `fp` (if TLS enabled): the app pins this self-signed cert fingerprint; no CA trust involved.

### mDNS
Service `_deskpanel._tcp.local.`, port 8765, TXT: `id=<agent_id>`, `proto=1`, `tls=1|0`.
The app only auto-connects to an `id` it has paired with.

---

## 2. Heartbeat

`{"t":"ping","ts":...}` ↔ `{"t":"pong","ts":<echo>}` — either side may send. The app pings every
5 s and treats 10 s without any inbound frame as a dead link (catches yanked USB cables,
which don't always produce a TCP close).

---

## 3. Subscriptions

```
client → {"t":"sub","topics":["system","claude","media"]}
```
- **Replaces** the client's subscription set (idempotent; send the full set on every
  page change). The app subscribes to `HOME_TOPICS ∪ current page topics`.
- Agent immediately sends one `evt` per newly-added topic with the current snapshot, then
  pushes at the topic's cadence.
- Unknown topics are ignored (listed in an `{"t":"warn"}` frame).

```
agent → {"t":"evt","topic":"system","seq":1234,"ts":1763500000000,"data":{...}}
```
- `data` is always a **full snapshot** of the topic (payloads are small; avoids delta
  bookkeeping and makes reconnect trivial). Exception: `media.art` (see below).
- `seq` is per-topic, monotonically increasing per agent process; the app drops older seqs.

### Common topic envelope
Every topic's `data` has:
```
"status": "ok" | "unconfigured" | "error" | "unsupported" | "starting",
"message": "Add a GitHub token under [github] in ~/.deskpanel/config.toml"   // optional, user-facing
```
Pages render a setup/empty state for anything other than `ok`.

---

## 4. Topics

| Topic | Cadence | Source |
|---|---|---|
| `system` | 1 Hz | psutil, NVML |
| `network` | 1 Hz (latency), usage every 10 s, speedtest on change | TCP-connect ping, psutil, SQLite |
| `claude` | on file change, coalesced ≤ 1 / 2 s; limits re-evaluated every 30 s for expiry | statusLine bridge file, ~/.claude/projects JSONL |
| `media` | on change + every 5 s resync | OS media session |
| `media.art` | on track change only (+ once on subscribe) | OS media session |
| `hotspot` | every 30 s | Hotspot Monitor Server REST (`/api/device`, `/api/events`; settings every 10 min) |
| `slack` | on each new / edited / deleted message, and on read | Slack Socket Mode (user events) |
| `github` | every 15 min | GitHub GraphQL (cached) |
| `shortcuts` | on change (mic/sound mute, volume) + every 5 s | OS audio APIs |
| `calendar` | every 15 min | optional ICS URL (device calendar is read on the phone) |

Weather and Timer are app-only and use no topic.

Collection vs. push: some collectors always run regardless of subscribers because they
need continuous history (net counters → SQLite, latency/uptime, Claude transcript tailing,
the Slack socket). Expensive or chatty ones (GitHub, media art) start on
first subscriber and stop 60 s after the last one leaves.

### `system`
```json
{"status":"ok",
 "cpu":{"pct":30.0,"model":"Ryzen 7 7800X3D 8-Core","cores":8,"threads":16,"temp_c":null},
 "gpu":{"available":true,"pct":48.0,"temp_c":52,"model":"GeForce RTX 4070",
        "vram_used":6657199308,"vram_total":12884901888,"vram_label":"VRAM"},
 "ram":{"used":19756849561,"total":34359738368},
 "disk":{"pct":58.0},
 "net":{"down_bps":1887436,"up_bps":225280},
 "history":{"interval_ms":1000,"cpu":[...60 floats],"gpu":[...60 floats|null]}}
```
`gpu.available=false` → app shows "N/A". On Apple Silicon `vram_label` is `"GPU MEM"`: memory is
unified, so used = GPU-resident memory and total = the GPU working-set limit.

### `network`
```json
{"status":"ok",
 "latency":{"target":"1.1.1.1:443","method":"tcp","ms":17.0,"jitter_ms":2.1,"loss_pct":0.0,
            "history":{"interval_ms":1000,"ms":[...120 floats|null]}},   // null = lost
 "online":true,"online_since":1763200000000,"last_drop":1763200000000,
 "usage":{"today":3435973836,"month":442381631488},
 "speedtest":{"state":"idle"|"running","last":{"down_bps":117750000,"up_bps":4750000,
              "ping_ms":9,"at":1763490000000},
              "progress":{"phase":"download","pct":40,"down_bps":15100000,"up_bps":1800000}}}
```

### `claude`
```json
{"status":"ok",
 "limits":{"source":"statusline","updated_at":1763500000000,
   "five_hour":{"used_pct":38.0,"resets_at":1763507920000,"expired":false},
   "seven_day":{"used_pct":61.0,"resets_at":1763830860000,"expired":false}},
 "today":{"tokens":48200000,"output_tokens":182000,"messages":214,"last_hour_tokens":6100000},
 "days":[{"date":"2026-11-12","tokens":31000000}, ...7 entries, oldest first],
 "models_today":[{"family":"opus","model":"claude-opus-5-5","tokens":31000000}, ...]}
```
- `limits` or either window may be `null` (not Pro/Max, bridge not installed, never seen).
  A window whose `resets_at` has passed is sent with `expired:true` (app shows "—, reset").
- `tokens` = input + output + cache_creation + cache_read (matches what Claude Code reports).
- `messages` = unique assistant message ids (deduped; Claude Code writes one JSONL line per
  content block with the same `message.id`). Day boundaries use the laptop's local timezone.

### `media`
```json
{"status":"ok","playing":true,"source":"Spotify","title":"Midnight City Lights",
 "artist":"Synth Dreams","album":"Neon Skyline","duration_ms":241000,
 "position_ms":75000,"position_at":1763500000000,"rate":1.0,"art_id":"9f2c…",
 "can":{"play_pause":true,"next":true,"prev":true,"seek":true}}
```
App interpolates position: `position_ms + (now - position_at) * rate` while playing.
`status:"ok"` with `title:null` = nothing playing.

### `media.art`
`{"status":"ok","art_id":"9f2c…","mime":"image/jpeg","b64":"…"}` — ≤ 512 px, JPEG q80. `b64:null` → app
draws the generated fallback artwork seeded by `title`.

### `hotspot`
The Hotspot Monitor Overview for the roof phone, flattened by the agent from its Server's
`GET /api/device` (+ `/api/settings` for the quota and temperature limits, `/api/events?limit=8`).
The agent never opens the Server's Dashboard socket (that would switch the phone to its fast
telemetry rate). Times are epoch ms; null = unknown.
```json
{"status":"ok","name":"Roof phone","model":"samsung SM-M526B · Android 14",
 "online":true,"last_seen":1795946400000,"updated":1795946405000,
 "internet":true,"down_since":null,"net_type":"5G NSA","band":"B40 + n78","operator":"Jio 5G",
 "score":76,"grade":"excellent"|"good"|"fair"|"poor","rsrp":-86,"sinr":14.5,"rsrq":-11,
 "rx_bps":18400000,"tx_bps":3300000,"ping_ms":34,"loss_pct":0,"jitter_ms":4.2,
 "tether_on":true,"clients":1,
 "battery_pct":82,"current_ma":-180,"charge_status":"discharging","plug":"usb",
 "charge_note":"limit 80%","low_battery":false,
 "battery_c":37.5,"cpu_c":44,"modem_c":41.5,"thermal":"Light","heat":"ok"|"warm"|"hot","radio_resting":false,
 "cycle_used":148600000000,"quota":300000000000,"today_used":6200000000,"cycle_start":"2026-11-05",
 "uptime_s":370800,"agent_uptime_s":370760,"boot_count":214,"boot_reason":"watchdog",
 "events":[{"ts":1795946160000,"kind":"connectivity","severity":"info"|"warning"|"critical",
            "message":"Internet back after 42 s"}],
 "session_expires":1797760000000}
```
`unconfigured` until `deskpanel-agent hotspot-login` has run; `error` with a "sign in again"
message when the Server rejects the session (30-day sessions). Network errors keep the last data.

### `slack`
```json
{"status":"ok","team":"Acme","user":"you","unread":3,
 "messages":[{"id":"D01:1763500000.000100","ts":1763500000000,"channel_id":"D01","channel":"Maya Chen",
              "kind":"dm" | "group" | "mention","sender":"Maya Chen","sender_color":"#E01E5A",
              "text":"Are you free for a quick call?","thread":false,"unread":true}, ...]}
```
Newest first, at most 50, persisted by the agent. Kept: DMs, group DMs, and channel messages
that mention you (or @here / @channel). Your own message in a conversation marks it read.
The phone opens the Slack page whenever an unread message newer than any it has seen arrives.

### `github`
```json
{"status":"ok","user":"octo","fetched_at":1763500000000,
 "year":{"total":1033,"commits":120,"private":907,"issues":1,"prs":5,"reviews":0,
         "weeks":[[{"date":"2025-11-23","count":0,"level":0}, ...7], ...53]},
 "streak":{"current":5,"longest":10,"best_day":{"date":"2026-11-16","count":75}},
 "week":{"this":[0,31,25,15,19,8,0],"last":[0,11,5,4,3,2,0],"this_total":281,"delta":180},
 "top_repos":[{"name":"pixel-garden","count":222}, ...]}
```
`level` 0–4 from GitHub's `contributionLevel`. Weeks start Sunday (GitHub's grid).

### `shortcuts`
```json
{"status":"ok",
 "tiles":[{"id":"mic.toggle","label":"Mute mic","icon":"mic","color":"#E8A598",
           "state":{"active":true}}, ...],
 "volume_pct":42}
```
Tile catalog = built-ins + `[[shortcuts.custom]]` from agent config. The phone stores only
**order and visibility**; it can never define what an action does.

### `calendar`
`{"status":"ok"|"unconfigured","events":[{"id":"…","title":"…","start":…,"end":…,"all_day":false,
"location":"Zoom","calendar":"Work","color":"#4A7DFF"}]}` — merged on the phone with
device-calendar events.

---

## 5. Actions (request / response)

```
client → {"t":"req","id":"c-42","action":"media.seek","params":{"position_ms":90000}}
agent  → {"t":"res","id":"c-42","ok":true,"result":{}}
agent  → {"t":"res","id":"c-42","ok":false,"error":{"code":"unsupported","message":"…"}}
agent  → {"t":"prog","id":"c-43","data":{...}}          // optional progress before res
```
`id` is client-chosen, unique per connection. Agent answers every `req` exactly once.
Client times out after 10 s (speedtest: 90 s).

| Action | Params | Notes |
|---|---|---|
| `media.play_pause` / `media.next` / `media.prev` | – | |
| `media.seek` | `position_ms` | |
| `shortcut.run` | `id` | must be in the tile catalog; anything else → `forbidden` |
| `shortcut.run` `{id:"phone.watch"}` | – | macOS: finds the browser's video (YouTube tab that's playing, else the visible one, else the front tab), pauses it and returns `{message, open_url}`; the app opens `open_url` on the phone (YouTube links in the YouTube app at `t=`). Any action result with `open_url` is opened by the app |
| `speedtest.run` | – | streams `prog`, final `res` carries result; also updates `network` topic |
| `slack.read` | `id` \| `channel_id` \| `all: true` | marks messages read; updates the `slack` topic |
| `slack.open` | `channel_id` | opens `slack://channel?id=…` on the laptop and marks that conversation read; id validated `[A-Z0-9]+` |
| `mouse.displays` | – | macOS: `{"displays":[{"x","y","w","h","mm_w","mm_h","main","builtin"}]}`, global points + physical mm (0 if unknown), for the app's Phone position screen |
| `mouse.setup` | `on`, `rect` `[x,y,w,h]` (the phone placed in the Mac's display arrangement, global points), `w`, `h` (phone screen, logical px) | macOS: share the laptop mouse with *this* phone where `rect` touches a display (see §5.1); `failed` without Accessibility permission, `unsupported` off macOS |

Error codes: `bad_request`, `forbidden`, `unsupported`, `unconfigured`, `busy`, `failed`, `timeout`.

---

### 5.1 Laptop mouse on the phone (`ptr` frames)
The phone is placed like a small extra display (to scale: Android's ~160 logical px per inch
against the display's own mm). After `mouse.setup`, pushing the laptop cursor out of a display
where the phone's `rect` touches it (24 pt of push, only with no button held) freezes and
hides the Mac cursor and streams agent → app frames to the phone that asked:
```json
{"t":"ptr","k":"enter","x":0.0,"y":0.42}
{"t":"ptr","k":"move","x":0.31,"y":0.40}   // ≤ 120 / s, newest only
{"t":"ptr","k":"down"} {"t":"ptr","k":"up"} // left button, at the last position
{"t":"ptr","k":"scroll","dy":-36}            // px, Flutter sign (positive = content up)
{"t":"ptr","k":"leave"}
```
`x`/`y` are 0..1 of the phone's screen; movement is continuous across the seam. Moving out of
the phone where a display touches it, Esc on the Mac, the phone disconnecting, or
`mouse.setup {on:false}` (sent when the app goes to the background) all return the cursor. The keyboard always stays on the Mac. The app draws the
arrow and turns down/move/up into touch events, hover moves into mouse hover, and `scroll`
into a pointer scroll, so it works on every DeskPanel screen (not in other Android apps).

## 6. Fixtures

`shared/fixtures/<topic>.json` holds one sample payload per topic, generated from the agent's
mock provider (`cd agent && .venv/bin/python -m tests.gen_fixtures`). The agent tests validate
them against the pydantic models, and the app tests parse them into the Dart models. Run
`app/tool/sync_fixtures.sh` afterwards: demo mode bundles them.

## 7. Close codes

| Code | Meaning | App behaviour |
|---|---|---|
| 1000/1001 | normal / agent shutting down | reconnect with backoff |
| 4401 | auth failed | stop, prompt re-pair |
| 4408 | hello timeout | reconnect |
| 4400 | first frame was not a valid hello | reconnect |
| 4426 | protocol unsupported | stop, show "update app/agent" |
