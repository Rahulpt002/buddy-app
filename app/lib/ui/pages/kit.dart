// Shared page kit: typed topic access, navigation, actions, toasts and small derived
// values. Every skin's pages build on these so behaviour is identical across themes.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/conn/controller.dart';
import '../../core/data/topics.dart';
import '../../core/pages.dart';
import '../../core/proto/models.dart';
import '../../core/settings.dart';
import '../fmt.dart';
import '../icons.dart';
import '../skin.dart';
import '../widgets/common.dart';

export '../../core/data/calendar.dart';
export '../../core/data/weather.dart';
export '../../core/proto/models.dart';
export '../../core/timer.dart';

/// Typed topic data, or null when missing / not ok.
T? topicData<T extends TopicData>(WidgetRef ref, String topic) {
  final d = ref.watch(topicProvider(topic))?.data;
  return d is T ? d : null;
}

/// Lets pages open other pages (Home cards) without knowing about the shell.
class PageNav extends InheritedWidget {
  const PageNav({super.key, required this.open, required super.child});
  final ValueChanged<PageId> open;
  static void go(BuildContext c, PageId p) => c.getInheritedWidgetOfExactType<PageNav>()?.open(p);
  @override
  bool updateShouldNotify(PageNav old) => false;
}

/// Sends an action to the agent; shows a toast on failure (and [ok] on success).
Future<ActionResult> act(BuildContext context, WidgetRef ref, String action,
    [Map<String, dynamic> params = const {}, String? ok,
    void Function(Map<String, dynamic>)? onProgress, Duration timeout = const Duration(seconds: 10)]) async {
  final r = await ref.read(agentProvider.notifier).request(action, params, onProgress, timeout);
  if (!context.mounted) return r;
  if (!r.ok) {
    toast(context, r.code == 'disconnected' ? 'Connect your laptop first' : (r.message ?? 'That didn\'t work'));
  } else if (ok != null) {
    toast(context, ok);
  } else if (action == 'shortcut.run' && r.result['message'] is String) {
    toast(context, r.result['message'] as String); // e.g. "Microphone muted", "Saved DeskPanel … .png"
  }
  return r;
}

// ------------------------------------------------------------------ toast

OverlayEntry? _toast;
Timer? _toastTimer;

/// Small transient message, styled per skin (concept `.toast`).
void toast(BuildContext context, String msg) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  final skin = context.skin;
  _toast?.remove();
  _toastTimer?.cancel();
  final ts = toastStyleOf(skin);
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      left: 0,
      right: 0,
      bottom: ts.bottom,
      child: IgnorePointer(
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 220),
            builder: (context, v, child) =>
                Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 8 * (1 - v)), child: child)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: ts.bg,
                borderRadius: BorderRadius.circular(ts.radius),
                boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 30, offset: Offset(0, 10))],
              ),
              child: Text(msg,
                  style: TextStyle(
                      fontFamily: ts.font,
                      fontSize: ts.size,
                      fontWeight: FontWeight.w600,
                      color: ts.fg,
                      decoration: TextDecoration.none)),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  _toast = entry;
  _toastTimer = Timer(const Duration(milliseconds: 2200), () {
    if (_toast == entry) {
      entry.remove();
      _toast = null;
    }
  });
}

// ------------------------------------------------------------------ derived values

/// green < 50% ≤ amber < 80% ≤ red (Claude limits).
Color usageColor(double pct, SkinTokens t) => pct < 50 ? t.ok : (pct < 80 ? t.warn : t.bad);

/// "Resets in 2h 12m" / "Reset" once passed.
String resetsIn(LimitWindow? w, DateTime now) {
  if (w == null || w.resetsAt == null) return 'No data yet';
  if (w.isExpired(now)) return 'Window has reset';
  return 'Resets in ${dur(w.resetsAt!.difference(now))}';
}

/// "Resets Sat 2:01 PM"
String resetsAt(LimitWindow? w, DateTime now, {bool h24 = false}) {
  if (w == null || w.resetsAt == null) return 'No data yet';
  if (w.isExpired(now)) return 'Window has reset';
  final r = w.resetsAt!.toLocal();
  final sameDay = r.year == now.year && r.month == now.month && r.day == now.day;
  return 'Resets ${sameDay ? 'today' : weekday3(r)} ${clockFull(r, h24: h24)}';
}

/// Used % for display; expired windows count as 0.
double limitPct(LimitWindow? w, DateTime now) => w == null || w.isExpired(now) ? 0 : w.usedPct;

/// Short weekday labels for the 7-day chart, "Today" last.
String dayLabel(DateTime d, DateTime now) =>
    d.year == now.year && d.month == now.month && d.day == now.day ? 'Today' : weekday3(d);

/// Bubble text for a tapped 7-day bar: "Fri · 55.3M tokens".
String dayTokensLabel(ClaudeDay d, DateTime now) => '${dayLabel(d.date, now)} · ${compact(d.tokens)} tokens';

String modelName(String family) => family.isEmpty ? family : family[0].toUpperCase() + family.substring(1);

/// Hours like the screenshots: "41 h", "5.0 h".
String hours(double h) => h >= 10 ? '${h.round()} h' : '${h.toStringAsFixed(1)} h';

/// Shortcut tile label reflecting state ("Mute mic" -> "Mic muted").
String tileLabel(Tile t) => switch ((t.id, t.active)) {
      ('mic.toggle', true) => 'Mic muted',
      ('sound.toggle', true) => 'Sound muted',
      _ => t.label,
    };

String tileIcon(Tile t) => switch ((t.id, t.active)) {
      ('mic.toggle', true) => 'micOff',
      ('sound.toggle', true) => 'speakerOff',
      _ => t.icon,
    };

/// Tiles in the user's saved order.
List<Tile> orderedTiles(List<Tile> tiles, List<String> order) {
  final idx = {for (final (i, id) in order.indexed) id: i};
  return [...tiles]..sort((a, b) => (idx[a.id] ?? 999).compareTo(idx[b.id] ?? 999));
}

/// Max of the non-null values (≥ [floor]).
double maxOf(Iterable<num?> xs, {double floor = 1}) {
  var m = floor;
  for (final x in xs) {
    if (x != null && x > m) m = x.toDouble();
  }
  return m;
}

/// System page tab (0 = PC, 1 = Internet); survives page switches.
class SystemTab extends Notifier<int> {
  SystemTab([this.initial = 0]);
  final int initial;
  @override
  int build() => initial;
  void set(int v) => state = v;
}

final systemTabProvider = NotifierProvider<SystemTab, int>(SystemTab.new);

/// The skin's toast look (also used for chart tap bubbles).
ToastStyle toastStyleOf(Skin skin) {
  final t = skin.tokens;
  return switch (skin.id) {
    SkinId.slate => ToastStyle(bg: const Color(0xFFF1F3F5), fg: const Color(0xFF0D1014), font: t.body),
    SkinId.glow => ToastStyle(bg: const Color(0x33F4EFE6), fg: t.text, font: t.body, bottom: 56),
    SkinId.panel => ToastStyle(bg: const Color(0xFF111315), fg: const Color(0xFFFFB21E), font: t.display, radius: 8, size: 15),
    _ => skin.toastStyle,
  };
}

/// Code-hosting source shown on the GitHub page: 0 = GitHub, 1 = GitLab. Remembered.
class CodeSource extends Notifier<int> {
  CodeSource([this.initial]);
  final int? initial;
  static const _key = 'code.source';
  @override
  int build() => initial ?? ref.read(prefsProvider).getInt(_key) ?? 0;
  void set(int v) {
    state = v;
    ref.read(prefsProvider).setInt(_key, v);
  }
}

final codeSourceProvider = NotifierProvider<CodeSource, int>(CodeSource.new);

/// Labels for the GitHub | GitLab switch.
const codeSources = ['GitHub', 'GitLab'];

/// Topic for the selected source ('github' / 'gitlab').
String codeTopic(WidgetRef ref) => ref.watch(codeSourceProvider) == 1 ? 'gitlab' : 'github';

/// "Top repos" on GitHub, "Top projects" on GitLab.
String topReposLabel(WidgetRef ref) => ref.watch(codeSourceProvider) == 1 ? 'Top projects' : 'Top repos';

// ------------------------------------------------------------------ slack

/// Compact message time: "now", "4m", "2h", "Yesterday", "Mon", "Nov 3".
String slackTime(DateTime ts, DateTime now) {
  final d = now.difference(ts);
  if (d.inMinutes < 1) return 'now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(ts.year, ts.month, ts.day);
  if (day == today) return '${d.inHours}h';
  final days = today.difference(day).inDays;
  if (days == 1) return 'Yesterday';
  if (days < 7) return const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][ts.weekday - 1];
  return '${month3(ts)} ${ts.day}';
}

/// One line of context: "DM", "#deploys", "#deploys · thread", "Priya, Leo".
String slackWhere(SlackMsg m) => m.thread ? '${m.where} · thread' : m.where;

/// Tap on a message: opens that conversation in Slack on the laptop (and marks it read).
Future<void> slackOpen(BuildContext context, WidgetRef ref, SlackMsg m) =>
    act(context, ref, 'slack.open', {'channel_id': m.channelId}, 'Opened in Slack on your laptop');

/// Mark one message read without opening Slack.
Future<ActionResult> slackMarkRead(BuildContext context, WidgetRef ref, SlackMsg m) =>
    act(context, ref, 'slack.read', {'id': m.id});

/// Per-message "mark read" for a Slack row: a small ring with a tick inside a 40 px touch
/// target. Tapping it fills the ring straight away, then the agent marks the message read
/// (the row dims when the update arrives). Read messages get an empty space of the same
/// width so the rows stay lined up.
class SlackReadTick extends ConsumerStatefulWidget {
  const SlackReadTick(this.m, {super.key, this.color, this.fill, this.onFill, this.size = 26, this.radius, this.hit = 40});
  final SlackMsg m;

  /// Ring / tick colour (default: the theme's muted text). [fill] is the "done" fill and
  /// [onFill] the tick drawn on it (default: the theme background).
  final Color? color, fill, onFill;
  final double size, hit;

  /// Corner radius; null = circle.
  final double? radius;

  @override
  ConsumerState<SlackReadTick> createState() => _SlackReadTickState();
}

class _SlackReadTickState extends ConsumerState<SlackReadTick> {
  bool _done = false;

  @override
  void didUpdateWidget(SlackReadTick old) {
    super.didUpdateWidget(old);
    if (old.m.id != widget.m.id) _done = false;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.m.unread) return SizedBox(width: widget.hit);
    final t = context.tk;
    final c = widget.color ?? t.muted;
    final fill = widget.fill ?? t.ok;
    final s = widget.size;
    final shape = widget.radius == null ? BoxShape.circle : BoxShape.rectangle;
    final br = widget.radius == null ? null : BorderRadius.circular(widget.radius!);
    return Semantics(
      button: true,
      label: 'Mark read',
      child: Press(
        scale: .9,
        onTap: _done
            ? null
            : () {
                setState(() => _done = true);
                slackMarkRead(context, ref, widget.m).then((r) {
                  if (!r.ok && mounted) setState(() => _done = false);
                });
              },
        child: SizedBox(
          width: widget.hit,
          height: widget.hit,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: s,
              height: s,
              decoration: BoxDecoration(
                shape: shape,
                borderRadius: br,
                color: _done ? fill : null,
                border: Border.all(color: _done ? fill : c.withValues(alpha: .7), width: 1.5),
              ),
              alignment: Alignment.center,
              child: DpIcon('check', size: s * .62, stroke: 2.4, color: _done ? (widget.onFill ?? t.bg) : c),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Mark all read".
Future<void> slackReadAll(BuildContext context, WidgetRef ref) =>
    act(context, ref, 'slack.read', {'all': true}, 'All caught up');

/// Home-card summary: "3 unread" / "All caught up".
String slackSummary(SlackData s) => s.unread == 0 ? 'All caught up' : '${s.unread} unread';

/// What a Home card / row / line shows for Slack, so every theme says the same thing.
/// Prefer [slackHome] (it also sees "not set up", which `topicData<SlackData>` hides).
///   headline: "3 unread" | "All caught up" | "Slack"
///   detail:   "Maya Chen: Are you free…" | "No new messages" | "Last from Sam Okafor" | "Not set up" | "—"
///   latest:   the newest unread message, if any.
({String headline, String detail, SlackMsg? latest, int unread}) slackHome(WidgetRef ref) =>
    slackHomeInfo(ref.watch(topicProvider('slack'))?.data);

({String headline, String detail, SlackMsg? latest, int unread}) slackHomeInfo(TopicData? d) {
  if (d is! SlackData) {
    final setup = d?.status == TopicStatus.unconfigured;
    return (headline: 'Slack', detail: setup ? 'Not set up' : '—', latest: null, unread: 0);
  }
  final s = d;
  final u = s.unreadMessages;
  if (u.isEmpty) {
    return (
      headline: 'All caught up',
      detail: s.messages.isEmpty ? 'No new messages' : 'Last from ${s.messages.first.sender}',
      latest: null,
      unread: 0,
    );
  }
  final m = u.first;
  return (headline: '${u.length} unread', detail: '${m.sender}: ${m.text}', latest: m, unread: u.length);
}

// ------------------------------------------------------------------ hotspot
// The Hotspot Monitor Overview, worded and formatted the same in every theme (and the
// same as the Hotspot Monitor Dashboard: decimal units, its grade names).

String _trim(double v, int digits) {
  final s = v.toStringAsFixed(digits);
  return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
}

/// Bits/s -> ("18.4", "Mbps"); "—" when unknown.
(String, String) hsBpsParts(double? bps) {
  if (bps == null) return ('—', 'Mbps');
  const u = ['bps', 'kbps', 'Mbps', 'Gbps'];
  var v = bps < 0 ? 0.0 : bps;
  var i = 0;
  while (v >= 1000 && i < u.length - 1) {
    v /= 1000;
    i++;
  }
  return (i == 0 ? '${v.round()}' : (v >= 100 ? '${v.round()}' : _trim(v, 1)), u[i]);
}

/// "18.4 Mbps"
String hsBps(double? bps) {
  final (v, u) = hsBpsParts(bps);
  return bps == null ? '—' : '$v $u';
}

/// Decimal bytes -> ("148.6", "GB").
(String, String) hsBytesParts(double? b) {
  if (b == null) return ('—', 'GB');
  const u = ['B', 'KB', 'MB', 'GB', 'TB'];
  var v = b;
  var i = 0;
  while (v >= 1000 && i < u.length - 1) {
    v /= 1000;
    i++;
  }
  return (i == 0 ? '${v.round()}' : (v >= 100 ? '${v.round()}' : _trim(v, 1)), u[i]);
}

/// "148.6 GB"
String hsBytes(double? b) {
  final (v, u) = hsBytesParts(b);
  return b == null ? '—' : '$v $u';
}

/// "37.5 °C" (Celsius, like the rest of DeskPanel unless °F is chosen).
String hsTemp(double? c, {bool fahrenheit = false}) {
  if (c == null) return '—';
  final v = fahrenheit ? c * 9 / 5 + 32 : c;
  return '${_trim(v, 1)} °${fahrenheit ? 'F' : 'C'}';
}

/// "+120 mA" / "-180 mA"
String hsCurrent(double? ma) => ma == null ? '—' : '${ma > 0 ? '+' : ''}${ma.round()} mA';

/// "4d 7h" from seconds.
String hsUptime(double? s) => s == null ? '—' : durLong(Duration(seconds: s.round()));

/// "Excellent" / "Good" / "Fair" / "Poor"
String hsGradeLabel(HotspotGrade? g) => switch (g) {
      HotspotGrade.excellent => 'Excellent',
      HotspotGrade.good => 'Good',
      HotspotGrade.fair => 'Fair',
      HotspotGrade.poor => 'Poor',
      null => '—',
    };

/// Grade colour from the theme's own status tokens (excellent/good = ok, fair = warn, poor = bad).
Color hsGradeColor(HotspotGrade? g, SkinTokens t) => switch (g) {
      HotspotGrade.excellent || HotspotGrade.good => t.ok,
      HotspotGrade.fair => t.warn,
      HotspotGrade.poor => t.bad,
      null => t.muted,
    };

/// Overall state, worst first: phone offline > internet down > heat > low battery > online.
enum HsState { offline, internetDown, hot, lowBattery, ok }

HsState hsState(HotspotData d) {
  if (!d.online) return HsState.offline;
  if (d.internet == false) return HsState.internetDown;
  if (d.heat == HotspotHeat.hot || d.radioResting) return HsState.hot;
  if (d.lowBattery) return HsState.lowBattery;
  return HsState.ok;
}

/// One-line status: "Online", "Offline", "Internet down", "Too hot", "Battery low".
String hsStateLabel(HotspotData d) => switch (hsState(d)) {
      HsState.offline => 'Offline',
      HsState.internetDown => 'Internet down',
      HsState.hot => d.radioResting ? 'Radio resting (heat)' : 'Too hot',
      HsState.lowBattery => 'Battery low',
      HsState.ok => 'Online',
    };

Color hsStateColor(HotspotData d, SkinTokens t) => switch (hsState(d)) {
      HsState.offline || HsState.internetDown || HsState.hot => t.bad,
      HsState.lowBattery => t.warn,
      HsState.ok => t.ok,
    };

/// The banner the Dashboard shows above the cards, or null when all is well.
/// "Internet down on the phone since 4m ago. The watchdog recovers it by itself."
String? hsAlert(HotspotData d, DateTime now) {
  if (!d.online) {
    return 'The phone isn\'t connected to the Server${d.lastSeen == null ? '' : ' (last seen ${ago(now.difference(d.lastSeen!))})'}.';
  }
  if (d.internet == false) {
    final since = d.downSince == null ? '' : ' since ${ago(now.difference(d.downSince!))}';
    return 'Internet down on the phone$since. The watchdog recovers it by itself.';
  }
  if (d.radioResting) return 'The radio is resting to cool down.';
  if (d.heat == HotspotHeat.hot) return 'Battery at ${hsTemp(d.batteryC)}: charging stopped to cool down.';
  return null;
}

/// "5G NSA · B40 + n78"
String hsNetwork(HotspotData d) => [d.netType, d.band].whereType<String>().join(' · ').ifEmpty('—');

/// "RSRP -86 dBm · SINR 14.5 dB · RSRQ -11 dB"
String hsSignalLine(HotspotData d) => 'RSRP ${d.rsrp == null ? '—' : _trim(d.rsrp!, 0)} dBm · '
    'SINR ${d.sinr == null ? '—' : _trim(d.sinr!, 1)} dB · RSRQ ${d.rsrq == null ? '—' : _trim(d.rsrq!, 0)} dB';

/// "Ping 34 ms · loss 0% · jitter 4.2 ms"
String hsPingLine(HotspotData d) => 'Ping ${d.pingMs == null ? '—' : '${d.pingMs!.round()} ms'} · '
    'loss ${d.lossPct == null ? '—' : '${_trim(d.lossPct!, 1)}%'} · '
    'jitter ${d.jitterMs == null ? '—' : '${_trim(d.jitterMs!, 1)} ms'}';

/// "discharging · plug usb · limit 80%"
String hsPowerLine(HotspotData d) =>
    [d.chargeStatus ?? '—', 'plug ${d.plug ?? '—'}', if (d.chargeNote != null) d.chargeNote!].join(' · ');

/// "CPU 44 °C · modem 41.5 °C · thermal Light"
String hsHeatLine(HotspotData d, {bool fahrenheit = false}) =>
    'CPU ${hsTemp(d.cpuC, fahrenheit: fahrenheit)} · modem ${hsTemp(d.modemC, fahrenheit: fahrenheit)} · '
    'thermal ${d.thermal ?? '—'}';

/// "148.6 GB of 300 GB" / "148.6 GB used (no quota)"
String hsDataLine(HotspotData d) =>
    d.quota == null ? '${hsBytes(d.cycleUsed)} used (no quota)' : '${hsBytes(d.cycleUsed)} of ${hsBytes(d.quota)}';

/// "Today 6.2 GB · cycle started Nov 5"
String hsTodayLine(HotspotData d) => 'Today ${hsBytes(d.todayUsed)}'
    '${d.cycleStart == null ? '' : ' · cycle started ${month3(d.cycleStart!)} ${d.cycleStart!.day}'}';

/// "Sharing to 1 device" / "Sharing off"
String hsSharing(HotspotData d) => switch (d.tetherOn) {
      true => d.clients == null ? 'Sharing on' : 'Sharing to ${d.clients} device${d.clients == 1 ? '' : 's'}',
      false => 'Sharing off',
      null => 'Sharing —',
    };

/// "Boot #214 · watchdog"
String hsBootLine(HotspotData d) => 'Boot #${d.bootCount ?? '—'} · ${d.bootReason ?? 'reason unknown'}';

/// "Seen 12s ago" style for the header; "just now" under a minute.
String hsSeen(HotspotData d, DateTime now) =>
    d.lastSeen == null ? 'Never seen' : 'Seen ${ago(now.difference(d.lastSeen!))}';

/// Event severity colour.
Color hsEventColor(HotspotEvent e, SkinTokens t) => switch (e.severity) {
      'critical' => t.bad,
      'warning' => t.warn,
      _ => t.muted,
    };

/// DeskPanel's sign-in to the Server ends within 5 days: "Sign-in ends in 3 days".
String? hsSessionNote(HotspotData d, DateTime now) {
  final e = d.sessionExpires;
  if (e == null) return null;
  final left = e.difference(now);
  if (left > const Duration(days: 5)) return null;
  if (left.isNegative) return 'Sign-in expired: run deskpanel-agent hotspot-login';
  return 'Sign-in ends in ${left.inDays <= 1 ? '1 day' : '${left.inDays} days'}';
}

/// Home-card / summary: (headline, detail, color-state).
/// "Online" / "5G NSA · 18.4 Mbps"; "Not set up" when the agent isn't signed in.
({String headline, String detail, HsState? state}) hotspotHome(WidgetRef ref) {
  final d = ref.watch(topicProvider('hotspot'))?.data;
  if (d is HotspotData) {
    return (headline: hsStateLabel(d), detail: '${d.netType ?? '—'} · ${hsBps(d.rxBps)}', state: hsState(d));
  }
  final st = d?.status;
  return (
    headline: 'Hotspot',
    detail: st == TopicStatus.unconfigured ? 'Not set up' : st == TopicStatus.error ? 'Sign in again' : '—',
    state: null,
  );
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
