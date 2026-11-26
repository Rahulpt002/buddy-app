// Liquid (concept 16) pages: System, Claude, Calendar, Weather, GitHub. Shared pieces: liquid_kit.dart.
// Layouts follow `pages.system/claude/calendar/weather/github` in deskpanel-concept-16-liquid.html.
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/conn/controller.dart';
import '../../core/settings.dart';
import '../fmt.dart';
import '../icons.dart';
import '../pages/kit.dart';
import '../widgets/bar_tip.dart';
import '../widgets/common.dart';
import 'liquid_kit.dart';

const _gap = 12.0;

/// A card with one muted line in the middle (waiting / empty states).
Widget _note(String s) => LqCard(child: Center(child: Text(s, style: lqT(14, c: lqMu), textAlign: TextAlign.center)));

/// A muted one-liner (`.mu`).
Widget _mu(String s, {double size = 12, int lines = 1, TextAlign? align, double? h}) => Text(s,
    style: lqT(size, c: lqMu, h: h), maxLines: lines, overflow: TextOverflow.ellipsis, textAlign: align);

/// A big figure that shrinks rather than overflows when its slot is narrow.
Widget _fit(Widget big, {Alignment alignment = Alignment.centerLeft}) =>
    FittedBox(fit: BoxFit.scaleDown, alignment: alignment, child: big);

// ------------------------------------------------------------------ System

/// Concept system: a Laptop | Internet switch, then four ring cards and the last-minute
/// chart, or latency / connection / speed test.
class LqSystemPage extends ConsumerWidget {
  const LqSystemPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(systemTabProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Align(
        alignment: Alignment.centerLeft,
        child: LqSeg<int>(
          items: const [(0, 'Laptop'), (1, 'Internet')],
          value: tab,
          onChanged: ref.read(systemTabProvider.notifier).set,
        ),
      ),
      const SizedBox(height: _gap),
      Expanded(child: tab == 0 ? const _Laptop() : const _Internet()),
    ]);
  }
}

class _Laptop extends ConsumerWidget {
  const _Laptop();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = topicData<SystemData>(ref, 'system');
    if (s == null) return _note('Waiting for laptop data…');
    final g = s.gpu;
    const gb = 1073741824;
    final ram = s.ramTotal > 0 ? s.ramUsed / s.ramTotal * 100 : null;
    final vram = g.vramUsed != null && (g.vramTotal ?? 0) > 0 ? g.vramUsed! / g.vramTotal! * 100 : null;
    final (down, downU) = rate(s.downBps);
    final (up, upU) = rate(s.upBps);

    Widget ring(String label, double? pct, String sub, Color c) => LqCard(
          child: Row(children: [
            LqRing(
              value: (pct ?? 0) / 100,
              size: 80,
              color: c,
              child: Text(pct == null ? 'N/A' : '${pct.round()}%', style: lqN(pct == null ? 17 : 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                // Shrinks a little rather than cut "GPU memory" (Apple Silicon's label).
                _fit(Text(label, style: lqT(14, w: FontWeight.w700), maxLines: 1)),
                const SizedBox(height: 1),
                _mu(sub),
              ]),
            ),
          ]),
        );

    final cards = [
      ring('Processor', s.cpu.pct, s.cpu.cores != null ? '${s.cpu.cores} cores' : s.cpu.model, lqTx),
      ring('Graphics', g.available ? g.pct : null,
          g.tempC != null ? '${g.tempC!.round()}°C' : (g.model ?? 'Not available'), lqCyan),
      ring('Memory', ram, '${(s.ramUsed / gb).toStringAsFixed(1)}/${(s.ramTotal / gb).round()} GB', lqTx),
      ring(g.vramLabel == 'VRAM' ? 'Video' : 'GPU memory', vram,
          vram == null ? 'Not available' : '${(g.vramUsed! / gb).toStringAsFixed(1)}/${(g.vramTotal! / gb).round()} GB',
          lqCyan),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        for (final (i, c) in cards.indexed) ...[if (i > 0) const SizedBox(width: _gap), Expanded(child: c)],
      ]),
      const SizedBox(height: _gap),
      Expanded(
        child: LqCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              lqLab('Last minute'),
              const SizedBox(width: 12),
              _key('CPU', lqTx),
              if (g.available) ...[const SizedBox(width: 10), _key('GPU', lqCyan)],
              const SizedBox(width: 16),
              Expanded(
                child: _mu('$down $downU down, $up $upU up. ${s.cpu.model}, disk ${s.diskPct.round()}%',
                    align: TextAlign.right),
              ),
            ]),
            const SizedBox(height: 6),
            Expanded(
              child: _LqChart([
                if (g.available) _Line(s.gpuHistory, lqCyan.withValues(alpha: .9), 2.5),
                _Line(s.cpuHistory, lqTx, 3, fill: true),
              ], pad: 4),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget _key(String s, Color c) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: c)),
        const SizedBox(width: 5),
        Text(s, style: lqT(11.5, w: FontWeight.w600, c: lqMu)),
      ]);
}

class _Internet extends ConsumerWidget {
  const _Internet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = topicData<NetworkData>(ref, 'network');
    final live = ref.watch(agentProvider).live;
    if (n == null) return _note('Waiting for network data…');
    final st = n.speedtest, last = st.last, prog = st.progress;
    final down = st.running ? prog?.downBps : last?.downBps;
    final up = st.running ? prog?.upBps : last?.upBps;
    return Ticker(
      builder: (context, now) {
        final latency = LqCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              lqLab('Latency'),
              const SizedBox(width: 10),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _fit(
                    n.latencyMs == null ? lqBig('Timeout', 28) : lqBig('${n.latencyMs!.round()}', 38, unit: 'ms'),
                    alignment: Alignment.centerRight,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            Expanded(child: _LqChart([_Line(n.latencyHistory, lqTx, 2.5, fill: true)], max: 50, pad: 3)),
            const SizedBox(height: 6),
            _mu('Jitter ${n.jitterMs?.toStringAsFixed(1) ?? '—'} ms, ${n.lossPct.round()}% loss'),
          ]),
        );

        final uptime = n.online
            ? (n.onlineSince == null ? 'Up' : 'Up ${durLong(now.difference(n.onlineSince!))}')
            : 'Down right now';
        final connection = LqCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            lqLab('Connection'),
            const SizedBox(height: 8),
            Row(children: [
              lqDot(ok: live && n.online),
              const SizedBox(width: 10),
              Text(!live ? 'Unknown' : (n.online ? 'Online' : 'Offline'), style: lqT(20, w: FontWeight.w700)),
            ]),
            const SizedBox(height: 8),
            Flexible(
              child: _mu(
                '$uptime\n'
                'Last drop ${n.lastDrop == null ? 'never' : ago(now.difference(n.lastDrop!))}\n'
                '${bytes(n.usageToday)} today\n'
                '${bytes(n.usageMonth, digits: 0)} this month',
                size: 12.5,
                lines: 4,
                h: 1.45,
              ),
            ),
          ]),
        );

        final speed = LqCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [lqLab('Speed test'), const Spacer(), _mu('Mbps')]),
            const SizedBox(height: 6),
            _fit(lqBig(down == null ? '—' : mbps(down), 38, unit: 'down')),
            const SizedBox(height: 2),
            _fit(lqBig(up == null ? '—' : mbps(up), 38, unit: 'up')),
            const SizedBox(height: 6),
            _mu(st.running
                ? 'Testing now'
                : last == null
                    ? 'Not tested yet'
                    : 'Tested ${ago(now.difference(last.at))}, ping ${last.pingMs.round()} ms'),
            if (st.running) ...[const SizedBox(height: 6), LqBar(value: (prog?.pct ?? 0) / 100, height: 6)],
            const Spacer(),
            LqButton(
              solid: true,
              onTap: st.running
                  ? null
                  : () => act(context, ref, 'speedtest.run', const {}, null, null, const Duration(seconds: 90)),
              child: Text(st.running ? 'Testing…' : 'Run test'),
            ),
          ]),
        );

        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(flex: 13, child: latency),
          const SizedBox(width: _gap),
          Expanded(flex: 10, child: connection),
          const SizedBox(width: _gap),
          Expanded(flex: 10, child: speed),
        ]);
      },
    );
  }
}

// ------------------------------------------------------------------ Claude

/// Concept claude: a tall 5-hour ring, weekly limit, today, and the last 7 days.
class LqClaudePage extends ConsumerWidget {
  const LqClaudePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = topicData<ClaudeData>(ref, 'claude');
    final h24 = ref.watch(settingsProvider.select((s) => s.clock24));
    if (c == null) return _note('Waiting for Claude data…');
    return Ticker(
      builder: (context, now) {
        final five = limitPct(c.fiveHour, now), week = limitPct(c.sevenDay, now);
        final reset = resetsIn(c.fiveHour, now);
        const lead = 'Resets in ';

        final fiveCard = LqCard(
          child: Column(children: [
            Align(alignment: Alignment.centerLeft, child: lqLab('5-hour limit')),
            Expanded(
              child: Center(
                child: LayoutBuilder(
                  builder: (context, box) => LqRing(
                    value: five / 100,
                    size: math.min(170, box.biggest.shortestSide),
                    stroke: 8,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: _fit(
                        Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(c.fiveHour == null ? '—' : '${five.round()}%', style: lqN(46)),
                          const SizedBox(height: 4),
                          Text('used', style: lqT(13.5, c: lqMu)),
                        ]),
                        alignment: Alignment.center,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Text.rich(
              reset.startsWith(lead)
                  ? TextSpan(children: [
                      TextSpan(text: lead, style: lqT(13.5)),
                      TextSpan(text: reset.substring(lead.length), style: lqT(13.5, w: FontWeight.w700)),
                    ])
                  : TextSpan(text: reset, style: lqT(13.5)),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ]),
        );

        final weekly = LqCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            lqLab('Weekly limit'),
            const SizedBox(height: 4),
            // `61<small>%</small>`: the unit sits right against the figure.
            _fit(Text.rich(
              TextSpan(children: [
                TextSpan(text: c.sevenDay == null ? '—' : '${week.round()}', style: lqN(44)),
                if (c.sevenDay != null) TextSpan(text: '%', style: lqT(44 * .42, w: FontWeight.w600, c: lqMu)),
              ]),
              maxLines: 1,
            )),
            const Spacer(),
            LqBar(value: week / 100, color: lqGold),
            const SizedBox(height: 6),
            _mu(resetsAt(c.sevenDay, now, h24: h24)),
          ]),
        );

        final today = LqCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            lqLab('Today'),
            const SizedBox(height: 4),
            _fit(lqBig(compact(c.tokens), 36, unit: 'tokens')),
            const SizedBox(height: 6),
            Flexible(
              child: _mu(
                '${compact(c.outputTokens)} output, ${c.messages} messages, '
                '${compact(c.lastHourTokens)} in the last hour',
                size: 12.5,
                lines: 3,
                h: 1.3,
              ),
            ),
          ]),
        );

        final peak = maxOf(c.days.map((d) => d.tokens));
        final last7 = LqCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              lqLab('Last 7 days'),
              const SizedBox(width: 12),
              Expanded(
                child: _mu(
                  c.modelsToday.isEmpty
                      ? 'No messages yet today'
                      : c.modelsToday.map((m) => '${modelName(m.family)} ${compact(m.tokens)}').join(', '),
                  align: TextAlign.right,
                ),
              ),
            ]),
            const SizedBox(height: 6),
            Expanded(
              child: BarTapTip(
                count: c.days.length,
                label: (i) => dayTokensLabel(c.days[i], now),
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (final (i, d) in c.days.indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(child: _dayBar(d, peak, i == c.days.length - 1, now)),
                  ],
                ]),
              ),
            ),
          ]),
        );

        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(flex: 115, child: fiveCard),
          const SizedBox(width: _gap),
          Expanded(
            flex: 204,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: weekly),
                  const SizedBox(width: _gap),
                  Expanded(child: today),
                ]),
              ),
              const SizedBox(height: _gap),
              Expanded(child: last7),
            ]),
          ),
        ]);
      },
    );
  }

  /// A pill bar: today's is white with a faint halo, the others white .4.
  Widget _dayBar(ClaudeDay d, double peak, bool today, DateTime now) => Column(children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) => Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                width: math.min(24, box.maxWidth),
                height: math.max(8, (box.maxHeight - 3) * d.tokens / peak * .94),
                decoration: BoxDecoration(
                  color: today ? lqTx : const Color(0x66FFFFFF),
                  borderRadius: BorderRadius.circular(99),
                  border: today
                      ? Border.all(color: const Color(0x38FFFFFF), width: 3, strokeAlign: BorderSide.strokeAlignOutside)
                      : null,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(dayLabel(d.date, now),
            style: lqT(11, w: today ? FontWeight.w700 : FontWeight.w500, c: today ? lqTx : lqMu), maxLines: 1),
      ]);
}

// ------------------------------------------------------------------ Calendar

/// Concept calendar: "Next up" with a big countdown, then today's list and later pills.
class LqCalendarPage extends ConsumerWidget {
  const LqCalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(calendarEventsProvider);
    final h24 = ref.watch(settingsProvider.select((s) => s.clock24));
    return Ticker(
      builder: (context, now) {
        final split = splitEvents(events, now);
        final n = nextEvent(events, now);
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(flex: 100, child: _next(n, now, h24)),
          const SizedBox(width: _gap),
          Expanded(flex: 115, child: _today(split, now, h24)),
        ]);
      },
    );
  }

  static String _countdown(CalEvent e, DateTime now) {
    if (!e.start.isAfter(now)) return 'Now';
    final d = e.start.difference(now);
    return d.inMinutes < 1 ? 'Starting now' : 'in ${dur(d)}';
  }

  Widget _next(CalEvent? n, DateTime now, bool h24) {
    if (n == null) {
      return LqCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          lqLab('Next up'),
          const SizedBox(height: 6),
          Text('Nothing else today', style: lqT(24, w: FontWeight.w700, ls: -.02)),
          const SizedBox(height: 4),
          _mu('Free until tomorrow', size: 13.5),
        ]),
      );
    }
    return LqCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        lqLab('Next up'),
        const SizedBox(height: 6),
        Text(n.title,
            style: lqT(26, w: FontWeight.w700, h: 1.12, ls: -.02), maxLines: 2, overflow: TextOverflow.ellipsis),
        const Spacer(),
        _fit(Text(_countdown(n, now), style: lqN(64), maxLines: 1)),
        const SizedBox(height: 10),
        Row(children: [
          LqPill(height: 30, children: [
            const DpIcon('clock', size: 16, color: lqTx),
            Text(n.allDay ? 'All day' : clockFull(n.start, h24: h24)),
          ]),
          if (n.location != null && n.location!.isNotEmpty) ...[
            const SizedBox(width: 8),
            Flexible(
              child: LqPill(height: 30, children: [
                const DpIcon('pin', size: 16, color: lqTx),
                Flexible(child: Text(n.location!, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            ),
          ],
        ]),
      ]),
    );
  }

  Widget _today(({List<CalEvent> today, List<CalEvent> later}) split, DateTime now, bool h24) {
    String later(CalEvent e) {
      if (e.allDay) return '${weekday3(e.start)}, ${e.title}';
      final t = clockFull(e.start, h24: h24);
      return '${weekday3(e.start)} ${h24 ? t : t.replaceAll(':00', '')}, ${e.title}';
    }

    return LqCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        lqLab('Today'),
        const SizedBox(height: 2),
        if (split.today.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: _mu('Nothing on the calendar today', size: 13.5))
        else
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                for (final (i, e) in split.today.indexed)
                  LqRow(
                    first: i == 0,
                    dim: !e.end.isAfter(now),
                    leading: Container(
                      width: 4,
                      height: 32,
                      decoration:
                          BoxDecoration(color: hex(e.color, lqCyan), borderRadius: BorderRadius.circular(4)),
                    ),
                    title: e.title,
                    subtitle: e.location ?? e.calendar,
                    trailing: Text(e.allDay ? 'All day' : clockFull(e.start, h24: h24), style: lqT(13.5, c: lqMu)),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        lqLab('Later this week'),
        const SizedBox(height: 6),
        if (split.later.isEmpty)
          _mu('Nothing else this week', size: 13)
        else
          // Two rows of pills at most; the rest are clipped.
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 62),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              clipBehavior: Clip.hardEdge,
              children: [
                for (final e in split.later.take(8))
                  LqPill(height: 28, fontSize: 12.5, children: [
                    Flexible(child: Text(later(e), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
              ],
            ),
          ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ Weather

/// Concept weather: the tall current card, the next 12 hours, and the week with range bars.
class LqWeatherPage extends ConsumerWidget {
  const LqWeatherPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(weatherProvider);
    final f = ref.watch(settingsProvider.select((s) => s.fahrenheit));
    final h24 = ref.watch(settingsProvider.select((s) => s.clock24));
    if (w == null) {
      return LqCard(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const DpIcon('weather', size: 40, color: lqMu, stroke: 1.5),
            const SizedBox(height: 12),
            Text('Choose a location', style: lqT(22, w: FontWeight.w700)),
            const SizedBox(height: 6),
            _mu('Allow location access, or pick a city in Settings → Weather.', size: 13.5, align: TextAlign.center),
          ]),
        ),
      );
    }
    final t0 = w.days.isEmpty ? null : w.days.first;

    final current = LqCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        lqLab(w.place),
        const SizedBox(height: 6),
        _fit(Text('${temp(w.now.tempC, f)}°', style: lqN(96), maxLines: 1)),
        const SizedBox(height: 6),
        Text(w.now.condition, style: lqT(20, w: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        _mu(
          '${t0 == null ? '' : 'H ${temp(t0.hiC, f)}° L ${temp(t0.loC, f)}°. '}Feels like ${temp(w.now.feelsC, f)}°.',
          size: 13.5,
          lines: 2,
        ),
        const Spacer(),
        Row(children: [
          const DpIcon('drop', size: 15, color: lqMu),
          const SizedBox(width: 4),
          _mu('${w.now.humidity}%', size: 12.5),
          const SizedBox(width: 14),
          const DpIcon('wind', size: 15, color: lqMu),
          const SizedBox(width: 4),
          Flexible(child: _mu(wind(w.now.windKmh, f), size: 12.5)),
        ]),
      ]),
    );

    String hour(DateTime t) => h24 ? '${two(t.hour)}:00' : '${t.hour % 12 == 0 ? 12 : t.hour % 12} ${ampm(t)}';
    final hours = [for (var i = 0; i < w.hours.length; i += 2) w.hours[i]];
    final next12 = LqCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        lqLab('Next 12 hours'),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (final (k, h) in hours.indexed)
            Column(mainAxisSize: MainAxisSize.min, children: [
              _mu(k == 0 ? 'Now' : hour(h.time)),
              const SizedBox(height: 6),
              DpIcon(h.icon, size: 20, color: lqTx),
              const SizedBox(height: 6),
              Text('${temp(h.tempC, f)}°', style: lqN(16)),
            ]),
        ]),
      ]),
    );

    final lo = w.days.isEmpty ? 0.0 : w.days.map((d) => d.loC).reduce(math.min);
    final hi = w.days.isEmpty ? 1.0 : w.days.map((d) => d.hiC).reduce(math.max);
    final week = LqCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        lqLab('This week'),
        const SizedBox(height: 2),
        for (final (i, d) in w.days.indexed)
          Expanded(
            child: Row(children: [
              SizedBox(
                width: 52,
                child: Text(i == 0 ? 'Today' : weekday3(d.date), style: lqT(13, w: FontWeight.w700), maxLines: 1),
              ),
              const SizedBox(width: 10),
              SizedBox(width: 22, child: Center(child: DpIcon(d.icon, size: 17, color: lqTx))),
              const SizedBox(width: 10),
              SizedBox(
                width: 36,
                child: Text(d.precipPct > 0 ? '${d.precipPct}%' : '',
                    style: lqT(11.5, w: FontWeight.w600, c: lqCyan), maxLines: 1),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 30,
                child: Text('${temp(d.loC, f)}°', style: lqT(13, c: lqMu), textAlign: TextAlign.right, maxLines: 1),
              ),
              const SizedBox(width: 10),
              Expanded(child: _Range(lo: lo, hi: hi, from: d.loC, to: d.hiC)),
              const SizedBox(width: 10),
              SizedBox(
                width: 30,
                child: Text('${temp(d.hiC, f)}°', style: lqT(13, w: FontWeight.w700), maxLines: 1),
              ),
            ]),
          ),
      ]),
    );

    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(flex: 90, child: current),
      const SizedBox(width: _gap),
      Expanded(
        flex: 130,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          next12,
          const SizedBox(height: _gap),
          Expanded(child: week),
        ]),
      ),
    ]);
  }
}

/// A day's low..high on the week's scale: a cyan-to-gold segment on a faint track.
class _Range extends StatelessWidget {
  const _Range({required this.lo, required this.hi, required this.from, required this.to});
  final double lo, hi, from, to;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 6,
        child: LayoutBuilder(builder: (context, box) {
          final span = hi - lo;
          final a = span <= 0 ? 0.0 : ((from - lo) / span).clamp(0.0, 1.0);
          final b = span <= 0 ? 1.0 : ((to - lo) / span).clamp(0.0, 1.0);
          final w = box.maxWidth;
          return Stack(children: [
            Positioned.fill(
              child: DecoratedBox(
                  decoration: BoxDecoration(color: const Color(0x2EFFFFFF), borderRadius: BorderRadius.circular(9))),
            ),
            Positioned(
              left: a * w,
              width: math.max(6, (b - a) * w),
              top: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  gradient: const LinearGradient(colors: [lqCyan, lqGold]),
                ),
              ),
            ),
          ]);
        }),
      );
}

// ------------------------------------------------------------------ GitHub

/// Concept github: the full-width contributions heatmap (with the GitHub | GitLab switch
/// in its header), then streak, this week and top repos.
class LqGithubPage extends ConsumerWidget {
  const LqGithubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final src = ref.watch(codeSourceProvider);
    final g = topicData<GithubData>(ref, codeTopic(ref));
    final seg = LqSeg<int>(
      items: [for (final (i, l) in codeSources.indexed) (i, l)],
      value: src,
      onChanged: ref.read(codeSourceProvider.notifier).set,
    );
    if (g == null) {
      return LqCard(
        child: Column(children: [
          Align(alignment: Alignment.topRight, child: seg),
          Expanded(child: Center(child: _mu('Waiting for ${codeSources[src]} data…', size: 14))),
        ]),
      );
    }
    final best = g.bestDay;
    return LayoutBuilder(builder: (context, box) {
      // The card's top/right padding is 8 so the switch sits concentric with the card's
      // corner; the heatmap gets what's left once the bottom row has its minimum.
      const bottomMin = 110.0, segH = 36.0, chrome = 8 + segH + 6 + 12;
      final heatW = box.maxWidth - 32;
      final heatH = (box.maxHeight - _gap - bottomMin - chrome).clamp(35.0, heatW / 53 * 7);
      final heat = LqCard(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            lqLab('Contributions'),
            const SizedBox(width: 12),
            Expanded(
              child: _mu('${_thousands(g.total)} total, ${g.commits} commits, ${g.private} private'),
            ),
            const SizedBox(width: 12),
            seg,
          ]),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SizedBox(height: heatH, child: CustomPaint(painter: _HeatPainter(g.weeks))),
          ),
        ]),
      );

      final streak = LqCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          lqLab('Streak'),
          const SizedBox(height: 4),
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: _fit(lqBig('${g.streakCurrent}', 66, unit: g.streakCurrent == 1 ? 'day' : 'days'),
                  alignment: Alignment.topLeft),
            ),
          ),
          _mu(
            'Longest ${g.streakLongest}.'
            '${best == null ? '' : ' Best day ${best.count} on ${month3(best.date)} ${best.date.day}.'}',
            lines: 2,
          ),
        ]),
      );

      final up = g.weekDelta >= 0;
      final thisWeek = LqCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          lqLab('This week'),
          const SizedBox(height: 4),
          _fit(lqBig('${g.weekTotal}', 44)),
          const SizedBox(height: 4),
          Text('${up ? '+' : ''}${g.weekDelta} on last week',
              style: lqT(13.5, w: FontWeight.w600, c: up ? lqMint : lqMu), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      );

      final repos = LqCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          lqLab(topReposLabel(ref)),
          Expanded(
            child: g.topRepos.isEmpty
                ? Align(alignment: Alignment.topLeft, child: Padding(padding: const EdgeInsets.only(top: 4), child: _mu('No activity yet', size: 13)))
                : LayoutBuilder(builder: (context, c) {
                    // As many as fit (each row is ~19 px: 13 px text + 3 px gap).
                    final n = (c.maxHeight / 19).floor().clamp(1, 4);
                    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      for (final r in g.topRepos.take(n))
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Row(children: [
                            Expanded(
                              child: Text(r.name, style: lqT(13), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(width: 8),
                            Text('${r.count}', style: lqT(13, w: FontWeight.w700)),
                          ]),
                        ),
                    ]);
                  }),
          ),
        ]),
      );

      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        heat,
        const SizedBox(height: _gap),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(flex: 8, child: streak),
            const SizedBox(width: _gap),
            Expanded(flex: 10, child: thisWeek),
            const SizedBox(width: _gap),
            Expanded(flex: 10, child: repos),
          ]),
        ),
      ]);
    });
  }
}

String _thousands(int n) => n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

/// The contributions calendar: 53 week columns × 7 days, white rounded squares whose
/// opacity follows the day's level (concept `charts.heat`). Cells stay square; when the
/// card is shorter than the width asks for, the columns spread a little wider apart.
class _HeatPainter extends CustomPainter {
  _HeatPainter(this.weeks);
  final List<List<ContribDay>> weeks;

  static final _paints = [
    for (final o in const [.1, .3, .5, .75, 1.0]) Paint()..color = lqTx.withValues(alpha: o),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final ws = weeks.length > 53 ? weeks.sublist(weeks.length - 53) : weeks;
    final px = size.width / 53, py = size.height / 7;
    final cs = math.min(px, py) - 2.4;
    if (cs <= 0) return;
    final r = Radius.circular(cs / 2.6);
    final x0 = (53 - ws.length) * px; // fewer weeks: keep the newest on the right
    for (var x = 0; x < ws.length; x++) {
      for (final day in ws[x]) {
        final y = day.date.weekday % 7; // Sunday on top
        final rect = Rect.fromLTWH(x0 + x * px + (px - 2.4 - cs) / 2, y * py + (py - 2.4 - cs) / 2, cs, cs);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, r), _paints[day.level.clamp(0, 4)]);
      }
    }
  }

  @override
  bool shouldRepaint(_HeatPainter o) => o.weeks != weeks;
}

// ------------------------------------------------------------------ charts

class _Line {
  const _Line(this.values, this.color, this.width, {this.fill = false});
  final List<double?> values;
  final Color color;
  final double width;

  /// Soft white fill under the line (concept: rgba(255,255,255,.14)).
  final bool fill;
}

/// The concept's `linePath` charts: smooth lines through the samples (nulls break them),
/// fills first, then the lines in order.
class _LqChart extends StatelessWidget {
  const _LqChart(this.lines, {this.max = 100, this.pad = 2});
  final List<_Line> lines;
  final double max, pad;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _ChartPainter(lines, max, pad), size: Size.infinite);
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.lines, this.max, this.pad);
  final List<_Line> lines;
  final double max, pad;

  static final _fill = Paint()..color = const Color(0x24FFFFFF);

  /// Contiguous non-null runs of points.
  List<List<Offset>> _runs(List<double?> vals, Size size) {
    final out = <List<Offset>>[];
    if (vals.length < 2) return out;
    final dx = size.width / (vals.length - 1);
    List<Offset>? cur;
    for (var i = 0; i < vals.length; i++) {
      final v = vals[i];
      if (v == null || !v.isFinite) {
        cur = null;
        continue;
      }
      final y = pad + (size.height - 2 * pad) * (1 - v.clamp(0, max) / max);
      if (cur == null) out.add(cur = []);
      cur.add(Offset(i * dx, y));
    }
    return out;
  }

  Path _curve(List<Offset> pts) {
    final p = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1], b = pts[i], xm = (a.dx + b.dx) / 2;
      p.cubicTo(xm, a.dy, xm, b.dy, b.dx, b.dy);
    }
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || max <= 0) return;
    final runs = [for (final l in lines) _runs(l.values, size)];
    for (final (i, l) in lines.indexed) {
      if (!l.fill) continue;
      for (final r in runs[i]) {
        if (r.length < 2) continue;
        canvas.drawPath(
            _curve(r)
              ..lineTo(r.last.dx, size.height)
              ..lineTo(r.first.dx, size.height)
              ..close(),
            _fill);
      }
    }
    for (final (i, l) in lines.indexed) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = l.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = l.color;
      for (final r in runs[i]) {
        if (r.length == 1) {
          canvas.drawCircle(r.first, l.width / 2, Paint()..color = l.color);
        } else {
          canvas.drawPath(_curve(r), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_ChartPainter o) => true; // new samples arrive with every rebuild
}
