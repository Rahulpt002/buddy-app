// Liquid (concept 16) pages: Hotspot, Timer, Slack, Controls. Shared pieces: liquid_kit.dart.
//
// Timer and Controls follow the concept's `pages.timer` / `pages.shortcuts` (Control Center
// toggles and the tall volume slider). Hotspot and Slack aren't in the concept: they're
// glass cards in the same language as Home (big rounded figures, muted labels, `.li` rows).
// No blur and no opacity layers anywhere here: the wallpaper under them moves every frame.
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings.dart';
import '../fmt.dart';
import '../icons.dart';
import '../pages/kit.dart';
import '../skin.dart';
import '../widgets/common.dart';
import 'liquid_kit.dart';

const _gap = 12.0;

/// The concept's offline banner red, rgba(229,72,77,.55), for alert strips and pills.
const _alertFill = Color(0x8CE5484D);
const _warnFill = Color(0x66FFB547);

/// The concept's Tinted glass, a shade darker: cards that need attention sit on it so their
/// red / gold figures stay legible over a warm wallpaper (Hotspot's is amber).
const _dark = Color(0x8C161826);

/// A status dot with its glow as a faint halo (like [lqDot], any colour).
Widget _dot(Color c, {double size = 10, bool halo = true}) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c,
        border: halo
            ? Border.all(color: c.withValues(alpha: .35), width: 2.5, strokeAlign: BorderSide.strokeAlignOutside)
            : null,
      ),
    );

/// A muted line pinned to the bottom of what's left, as many lines (≤ [max]) as fit.
Widget _foot(String text, {int max = 2}) => LayoutBuilder(
      builder: (context, c) {
        const size = 11.5, lh = 1.3;
        final n = math.min(max, (c.maxHeight / (size * lh * 1.02)).floor());
        if (n < 1) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.bottomLeft,
          child: Text(text, style: lqT(size, c: lqMu, h: lh), maxLines: n, overflow: TextOverflow.ellipsis),
        );
      },
    );

// ------------------------------------------------------------------ Hotspot

/// Hotspot Monitor overview (the roof phone): the signal ring tall on the left, speed /
/// battery / temperature / data in a 2×2, status and the latest events on the right. An
/// alert (or a sign-in note) runs as a red glass strip above the figures.
class LqHotspotPage extends ConsumerWidget {
  const LqHotspotPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = topicData<HotspotData>(ref, 'hotspot')!;
    final f = ref.watch(settingsProvider.select((s) => s.fahrenheit));
    final tk = context.tk;
    return Ticker(
      builder: (context, now) {
        final alert = hsAlert(d, now);
        final note = hsSessionNote(d, now);
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            flex: 59,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (alert != null || note != null) ...[_strip(alert, note), const SizedBox(height: _gap)],
              Expanded(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(flex: 85, child: _signal(d, tk)),
                  const SizedBox(width: _gap),
                  Expanded(
                    flex: 200,
                    child: lqGrid([
                      (1, [(1, _speed(d)), (1, _battery(d))]),
                      (1, [(1, _temp(d, f)), (1, _data(d))]),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
          const SizedBox(width: _gap),
          Expanded(
            flex: 31,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _status(d, now, tk),
              const SizedBox(height: _gap),
              Expanded(child: _events(d, now, tk)),
            ]),
          ),
        ]);
      },
    );
  }

  /// The Dashboard's banner (red), or the sign-in note on its own (amber).
  Widget _strip(String? alert, String? note) => SizedBox(
        height: 38,
        child: LqGlass(
          radius: 99,
          fill: alert != null ? _alertFill : _warnFill,
          shadow: false,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            _dot(lqTx, size: 8),
            const SizedBox(width: 10),
            Expanded(
              child: Text(alert ?? note!,
                  style: lqT(13.5, w: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (alert != null && note != null) ...[
              const SizedBox(width: 10),
              Flexible(
                child: Text(note, style: lqT(12, c: lqTx), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ]),
        ),
      );

  /// A small figure card: label (+ trailing), the figure, and a muted line at the bottom.
  Widget _box(String label, Widget main, String foot, {Widget? trailing, bool alarm = false}) => LqGlass(
        fill: alarm ? _dark : null,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: lqLab(label)), ?trailing]),
          const SizedBox(height: 7),
          main,
          Expanded(child: _foot(foot)),
        ]),
      );

  Widget _signal(HotspotData d, SkinTokens tk) {
    final gc = hsGradeColor(d.grade, tk);
    final lines = hsSignalLine(d).split(' · ');
    return LqGlass(
      fill: d.grade == HotspotGrade.fair || d.grade == HotspotGrade.poor ? _dark : null,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(children: [
        Align(alignment: Alignment.centerLeft, child: lqLab('Signal score')),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final side = math.min(c.maxWidth, c.maxHeight - 30).clamp(56.0, 124.0);
            return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              LqRing(
                value: (d.score ?? 0) / 100,
                size: side,
                color: gc,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(d.score == null ? '—' : '${d.score!.round()}', style: lqN(side * .29)),
                  SizedBox(height: side * .03),
                  Text('of 100', style: lqT(11, c: lqMu)),
                ]),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 21,
                child: Text(hsGradeLabel(d.grade), style: lqT(16, w: FontWeight.w700, c: gc, h: 1.25), maxLines: 1),
              ),
            ]);
          }),
        ),
        for (final l in lines)
          Text(l, style: lqT(11.5, c: lqMu, h: 1.3), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _speed(HotspotData d) {
    Widget row(String icon, double? bps) {
      final (v, u) = hsBpsParts(bps);
      return Row(children: [
        DpIcon(icon, size: 16, color: lqCyan, stroke: 2.2),
        const SizedBox(width: 8),
        Expanded(child: lqBig(v, 25, unit: u)),
      ]);
    }

    return _box(
      'Speed now',
      Column(children: [row('down', d.rxBps), const SizedBox(height: 6), row('up', d.txBps)]),
      hsPingLine(d),
    );
  }

  Widget _battery(HotspotData d) {
    final low = d.lowBattery;
    final ma = d.currentMa;
    return _box(
      'Battery',
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: lqBig(d.batteryPct == null ? '—' : '${d.batteryPct!.round()}', 32,
                unit: d.batteryPct == null ? null : '%', c: low ? lqRed : lqTx),
          ),
          Text(hsCurrent(ma),
              style: lqT(12.5,
                  w: FontWeight.w600, c: ma == null || ma == 0 ? lqMu : (ma < 0 ? lqGold : lqMint))),
        ]),
        const SizedBox(height: 9),
        LqBar(value: (d.batteryPct ?? 0) / 100, color: low ? lqRed : lqTx, height: 6),
      ]),
      hsPowerLine(d),
      alarm: low,
    );
  }

  Widget _temp(HotspotData d, bool f) {
    final c = switch (d.heat) {
      HotspotHeat.hot => lqRed,
      HotspotHeat.warm => lqGold,
      HotspotHeat.ok => lqTx,
    };
    // "37.5 °C" -> the figure with its unit small, like every other big number here.
    final t = hsTemp(d.batteryC, fahrenheit: f).split(' ');
    return _box(
      'Temperature',
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        lqBig(t.first, 32, unit: t.length > 1 ? t.last : null, c: c),
        const SizedBox(height: 6),
        SizedBox(
          height: 20,
          child: Row(children: [
            Text('Battery', style: lqT(12, c: lqMu)),
            if (d.radioResting) ...[
              const SizedBox(width: 8),
              Flexible(
                child: LqPill(
                  height: 20,
                  fontSize: 11,
                  fill: _alertFill,
                  children: const [Flexible(child: Text('Radio resting', maxLines: 1, overflow: TextOverflow.ellipsis))],
                ),
              ),
            ],
          ]),
        ),
      ]),
      hsHeatLine(d, fahrenheit: f),
      alarm: d.heat != HotspotHeat.ok || d.radioResting,
    );
  }

  Widget _data(HotspotData d) {
    final (v, u) = hsBytesParts(d.cycleUsed);
    final q = d.quotaFrac;
    final qc = q == null ? lqTx : (q >= 1 ? lqRed : (q >= .8 ? lqGold : lqTx));
    return _box(
      'Data this cycle',
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        lqBig(v, 32, unit: u),
        const SizedBox(height: 9),
        if (q != null)
          LqBar(value: q.clamp(0.0, 1.0), color: qc, height: 6)
        else
          Text('No quota set', style: lqT(12, c: lqMu)),
      ]),
      hsTodayLine(d),
      trailing: q == null ? null : Text('${(q * 100).round()}%', style: lqT(12.5, w: FontWeight.w700, c: qc)),
      alarm: q != null && q >= .8,
    );
  }

  Widget _status(HotspotData d, DateTime now, SkinTokens tk) {
    Widget kv(String k, Widget v) => Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Row(children: [
            SizedBox(width: 66, child: Text(k, style: lqT(12.5, c: lqMu, h: 1.25))),
            Expanded(child: Align(alignment: Alignment.centerRight, child: v)),
          ]),
        );
    Widget val(String s) =>
        Text(s, style: lqT(13, w: FontWeight.w600, h: 1.25), maxLines: 1, overflow: TextOverflow.ellipsis);
    return LqCard(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        // The state is the card's heading: dot, "Online" / "Internet down"…, and when seen.
        Row(children: [
          _dot(hsStateColor(d, tk)),
          const SizedBox(width: 11),
          Expanded(
            child: Text(hsStateLabel(d),
                style: lqT(22, w: FontWeight.w700, ls: -.02, h: 1.15), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Text(hsSeen(d, now), style: lqT(12, c: lqMu)),
        ]),
        const SizedBox(height: 5),
        kv('Network', val(hsNetwork(d))),
        kv('Operator', val(d.operator ?? '—')),
        kv('Sharing', val(hsSharing(d).replaceFirst('Sharing ', ''))),
        kv(
          'Uptime',
          Text.rich(
            TextSpan(children: [
              TextSpan(text: hsUptime(d.uptimeS), style: lqT(13, w: FontWeight.w600, h: 1.25)),
              TextSpan(text: '  ${hsBootLine(d)}', style: lqT(12, c: lqMu, h: 1.25)),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
    );
  }

  Widget _events(HotspotData d, DateTime now, SkinTokens tk) => LqCard(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          lqLab('Latest events'),
          const SizedBox(height: 3),
          Expanded(
            child: d.events.isEmpty
                ? Center(child: Text('No events yet', style: lqT(13, c: lqMu)))
                : LayoutBuilder(builder: (context, c) {
                    const rowH = 24.0;
                    final n = math.min(d.events.length, (c.maxHeight / rowH).floor());
                    return Column(children: [
                      for (final (i, e) in d.events.take(n).indexed)
                        Container(
                          height: rowH,
                          decoration: BoxDecoration(border: i == 0 ? null : const Border(top: BorderSide(color: lqSep))),
                          child: Row(children: [
                            _dot(hsEventColor(e, tk), size: 6, halo: false),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                e.message,
                                style: lqT(12.5,
                                    w: e.severity == 'info' ? FontWeight.w500 : FontWeight.w600,
                                    c: switch (e.severity) {
                                      'critical' => lqRed,
                                      'warning' => lqGold,
                                      _ => lqTx,
                                    }),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(slackTime(e.ts, now), style: lqT(11.5, c: lqFa)),
                          ]),
                        ),
                    ]);
                  }),
          ),
        ]),
      );
}

// ------------------------------------------------------------------ Timer

/// Concept timer: the big thin ring with the time and mode; beside it the mode switch,
/// Start / Pause (solid) and Reset, and today's focus sessions (or the countdown length).
class LqTimerPage extends ConsumerWidget {
  const LqTimerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(timerProvider);
    final ctl = ref.read(timerProvider.notifier);
    return Ticker(
      period: const Duration(milliseconds: 250),
      builder: (context, now) {
        final d = st.display(now);
        final digits = d.inHours > 0
            ? '${d.inHours}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}'
            : '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
        final label = st.running ? 'Pause' : (st.pristine ? 'Start' : 'Resume');
        return Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Row(children: [
            LayoutBuilder(builder: (context, c) {
              final side = math.min(c.maxHeight, 270.0);
              return LqRing(
                value: st.progress(now),
                size: side,
                stroke: 6,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                    width: side * .7,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(digits, style: lqN(66 * side / 270), maxLines: 1),
                    ),
                  ),
                  SizedBox(height: side * .035),
                  Text(st.mode.label, style: lqT(15, w: FontWeight.w600, c: lqMu)),
                ]),
              );
            }),
            const SizedBox(width: 30),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: LqSeg<TimerMode>(
                    items: [for (final m in TimerMode.values) (m, m.label)],
                    value: st.mode,
                    onChanged: ctl.setMode,
                  ),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  LqButton(
                    solid: true,
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    onTap: ctl.toggle,
                    // Wide enough for "Resume", so Reset doesn't shift as the label changes.
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 96),
                      child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                        DpIcon(st.running ? 'pause' : 'play', size: 19, color: lqInk, stroke: 2.2),
                        const SizedBox(width: 9),
                        Text(label, style: lqT(16, w: FontWeight.w700, c: lqInk)),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 10),
                  LqButton(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    onTap: ctl.reset,
                    child: Text('Reset', style: lqT(16, w: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 16),
                SizedBox(height: 34, child: _sessions(st, ctl)),
              ]),
            ),
          ]),
        );
      },
    );
  }

  /// Pomodoro modes: "n of 4 focus sessions today". Countdown: its length, − / + while stopped.
  Widget _sessions(TimerState st, TimerNotifier ctl) {
    if (st.mode.isPomodoro) {
      return Row(children: [
        for (var i = 0; i < 4; i++)
          Container(
            width: 28,
            height: 8,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: i < st.sessions ? lqTx : const Color(0x40FFFFFF),
              borderRadius: BorderRadius.circular(9),
            ),
          ),
        const SizedBox(width: 6),
        Flexible(
          child: Text('${st.sessions} of 4 focus sessions today',
              style: lqT(13.5, c: lqMu), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ]);
    }
    if (st.mode == TimerMode.countdown) {
      Widget step(String s, int by) => LqButton(
            circle: true,
            size: 34,
            onTap: () => ctl.adjust(by),
            child: Text(s, style: lqT(18, w: FontWeight.w600, h: 1)),
          );
      final len = Text('${st.countdownMin} min', style: lqT(14, w: FontWeight.w600));
      if (st.running) return Align(alignment: Alignment.centerLeft, child: len);
      return Row(children: [step('−', -1), const SizedBox(width: 12), len, const SizedBox(width: 12), step('+', 1)]);
    }
    return const SizedBox.shrink();
  }
}

// ------------------------------------------------------------------ Slack

/// Initials on a circle in the sender's colour (faded for read messages).
Widget _avatar(SlackMsg m, double size, {bool dim = false}) {
  final c = hex(m.senderColor, lqCyan);
  final fg = c.computeLuminance() > .5 ? lqInk : lqTx;
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: dim ? c.withValues(alpha: .4) : c,
      border: Border.all(color: const Color(0x4DFFFFFF)),
    ),
    alignment: Alignment.center,
    child: Text(m.initials,
        style: lqT(size * .37, w: FontWeight.w700, c: dim ? fg.withValues(alpha: .6) : fg, h: 1, ls: 0)),
  );
}

/// Slack: the unread summary (count, Mark all read, the newest unread featured) beside the
/// rest of the messages as `.li` rows, each unread one with its own mark-read tick.
class LqSlackPage extends ConsumerWidget {
  const LqSlackPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = topicData<SlackData>(ref, 'slack')!;
    final unread = s.unreadMessages;
    final hero = unread.isEmpty ? null : unread.first;
    final rest = s.messages.where((m) => m != hero).toList();
    return Ticker(
      builder: (context, now) => s.messages.isEmpty
          ? _caughtUp(s, wide: true)
          : Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                flex: 100,
                child: hero == null
                    ? _caughtUp(s)
                    : _summary(context, ref, math.max(s.unread, unread.length), hero, now),
              ),
              const SizedBox(width: _gap),
              Expanded(flex: 122, child: _list(context, ref, rest, now, hero != null)),
            ]),
    );
  }

  Widget _caughtUp(SlackData s, {bool wide = false}) => LqCard(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const LqGlass(
              radius: 99,
              fill: Color(0x33FFFFFF),
              child: SizedBox(width: 62, height: 62, child: Center(child: DpIcon('check', size: 28, color: lqTx, stroke: 2.4))),
            ),
            const SizedBox(height: 14),
            Text('All caught up', style: lqT(22, w: FontWeight.w700, ls: -.02)),
            const SizedBox(height: 4),
            Text(
              wide ? 'No new messages${s.team == null ? '' : ' in ${s.team}'}' : 'No unread messages',
              style: lqT(13.5, c: lqMu),
              textAlign: TextAlign.center,
            ),
          ]),
        ),
      );

  Widget _summary(BuildContext context, WidgetRef ref, int count, SlackMsg m, DateTime now) => LqCard(
        onTap: () => slackOpen(context, ref, m),
        padding: const EdgeInsets.fromLTRB(16, 12, 14, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: lqBig('$count', 60, unit: 'unread')),
            const SizedBox(width: 8),
            LqButton(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              onTap: () => slackReadAll(context, ref),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const DpIcon('check', size: 15, color: lqTx, stroke: 2.4),
                const SizedBox(width: 6),
                Text('Mark all read', style: lqT(13, w: FontWeight.w600)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          Container(height: 1, color: lqSep),
          const SizedBox(height: 10),
          Row(children: [
            _avatar(m, 38),
            const SizedBox(width: 11),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m.sender, style: lqT(15.5, w: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(slackWhere(m), style: lqT(12.5, c: lqMu), maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            const SizedBox(width: 8),
            Text(slackTime(m.ts, now), style: lqT(12.5, w: FontWeight.w700)),
            SlackReadTick(m, color: lqTx, fill: lqTx, onFill: lqInk, size: 26, hit: 40),
          ]),
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(builder: (context, c) {
              const size = 16.0, lh = 1.34;
              final lines = (c.maxHeight / (size * lh)).floor();
              if (lines < 1) return const SizedBox.shrink();
              return Text(m.text,
                  style: lqT(size, h: lh), maxLines: math.min(lines, 5), overflow: TextOverflow.ellipsis);
            }),
          ),
          const SizedBox(height: 8),
          LqButton(
            solid: true,
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            onTap: () => slackOpen(context, ref, m),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const DpIcon('slack', size: 16, color: lqInk, stroke: 2),
              const SizedBox(width: 7),
              Text('Open in Slack', style: lqT(13.5, w: FontWeight.w700, c: lqInk)),
            ]),
          ),
        ]),
      );

  Widget _list(BuildContext context, WidgetRef ref, List<SlackMsg> msgs, DateTime now, bool hasHero) => LqCard(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(children: [
              Expanded(child: lqLab(hasHero ? 'Earlier' : 'Recent')),
              Text('${msgs.length}', style: lqT(12.5, w: FontWeight.w600, c: lqFa)),
            ]),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: msgs.isEmpty
                ? Center(child: Text('Nothing else in Slack', style: lqT(13.5, c: lqMu)))
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: msgs.length,
                    itemBuilder: (context, i) => _row(context, ref, msgs[i], now, first: i == 0),
                  ),
          ),
        ]),
      );

  /// `.li`: avatar, sender + where and the message, time and the mark-read tick. Read
  /// messages are dimmed by colour (no Opacity layer).
  Widget _row(BuildContext context, WidgetRef ref, SlackMsg m, DateTime now, {required bool first}) {
    final u = m.unread;
    return Press(
      onTap: () => slackOpen(context, ref, m),
      scale: .99,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: lqSep))),
        child: Row(children: [
          _avatar(m, 34, dim: !u),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: m.sender, style: lqT(14.5, w: u ? FontWeight.w700 : FontWeight.w600, c: u ? lqTx : lqFa)),
                      TextSpan(text: '  ${slackWhere(m)}', style: lqT(12.5, c: u ? lqMu : lqFa)),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(slackTime(m.ts, now), style: lqT(12, w: u ? FontWeight.w700 : FontWeight.w500, c: u ? lqTx : lqFa)),
              ]),
              const SizedBox(height: 1),
              Text(m.text,
                  style: lqT(13, c: u ? const Color(0xE6FFFFFF) : lqFa, h: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
          const SizedBox(width: 2),
          SlackReadTick(m, color: lqTx, fill: lqTx, onFill: lqInk, size: 24, hit: 38),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------------ Controls

/// Concept `.cc`: Control Center toggles (round 72 px glass buttons, solid white with a red
/// icon while on) in a grid, and the tall volume slider as the last column. Volume up /
/// down live on the slider, not as tiles. More tiles add columns, then rows; the circles
/// shrink (and drop their sub-labels) only when a cell gets too small.
class LqControlsPage extends ConsumerWidget {
  const LqControlsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sc = topicData<ShortcutsData>(ref, 'shortcuts')!;
    final order = ref.watch(settingsProvider.select((s) => s.tileOrder));
    final tiles = orderedTiles(sc.tiles, order).where((t) => !t.id.startsWith('volume.')).toList();
    final cols = math.min(6, math.max(3, (tiles.length / 2).ceil()));
    final rows = math.max(2, (tiles.length / cols).ceil());
    void run(String id) => act(context, ref, 'shortcut.run', {'id': id});
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        flex: cols * 10,
        child: Column(children: [
          for (var r = 0; r < rows; r++) ...[
            if (r > 0) const SizedBox(height: _gap),
            Expanded(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (var c = 0; c < cols; c++) ...[
                  if (c > 0) const SizedBox(width: _gap),
                  Expanded(
                    child: r * cols + c < tiles.length
                        ? _Toggle(tile: tiles[r * cols + c], onTap: () => run(tiles[r * cols + c].id))
                        : const SizedBox(),
                  ),
                ],
              ]),
            ),
          ],
        ]),
      ),
      const SizedBox(width: _gap),
      Expanded(
        flex: 9,
        child: _Volume(vol: sc.volumePct, up: () => run('volume.up'), down: () => run('volume.down')),
      ),
    ]);
  }
}

/// `.tog`: the round glass button with the tile's icon, its label and a small sub-label.
class _Toggle extends StatelessWidget {
  const _Toggle({required this.tile, required this.onTap});
  final Tile tile;
  final VoidCallback onTap;

  /// The tile's own detail, else the concept's hint for the built-in tiles.
  String? get _sub =>
      tile.detail ??
      switch (tile.id) {
        'screenshot' => 'Full screen',
        'terminal' => 'New window',
        'downloads' => 'Open folder',
        'lock' => 'Right away',
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final on = tile.active;
    final sub = _sub;
    return Press(
      onTap: onTap,
      scale: 1.06,
      child: LayoutBuilder(builder: (context, c) {
        const labelH = 17.0, subH = 16.0, gap = 8.0;
        // Room for the label always; for the sub-label line only while the circle stays ≥ 56.
        var showSub = true;
        var d = math.min(72.0, math.min(c.maxWidth - 8, c.maxHeight - gap - labelH - subH));
        if (d < 56) {
          showSub = false;
          d = math.min(72.0, math.min(c.maxWidth - 8, c.maxHeight - gap - labelH));
        }
        d = math.max(d, 28.0);
        return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(
            width: d,
            height: d,
            child: LqGlass(
              radius: 99,
              fill: on ? const Color(0xF2FFFFFF) : null,
              child: Center(
                child: DpIcon(tileIcon(tile), size: d * .39, color: on ? const Color(0xFFE5484D) : lqTx, stroke: 1.9),
              ),
            ),
          ),
          const SizedBox(height: gap),
          SizedBox(
            height: labelH,
            child: Text(tileLabel(tile),
                style: lqT(13, w: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center),
          ),
          if (showSub)
            SizedBox(
              height: subH,
              child: sub == null
                  ? null
                  : Text(sub,
                      style: lqT(11.5, c: lqMu),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center),
            ),
        ]);
      }),
    );
  }
}

/// `.vol`: a tall glass slider. White fill rises from the bottom to the volume; volume up
/// (top half) and down (bottom half), the % in the middle. Icons and figure turn dark where
/// the fill is under them (the concept's `mix-blend-mode: difference`, done with a hard clip).
class _Volume extends StatelessWidget {
  const _Volume({required this.vol, required this.up, required this.down});
  final int? vol;
  final VoidCallback up, down;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(end: ((vol ?? 0) / 100).clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutBack,
        builder: (context, p, _) => LqGlass(
          radius: 30,
          child: LayoutBuilder(builder: (context, c) {
            final h = c.maxHeight;
            final cut = h - h * p.clamp(0.0, 1.0); // y where the fill starts
            Widget half(String icon, VoidCallback onTap, double top) => Expanded(
                  child: Press(
                    onTap: onTap,
                    scale: 1.12,
                    child: _TwoTone(cut: cut - top, builder: (col) => DpIcon(icon, size: 24, color: col, stroke: 2)),
                  ),
                );
            return Stack(fit: StackFit.expand, children: [
              CustomPaint(painter: _VolFill(p, 30)),
              Column(children: [half('volUp', up, 0), half('volDown', down, h / 2)]),
              IgnorePointer(
                child: _TwoTone(
                  cut: cut,
                  builder: (col) => Text(vol == null ? '—' : '$vol%', style: lqT(15, w: FontWeight.w700, c: col)),
                ),
              ),
            ]);
          }),
        ),
      );
}

/// Draws [builder] centred in white, and again in ink below [cut] (local y), clipped.
class _TwoTone extends StatelessWidget {
  const _TwoTone({required this.cut, required this.builder});
  final double cut;
  final Widget Function(Color) builder;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final h = c.maxHeight;
        final top = cut.clamp(0.0, h);
        return Stack(fit: StackFit.expand, children: [
          if (top > 0) Center(child: builder(lqTx)),
          if (top < h)
            Positioned(
              left: 0,
              right: 0,
              top: top,
              bottom: 0,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.bottomCenter,
                  minHeight: h,
                  maxHeight: h,
                  child: Center(child: builder(lqInk)),
                ),
              ),
            ),
        ]);
      });
}

/// The volume level: white .9 from the bottom, inside the slider's rounded outline.
class _VolFill extends CustomPainter {
  _VolFill(this.p, this.radius);
  final double p, radius;

  @override
  void paint(Canvas canvas, Size size) {
    final v = p.clamp(0.0, 1.0);
    if (v <= 0 || size.isEmpty) return;
    final outline = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(math.min(radius, size.shortestSide / 2))));
    final level = Path()..addRect(Rect.fromLTRB(0, size.height * (1 - v), size.width, size.height));
    canvas.drawPath(Path.combine(PathOperation.intersect, outline, level), Paint()..color = const Color(0xE6FFFFFF));
  }

  @override
  bool shouldRepaint(_VolFill o) => o.p != p || o.radius != radius;
}
