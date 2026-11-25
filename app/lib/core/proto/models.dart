// Typed protocol models. Mirrors agent/deskpanel_agent/protocol.py; both sides are
// tested against shared/fixtures/*.json.
// ignore_for_file: prefer_initializing_formals

typedef Json = Map<String, dynamic>;

double? _d(Object? v) => v == null ? null : (v as num).toDouble();
int? _i(Object? v) => v == null ? null : (v as num).toInt();
List<T> _list<T>(Object? v, T Function(Json) f) =>
    v == null ? <T>[] : (v as List).map((e) => f(e as Json)).toList(growable: false);

enum TopicStatus { ok, unconfigured, error, unsupported, starting }

TopicStatus _status(Object? s) =>
    TopicStatus.values.firstWhere((e) => e.name == s, orElse: () => TopicStatus.error);

/// Fields every topic payload carries.
abstract class TopicData {
  TopicStatus get status;
  String? get message;
}

class StatusOnly implements TopicData {
  StatusOnly(Json j)
      : status = _status(j['status']),
        message = j['message'] as String?;
  @override
  final TopicStatus status;
  @override
  final String? message;
}

// ----------------------------------------------------------------- system

class Cpu {
  Cpu(Json j)
      : pct = _d(j['pct'])!,
        model = j['model'] as String,
        cores = _i(j['cores']),
        threads = _i(j['threads']),
        tempC = _d(j['temp_c']);
  final double pct;
  final String model;
  final int? cores, threads;
  final double? tempC;
}

class Gpu {
  Gpu(Json j)
      : available = j['available'] as bool,
        pct = _d(j['pct']),
        tempC = _d(j['temp_c']),
        model = j['model'] as String?,
        vramUsed = _i(j['vram_used']),
        vramTotal = _i(j['vram_total']),
        vramLabel = (j['vram_label'] as String?) ?? 'VRAM';
  final bool available;
  final double? pct, tempC;
  final String? model;
  final int? vramUsed, vramTotal;
  final String vramLabel;
}

class SystemData implements TopicData {
  SystemData(Json j)
      : status = _status(j['status']),
        message = j['message'] as String?,
        cpu = Cpu(j['cpu'] as Json),
        gpu = Gpu(j['gpu'] as Json),
        ramUsed = _i((j['ram'] as Json)['used'])!,
        ramTotal = _i((j['ram'] as Json)['total'])!,
        diskPct = _d((j['disk'] as Json)['pct'])!,
        downBps = _d((j['net'] as Json)['down_bps'])!,
        upBps = _d((j['net'] as Json)['up_bps'])!,
        cpuHistory = ((j['history'] as Json)['cpu'] as List).map((e) => _d(e)!).toList(),
        gpuHistory = ((j['history'] as Json)['gpu'] as List).map(_d).toList(),
        downHistory = (((j['history'] as Json)['down'] as List?) ?? const []).map((e) => _d(e)!).toList(),
        upHistory = (((j['history'] as Json)['up'] as List?) ?? const []).map((e) => _d(e)!).toList();
  @override
  final TopicStatus status;
  @override
  final String? message;
  final Cpu cpu;
  final Gpu gpu;
  final int ramUsed, ramTotal;
  final double diskPct, downBps, upBps;
  final List<double> cpuHistory;
  final List<double?> gpuHistory;

  /// Throughput history, bytes/sec, oldest first (may be empty with older agents).
  final List<double> downHistory, upHistory;
}

// ----------------------------------------------------------------- network

class SpeedResult {
  SpeedResult(Json j)
      : downBps = _d(j['down_bps'])!,
        upBps = _d(j['up_bps'])!,
        pingMs = _d(j['ping_ms'])!,
        at = DateTime.fromMillisecondsSinceEpoch(_i(j['at'])!);
  final double downBps, upBps, pingMs;
  final DateTime at;
}

class SpeedProgress {
  SpeedProgress(Json j)
      : phase = j['phase'] as String,
        pct = _d(j['pct'])!,
        downBps = _d(j['down_bps']),
        upBps = _d(j['up_bps']);
  final String phase;
  final double pct;
  final double? downBps, upBps;
}

class Speedtest {
  Speedtest(Json j)
      : running = j['state'] == 'running',
        last = j['last'] == null ? null : SpeedResult(j['last'] as Json),
        progress = j['progress'] == null ? null : SpeedProgress(j['progress'] as Json);
  final bool running;
  final SpeedResult? last;
  final SpeedProgress? progress;
}

class NetworkData implements TopicData {
  NetworkData(Json j)
      : status = _status(j['status']),
        message = j['message'] as String?,
        latencyTarget = (j['latency'] as Json)['target'] as String,
        latencyMs = _d((j['latency'] as Json)['ms']),
        jitterMs = _d((j['latency'] as Json)['jitter_ms']),
        lossPct = _d((j['latency'] as Json)['loss_pct'])!,
        latencyHistory =
            (((j['latency'] as Json)['history'] as Json)['ms'] as List).map(_d).toList(),
        online = j['online'] as bool,
        onlineSince = _ts(j['online_since']),
        lastDrop = _ts(j['last_drop']),
        usageToday = _i((j['usage'] as Json)['today'])!,
        usageMonth = _i((j['usage'] as Json)['month'])!,
        speedtest = Speedtest(j['speedtest'] as Json);
  @override
  final TopicStatus status;
  @override
  final String? message;
  final String latencyTarget;
  final double? latencyMs, jitterMs;
  final double lossPct;
  final List<double?> latencyHistory;
  final bool online;
  final DateTime? onlineSince, lastDrop;
  final int usageToday, usageMonth;
  final Speedtest speedtest;
}

DateTime? _ts(Object? v) => v == null ? null : DateTime.fromMillisecondsSinceEpoch(_i(v)!);

// ----------------------------------------------------------------- claude

class LimitWindow {
  LimitWindow(Json j)
      : usedPct = _d(j['used_pct'])!,
        resetsAt = _ts(j['resets_at']),
        expired = (j['expired'] as bool?) ?? false;
  final double usedPct;
  final DateTime? resetsAt;
  final bool expired;

  /// Treat as expired client-side too once resets_at passes (data may be stale).
  bool isExpired(DateTime now) => expired || (resetsAt != null && !now.isBefore(resetsAt!));
}

class ClaudeDay {
  ClaudeDay(Json j)
      : date = DateTime.parse(j['date'] as String),
        tokens = _i(j['tokens'])!;
  final DateTime date;
  final int tokens;
}

class ModelUsage {
  ModelUsage(Json j)
      : family = j['family'] as String,
        model = j['model'] as String,
        tokens = _i(j['tokens'])!;
  final String family, model;
  final int tokens;
}

class ClaudeData implements TopicData {
  ClaudeData(Json j)
      : status = _status(j['status']),
        message = j['message'] as String?,
        fiveHour = _window(j, 'five_hour'),
        sevenDay = _window(j, 'seven_day'),
        tokens = _i((j['today'] as Json)['tokens'])!,
        outputTokens = _i((j['today'] as Json)['output_tokens'])!,
        messages = _i((j['today'] as Json)['messages'])!,
        lastHourTokens = _i((j['today'] as Json)['last_hour_tokens'])!,
        days = _list(j['days'], ClaudeDay.new),
        modelsToday = _list(j['models_today'], ModelUsage.new);
  static LimitWindow? _window(Json j, String k) {
    final l = j['limits'] as Json?;
    final w = l?[k] as Json?;
    return w == null ? null : LimitWindow(w);
  }

  @override
  final TopicStatus status;
  @override
  final String? message;
  final LimitWindow? fiveHour, sevenDay;
  final int tokens, outputTokens, messages, lastHourTokens;
  final List<ClaudeDay> days;
  final List<ModelUsage> modelsToday;
}

// ----------------------------------------------------------------- media

class MediaData implements TopicData {
  MediaData(Json j)
      : status = _status(j['status']),
        message = j['message'] as String?,
        playing = (j['playing'] as bool?) ?? false,
        source = j['source'] as String?,
        title = j['title'] as String?,
        artist = j['artist'] as String?,
        album = j['album'] as String?,
        durationMs = _i(j['duration_ms']),
        positionMs = _i(j['position_ms']),
        positionAt = _ts(j['position_at']),
        rate = _d(j['rate']) ?? 1.0,
        artId = j['art_id'] as String?,
        canSeek = ((j['can'] as Json?)?['seek'] as bool?) ?? false;
  @override
  final TopicStatus status;
  @override
  final String? message;
  final bool playing;
  final String? source, title, artist, album, artId;
  final int? durationMs, positionMs;
  final DateTime? positionAt;
  final double rate;
  final bool canSeek;

  /// Interpolated playback position. [skewMs] = agent clock - phone clock.
  int positionNow(DateTime now, {int skewMs = 0}) {
    final base = positionMs ?? 0;
    if (!playing || positionAt == null) return base;
    final elapsed = now.millisecondsSinceEpoch + skewMs - positionAt!.millisecondsSinceEpoch;
    final p = base + (elapsed * rate).round();
    final d = durationMs;
    return d == null ? p : p.clamp(0, d);
  }
}

class MediaArt implements TopicData {
  MediaArt(Json j)
      : status = _status(j['status']),
        message = j['message'] as String?,
        artId = j['art_id'] as String?,
        b64 = j['b64'] as String?;
  @override
  final TopicStatus status;
  @override
  final String? message;
  final String? artId, b64;
}

// ----------------------------------------------------------------- hotspot

/// Signal grade of the roof phone (Hotspot Monitor's plan 7.1 thresholds).
enum HotspotGrade { excellent, good, fair, poor }

/// Battery temperature against the phone's own limits: warn (40 °C) / stop charging (45 °C).
enum HotspotHeat { ok, warm, hot }

class HotspotEvent {
  HotspotEvent(Json j)
      : ts = _ts(j['ts']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        kind = j['kind'] as String? ?? '',
        severity = j['severity'] as String? ?? 'info',
        message = j['message'] as String? ?? '';
  final DateTime ts;
  final String kind, message;

  /// 'info' | 'warning' | 'critical'
  final String severity;
}

/// The Hotspot Monitor Overview (the roof phone sharing mobile data), via the agent.
class HotspotData implements TopicData {
  HotspotData(Json j)
      : status = _status(j['status']),
        message = j['message'] as String?,
        name = j['name'] as String?,
        model = j['model'] as String?,
        online = (j['online'] as bool?) ?? false,
        lastSeen = _ts(j['last_seen']),
        updated = _ts(j['updated']),
        internet = j['internet'] as bool?,
        downSince = _ts(j['down_since']),
        netType = j['net_type'] as String?,
        band = j['band'] as String?,
        operator = j['operator'] as String?,
        score = _d(j['score']),
        grade = HotspotGrade.values.where((g) => g.name == j['grade']).firstOrNull,
        rsrp = _d(j['rsrp']),
        sinr = _d(j['sinr']),
        rsrq = _d(j['rsrq']),
        rxBps = _d(j['rx_bps']),
        txBps = _d(j['tx_bps']),
        pingMs = _d(j['ping_ms']),
        lossPct = _d(j['loss_pct']),
        jitterMs = _d(j['jitter_ms']),
        tetherOn = j['tether_on'] as bool?,
        clients = _i(j['clients']),
        batteryPct = _d(j['battery_pct']),
        currentMa = _d(j['current_ma']),
        chargeStatus = j['charge_status'] as String?,
        plug = j['plug'] as String?,
        chargeNote = j['charge_note'] as String?,
        lowBattery = (j['low_battery'] as bool?) ?? false,
        batteryC = _d(j['battery_c']),
        cpuC = _d(j['cpu_c']),
        modemC = _d(j['modem_c']),
        thermal = j['thermal'] as String?,
        heat = HotspotHeat.values.where((h) => h.name == j['heat']).firstOrNull ?? HotspotHeat.ok,
        radioResting = (j['radio_resting'] as bool?) ?? false,
        cycleUsed = _d(j['cycle_used']),
        quota = _d(j['quota']),
        todayUsed = _d(j['today_used']),
        cycleStart = j['cycle_start'] == null ? null : DateTime.tryParse(j['cycle_start'] as String),
        uptimeS = _d(j['uptime_s']),
        agentUptimeS = _d(j['agent_uptime_s']),
        bootCount = _i(j['boot_count']),
        bootReason = j['boot_reason'] as String?,
        events = _list(j['events'], HotspotEvent.new),
        sessionExpires = _ts(j['session_expires']);
  @override
  final TopicStatus status;
  @override
  final String? message;
  final String? name, model, netType, band, operator, chargeStatus, plug, chargeNote, thermal, bootReason;

  /// Phone connected to the Hotspot Monitor Server.
  final bool online;
  final DateTime? lastSeen, updated, downSince, cycleStart, sessionExpires;

  /// Internet working on the phone (null = unknown).
  final bool? internet, tetherOn;
  final double? score, rsrp, sinr, rsrq, rxBps, txBps, pingMs, lossPct, jitterMs;
  final HotspotGrade? grade;
  final int? clients, bootCount;

  /// Battery %, net current (+ charging, - draining), temperatures in °C.
  final double? batteryPct, currentMa, batteryC, cpuC, modemC;
  final bool lowBattery, radioResting;
  final HotspotHeat heat;

  /// Bytes. [quota] is null when no data plan quota is set.
  final double? cycleUsed, quota, todayUsed;
  final double? uptimeS, agentUptimeS;

  /// Newest first (at most 8).
  final List<HotspotEvent> events;

  /// 0..1 of the data quota used, or null without a quota.
  double? get quotaFrac => quota == null || cycleUsed == null ? null : (cycleUsed! / quota!);
}

// ----------------------------------------------------------------- slack

enum SlackKind { dm, group, mention }

class SlackMsg {
  SlackMsg(Json j)
      : id = j['id'] as String,
        ts = _ts(j['ts']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        channelId = j['channel_id'] as String,
        channel = j['channel'] as String,
        kind = SlackKind.values.firstWhere((k) => k.name == j['kind'], orElse: () => SlackKind.dm),
        sender = j['sender'] as String,
        senderColor = j['sender_color'] as String? ?? '#36C5F0',
        text = j['text'] as String? ?? '',
        thread = j['thread'] as bool? ?? false,
        unread = j['unread'] as bool? ?? true;
  final String id, channelId, channel, sender, senderColor, text;
  final DateTime ts;
  final SlackKind kind;
  final bool thread, unread;

  /// Initials for an avatar ("Maya Chen" -> "MC").
  String get initials {
    final parts = sender.split(RegExp(r'[\s._-]+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.length == 1 ? parts[0].substring(0, parts[0].length.clamp(0, 2)) : parts[0][0] + parts[1][0])
        .toUpperCase();
  }

  /// Where it came from, for one-line labels: "DM", "#deploys", "Priya, Leo".
  String get where => kind == SlackKind.dm ? 'DM' : channel;
}

class SlackData implements TopicData {
  SlackData(Json j)
      : status = _status(j['status']),
        message = j['message'] as String?,
        team = j['team'] as String?,
        user = j['user'] as String?,
        unread = _i(j['unread']) ?? 0,
        messages = _list(j['messages'], SlackMsg.new);
  @override
  final TopicStatus status;
  @override
  final String? message;
  final String? team, user;
  final int unread;

  /// Newest first.
  final List<SlackMsg> messages;
  List<SlackMsg> get unreadMessages => messages.where((m) => m.unread).toList();
}

// ----------------------------------------------------------------- github

class ContribDay {
  ContribDay(Json j)
      : date = DateTime.parse(j['date'] as String),
        count = _i(j['count'])!,
        level = _i(j['level'])!;
  final DateTime date;
  final int count, level;
}

class GithubData implements TopicData {
  GithubData(Json j)
      : status = _status(j['status']),
        message = j['message'] as String?,
        user = j['user'] as String?,
        total = _i((j['year'] as Json?)?['total']) ?? 0,
        commits = _i((j['year'] as Json?)?['commits']) ?? 0,
        private = _i((j['year'] as Json?)?['private']) ?? 0,
        issues = _i((j['year'] as Json?)?['issues']) ?? 0,
        weeks = (((j['year'] as Json?)?['weeks'] as List?) ?? const [])
            .map((w) => (w as List).map((d) => ContribDay(d as Json)).toList())
            .toList(),
        streakCurrent = _i((j['streak'] as Json?)?['current']) ?? 0,
        streakLongest = _i((j['streak'] as Json?)?['longest']) ?? 0,
        bestDay = ((j['streak'] as Json?)?['best_day'] as Json?) == null
            ? null
            : ContribDay({...((j['streak'] as Json)['best_day'] as Json), 'level': 4}),
        thisWeek = (((j['week'] as Json?)?['this'] as List?) ?? const []).map(_i).toList(),
        lastWeek = (((j['week'] as Json?)?['last'] as List?) ?? const []).map((e) => _i(e)!).toList(),
        weekTotal = _i((j['week'] as Json?)?['this_total']) ?? 0,
        weekDelta = _i((j['week'] as Json?)?['delta']) ?? 0,
        topRepos = _list(j['top_repos'], (r) => (name: r['name'] as String, count: _i(r['count'])!));
  @override
  final TopicStatus status;
  @override
  final String? message;
  final String? user;
  final int total, commits, private, issues;
  final List<List<ContribDay>> weeks;
  final int streakCurrent, streakLongest;
  final ContribDay? bestDay;
  final List<int?> thisWeek;
  final List<int> lastWeek;
  final int weekTotal, weekDelta;
  final List<({String name, int count})> topRepos;
}

// ----------------------------------------------------------------- shortcuts

class Tile {
  Tile(Json j)
      : id = j['id'] as String,
        label = j['label'] as String,
        icon = j['icon'] as String,
        color = j['color'] as String?,
        active = ((j['state'] as Json?)?['active'] as bool?) ?? false,
        detail = (j['state'] as Json?)?['detail'] as String?;
  final String id, label, icon;
  final String? color, detail;
  final bool active;
}

class ShortcutsData implements TopicData {
  ShortcutsData(Json j)
      : status = _status(j['status']),
        message = j['message'] as String?,
        tiles = _list(j['tiles'], Tile.new),
        volumePct = _i(j['volume_pct']);
  @override
  final TopicStatus status;
  @override
  final String? message;
  final List<Tile> tiles;
  final int? volumePct;
}

// ----------------------------------------------------------------- calendar

class CalEvent {
  CalEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.allDay = false,
    this.location,
    this.calendar,
    this.color,
  });
  CalEvent.fromJson(Json j)
      : id = j['id'] as String,
        title = j['title'] as String,
        start = _ts(j['start'])!,
        end = _ts(j['end'])!,
        allDay = (j['all_day'] as bool?) ?? false,
        location = j['location'] as String?,
        calendar = j['calendar'] as String?,
        color = j['color'] as String?;
  final String id, title;
  final DateTime start, end;
  final bool allDay;
  final String? location, calendar, color;
}

class CalendarData implements TopicData {
  CalendarData(Json j)
      : status = _status(j['status']),
        message = j['message'] as String?,
        events = _list(j['events'], CalEvent.fromJson);
  @override
  final TopicStatus status;
  @override
  final String? message;
  final List<CalEvent> events;
}

// ----------------------------------------------------------------- registry

/// Parses a topic payload. Non-ok payloads parse to [StatusOnly] so pages can show a
/// setup/empty state without needing every field.
TopicData parseTopic(String topic, Json j) {
  final st = _status(j['status']);
  if (st != TopicStatus.ok && topic != 'media.art') return StatusOnly(j);
  return switch (topic) {
    'system' => SystemData(j),
    'network' => NetworkData(j),
    'claude' => ClaudeData(j),
    'media' => MediaData(j),
    'media.art' => MediaArt(j),
    'hotspot' => HotspotData(j),
    'slack' => SlackData(j),
    'github' || 'gitlab' => GithubData(j), // same shape
    'shortcuts' => ShortcutsData(j),
    'calendar' => CalendarData(j),
    _ => StatusOnly(j),
  };
}

const allTopics = [
  'system', 'network', 'claude', 'media', 'media.art', 'hotspot', 'slack', 'github', 'gitlab', 'shortcuts',
  'calendar',
];
