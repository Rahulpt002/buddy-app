// Concept 2 — Glow: one large serif number per page, no boxes, the glow hue carries
// meaning. Port of screens sample/deskpanel-concept-2-glow.html (sizes in CSS px).
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/conn/controller.dart';
import '../../core/pages.dart';
import '../../core/settings.dart';
import '../fmt.dart';
import '../icons.dart';
import '../pages/kit.dart';
import '../widgets/bar_tip.dart';
import '../widgets/anim.dart';
import '../widgets/art.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import 'glow.dart';

/// GlowSkin page layouts (concept glow).
Widget glowPage(PageId id) => switch (id) {
      PageId.home => const _Home(),
      PageId.system => const _System(),
      PageId.claude => const _Claude(),
      PageId.calendar => const _Calendar(),
      PageId.weather => const _Weather(),
      PageId.music => const _Music(),
      PageId.hotspot => const _Hotspot(),
      PageId.timer => const _Timer(),
      PageId.slack => const _Slack(),
      PageId.github => const _Github(),
      PageId.shortcuts => const _Shortcuts(),
    };

// ------------------------------------------------------------------ type & atoms

const _t = GlowSkin.t;
const _tx = GlowSkin.tx;
const _base = GlowSkin.base;

/// `.serif`: Fraunces Light, tight tracking, tabular lining figures.
TextStyle _serif(double size, {FontWeight w = FontWeight.w300, Color? c, double h = 1, FontStyle? style}) => TextStyle(
      fontFamily: 'Fraunces',
      fontSize: size,
      fontWeight: w,
      fontStyle: style,
      color: c ?? _tx,
      letterSpacing: -.02 * size,
      height: h,
      fontFeatures: const [ui.FontFeature.tabularFigures(), ui.FontFeature.liningFigures()],
    );

/// `.lbl`
final _lbl = _t.t(12.5, w: FontWeight.w600, c: _t.muted);
TextStyle _mu(double size, {FontWeight w = FontWeight.w500, double? h}) => _t.t(size, w: w, c: _t.muted, h: h);
TextStyle _fa(double size, {FontWeight w = FontWeight.w500}) => _t.t(size, w: w, c: _t.faint);

Color _hsl(double h, double s, double l, [double a = 1]) => HSLColor.fromAHSL(a, h % 360, s / 100, l / 100).toColor();

/// `.line`: 2px rule with a glowing fill.
Widget _line(double v, Color c, {double height = 2}) =>
    DpBar(value: v, color: c, track: _t.line, height: height, glow: true);

/// Two columns; the second is "ruled" (left hairline + 30px padding) when [ruled].
Widget _split(Widget a, Widget b, {int fa = 1, int fb = 1, bool ruled = true}) => Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: fa, child: a),
        const SizedBox(width: 34),
        Expanded(flex: fb, child: ruled ? _ruled(b) : b),
      ],
    );

Widget _ruled(Widget child, {double pad = 30}) => Container(
      decoration: BoxDecoration(border: Border(left: BorderSide(color: _t.line))),
      padding: EdgeInsets.only(left: pad),
      child: child,
    );

/// `.tabs`: words with a hue underline on the active one.
class _Tabs extends StatelessWidget {
  const _Tabs({required this.items, required this.selected, required this.onTap});
  final List<String> items;
  final int selected;
  final ValueChanged<int> onTap;
  static const gap = 20.0;

  @override
  Widget build(BuildContext context) {
    final hue = GlowHue.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (final (i, s) in items.indexed) ...[
        if (i > 0) SizedBox(width: gap),
        Press(
          onTap: () => onTap(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: i == selected ? hue : const Color(0x00000000), width: 1.5)),
            ),
            child: Text(s, style: _t.t(13, w: FontWeight.w600, c: i == selected ? _tx : _t.faint)),
          ),
        ),
      ],
    ]);
  }
}

/// `.pill` (solid) / `.pill.ghost`.
class _Pill extends StatelessWidget {
  const _Pill(this.label, {this.onTap, this.ghost = false});
  final String label;
  final VoidCallback? onTap;
  final bool ghost;
  @override
  Widget build(BuildContext context) => Press(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? .55 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
            decoration: BoxDecoration(
              color: ghost ? const Color(0x00000000) : _tx,
              borderRadius: BorderRadius.circular(99),
              border: ghost ? Border.all(color: const Color(0x4DF4EFE6)) : null,
            ),
            child: Text(label, style: _t.t(13, w: FontWeight.w700, c: ghost ? _tx : _base)),
          ),
        ),
      );
}

/// Glowing status dot (`.dot`).
Widget _dot(Color c, {double size = 9}) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: c, boxShadow: [BoxShadow(color: c, blurRadius: 10)]),
    );

/// Art with a blurred, saturated copy glowing behind it (`.cover .blur`).
Widget _glowArt(Widget art, {double radius = 18, double inset = .08, double sigma = 17, double opacity = .9}) =>
    LayoutBuilder(builder: (context, c) {
      final dx = c.maxWidth * inset, dy = c.maxHeight * inset;
      return Stack(clipBehavior: Clip.none, fit: StackFit.expand, children: [
        Positioned(
          left: dx,
          right: dx,
          top: dy,
          bottom: dy,
          child: Opacity(
            opacity: opacity,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal),
              child: art,
            ),
          ),
        ),
        ClipRRect(borderRadius: BorderRadius.circular(radius), child: art),
      ]);
    });

String _digits(Duration d) {
  final s = d.inSeconds;
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
  return h > 0 ? '$h:${two(m)}:${two(sec)}' : '${two(m)}:${two(sec)}';
}

String _inWhen(CalEvent e, DateTime now) {
  if (!e.start.isAfter(now)) return 'happening now';
  final d = e.start.difference(now);
  return d.inMinutes < 1 ? 'starting now' : 'in ${dur(d)}';
}

// ------------------------------------------------------------------ home

class _Home extends ConsumerWidget {
  const _Home();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final events = ref.watch(calendarEventsProvider);
    final wx = ref.watch(weatherProvider);
    final claude = topicData<ClaudeData>(ref, 'claude');
    final slack = slackHome(ref);
    final sys = topicData<SystemData>(ref, 'system');
    final m = topicData<MediaData>(ref, 'media');

    return Ticker(
      builder: (context, now) {
        final n = nextEvent(events, now);
        final left = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(longDate(now), style: _lbl),
          const SizedBox(height: 18),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: clock(now, h24: s.clock24), style: _serif(156, h: .82)),
              if (!s.clock24) ...[
                const WidgetSpan(child: SizedBox(width: 8)),
                TextSpan(text: ampm(now), style: _t.t(28, w: FontWeight.w600, c: _t.muted)),
              ],
            ]),
            maxLines: 1,
          ),
          const Spacer(),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text.rich(
              n == null
                  ? const TextSpan(text: 'Nothing else on your calendar today.')
                  : TextSpan(children: [
                      const TextSpan(text: 'Next up is '),
                      TextSpan(text: n.title, style: _t.t(13, w: FontWeight.w700, c: _tx)),
                      TextSpan(text: ', ${_inWhen(n, now)}.'),
                    ]),
              style: _mu(13, h: 1.4),
            ),
          ),
        ]);

        String rainNote() {
          if (wx == null) return '';
          for (final d in wx.days.skip(1)) {
            if (d.precipPct >= 50) return ' Rain likely ${weekday(d.date)}.';
          }
          return '';
        }

        final hot = sys != null && (sys.cpu.pct > 70 || (sys.gpu.tempC ?? 0) > 80);
        final rows = <Widget>[
          _glance(context, PageId.weather, wx?.now.icon ?? 'cloud',
              wx == null ? 'Weather' : '${temp(wx.now.tempC, s.fahrenheit)}° and ${wx.now.condition.toLowerCase()}',
              wx == null ? 'Set a location in Settings' : 'High ${temp(wx.days.first.hiC, s.fahrenheit)}°.${rainNote()}'),
          _glance(
              context,
              PageId.claude,
              'claude',
              claude == null ? 'Claude usage' : '${limitPct(claude.fiveHour, now).round()}% of your 5-hour limit',
              claude == null ? '—' : resetsIn(claude.fiveHour, now)),
          _glance(context, PageId.slack, 'slack', slack.headline, slack.detail,
              extra: slack.latest == null
                  ? null
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(slackTime(slack.latest!.ts, now), style: _fa(12, w: FontWeight.w600)),
                      const SizedBox(width: 12),
                      _avatar(slack.latest!, size: 34),
                    ])),
          _glance(
              context,
              PageId.system,
              'system',
              sys == null ? 'Laptop' : (hot ? 'Laptop working hard' : 'Laptop running cool'),
              sys == null
                  ? '—'
                  : 'CPU ${sys.cpu.pct.round()}%, GPU ${sys.gpu.pct == null ? 'N/A' : '${sys.gpu.pct!.round()}%'}'
                      '${sys.gpu.tempC == null ? '' : ', ${sys.gpu.tempC!.round()}°C'}'),
          _glance(context, PageId.music, 'music', m?.title ?? 'Nothing playing', m?.artist ?? '—',
              extra: m?.title == null
                  ? null
                  : Press(
                      onTap: () => act(context, ref, 'media.play_pause'),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle, border: Border.all(color: const Color(0x4DF4EFE6))),
                        alignment: Alignment.center,
                        child: DpIcon(m!.playing ? 'pause' : 'play', size: 13, color: _tx),
                      ),
                    )),
        ];
        return _split(
          left,
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (final (i, r) in rows.indexed)
              Container(
                decoration: BoxDecoration(
                    border: i == rows.length - 1 ? null : Border(bottom: BorderSide(color: _t.line))),
                child: r,
              ),
          ]),
          fa: 105,
          fb: 100,
        );
      },
    );
  }

  Widget _glance(BuildContext context, PageId p, String icon, String title, String sub, {Widget? extra}) => Press(
        onTap: () => PageNav.go(context, p),
        scale: .99,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(children: [
            SizedBox(width: 22, child: DpIcon(icon, size: 19, color: _t.muted)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _t.t(15, w: FontWeight.w600)),
                Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: _mu(12.5)),
              ]),
            ),
            if (extra != null) ...[const SizedBox(width: 14), extra],
          ]),
        ),
      );
}

// ------------------------------------------------------------------ system

class _System extends ConsumerWidget {
  const _System();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(systemTabProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Tabs(
          items: const ['Laptop', 'Internet'],
          selected: tab,
          onTap: (i) => ref.read(systemTabProvider.notifier).set(i)),
      const SizedBox(height: 14),
      Expanded(child: tab == 0 ? const _Laptop() : const _Internet()),
    ]);
  }
}

class _Laptop extends ConsumerWidget {
  const _Laptop();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = topicData<SystemData>(ref, 'system')!;
    final g = s.gpu;
    final ramPct = s.ramUsed / s.ramTotal * 100;
    final vramPct = g.vramUsed != null && g.vramTotal != null && g.vramTotal! > 0 ? g.vramUsed! / g.vramTotal! * 100 : null;
    final down = rate(s.downBps), up = rate(s.upBps);
    final vLabel = g.vramLabel == 'VRAM' ? 'Video memory' : 'GPU memory';

    Widget metric(String label, double? pct, Color c, String sub) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: _lbl),
            const SizedBox(height: 4),
            pct == null
                ? Text('N/A', style: _serif(66, h: .9))
                : Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                    AnimNum(pct, style: _serif(66, h: .9)),
                    const SizedBox(width: 2),
                    Text('%', style: _t.t(20, w: FontWeight.w600, c: _t.muted)),
                  ]),
            const SizedBox(height: 10),
            _line((pct ?? 0) / 100, c),
            const SizedBox(height: 8),
            Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: _mu(12)),
          ],
        );

    final cpuC = _hsl(205, 95, 72), gpuC = _hsl(170, 75, 62);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final (i, w) in [
          metric('Processor', s.cpu.pct, cpuC,
              s.cpu.cores != null ? '${s.cpu.cores} cores, ${s.cpu.threads ?? s.cpu.cores} threads' : s.cpu.model),
          metric('Graphics', g.available ? g.pct : null, gpuC,
              g.tempC != null ? '${g.tempC!.round()}°C' : (g.model ?? 'Not available')),
          metric('Memory', ramPct, _hsl(262, 90, 78),
              '${(s.ramUsed / 1073741824).toStringAsFixed(1)} of ${(s.ramTotal / 1073741824).round()} GB'),
          metric(vLabel, vramPct, _hsl(330, 85, 74),
              vramPct == null ? 'Not available' : '${(g.vramUsed! / 1073741824).toStringAsFixed(1)} of ${(g.vramTotal! / 1073741824).round()} GB'),
        ].indexed) ...[
          if (i > 0) const SizedBox(width: 24),
          Expanded(child: w),
        ],
      ]),
      const SizedBox(height: 14),
      Expanded(
        child: LineChart(
          pad: 6,
          series: [
            LineSeries(s.gpuHistory, gpuC, glow: true),
            LineSeries(s.cpuHistory, cpuC, glow: true),
          ],
        ),
      ),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(
          child: Text(
              '${s.cpu.model}${g.model == null ? '' : ' with ${g.model}'}. Disk ${s.diskPct.round()}% full.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _fa(12)),
        ),
        Text('${down.$1} ${down.$2} down, ${up.$1} ${up.$2} up', style: _fa(12)),
      ]),
      const SizedBox(height: 4),
    ]);
  }
}

class _Internet extends ConsumerWidget {
  const _Internet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = topicData<NetworkData>(ref, 'network');
    final sys = topicData<SystemData>(ref, 'system');
    if (n == null) {
      return Center(child: Text('Waiting for network data from the laptop…', style: _mu(14)));
    }
    final st = n.speedtest;
    final prog = st.progress;
    final down = st.running ? (prog?.downBps ?? 0) : (st.last?.downBps ?? 0);
    final up = st.running ? (prog?.upBps ?? 0) : (st.last?.upBps ?? 0);
    final hue = GlowHue.of(context);

    return Ticker(builder: (context, now) {
      final loss = n.lossPct == 0 ? 'no packet loss' : '${n.lossPct.toStringAsFixed(n.lossPct < 10 ? 1 : 0)}% packet loss';
      final col1 = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Latency', style: _lbl),
        const SizedBox(height: 6),
        n.latencyMs == null
            ? Text('—', style: _serif(92, h: .85))
            : Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                AnimNum(n.latencyMs!, style: _serif(92, h: .85)),
                const SizedBox(width: 4),
                Text('ms', style: _t.t(22, w: FontWeight.w600, c: _t.muted)),
              ]),
        const SizedBox(height: 12),
        Text('Jitter ${n.jitterMs?.toStringAsFixed(1) ?? '—'} ms, $loss', style: _mu(13)),
      ]);
      final col2 = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Connection', style: _lbl),
        const SizedBox(height: 8),
        Row(children: [
          _dot(n.online ? _t.ok : _t.bad),
          const SizedBox(width: 10),
          Text(n.online ? 'Online' : 'Offline', style: _serif(40)),
        ]),
        const SizedBox(height: 10),
        Text(
          '${n.online && n.onlineSince != null ? 'Up for ${durLong(now.difference(n.onlineSince!))}.' : 'Down right now.'}\n'
          'Last drop ${n.lastDrop == null ? 'never seen' : ago(now.difference(n.lastDrop!))}.',
          style: _mu(13, h: 1.4),
        ),
        const SizedBox(height: 14),
        Text('${bytes(n.usageToday)} today\n${bytes(n.usageMonth, digits: 0)} this month', style: _mu(13, h: 1.4)),
      ]);
      final col3 = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Speed test', style: _lbl),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(mbps(down), style: _serif(40)),
          const SizedBox(width: 3),
          Text('down', style: _t.t(14, w: FontWeight.w600, c: _t.muted)),
          const SizedBox(width: 18),
          Text(mbps(up), style: _serif(40)),
          const SizedBox(width: 3),
          Text('up', style: _t.t(14, w: FontWeight.w600, c: _t.muted)),
        ]),
        const SizedBox(height: 6),
        Text(
          st.running
              ? 'Testing ${prog?.phase ?? ''}…'
              : st.last == null
                  ? 'Not tested yet'
                  : 'Tested ${ago(now.difference(st.last!.at))}, ping ${st.last!.pingMs.round()} ms',
          style: _mu(12),
        ),
        const SizedBox(height: 14),
        _Pill(st.running ? 'Testing…' : 'Run test',
            ghost: true,
            onTap: st.running
                ? null
                : () => act(context, ref, 'speedtest.run', const {}, null, null, const Duration(seconds: 90))),
        if (st.running) ...[
          const SizedBox(height: 12),
          _line((prog?.pct ?? 0) / 100, hue),
        ],
      ]);
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(flex: 115, child: Padding(padding: const EdgeInsets.only(right: 24), child: col1)),
            Expanded(flex: 100, child: _ruled(Padding(padding: const EdgeInsets.only(right: 24), child: col2), pad: 24)),
            Expanded(flex: 100, child: _ruled(col3, pad: 24)),
          ]),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: LineChart(
            min: 0,
            max: 50,
            pad: 6,
            series: [LineSeries(n.latencyHistory, _hsl(178, 80, 66), width: 1.6, glow: true)],
          ),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: Text('Latency over the last 2 minutes', style: _fa(12))),
          if (sys != null)
            Text('Right now ${mbps(sys.downBps)} down, ${mbps(sys.upBps)} up (Mbps)', style: _fa(12)),
        ]),
        const SizedBox(height: 4),
      ]);
    });
  }
}

// ------------------------------------------------------------------ claude

class _Claude extends ConsumerWidget {
  const _Claude();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = topicData<ClaudeData>(ref, 'claude')!;
    final s = ref.watch(settingsProvider);
    return Ticker(builder: (context, now) {
      final five = limitPct(c.fiveHour, now), week = limitPct(c.sevenDay, now);
      final mx = maxOf(c.days.map((d) => d.tokens));
      final peak = c.days.isEmpty ? 0 : c.days.map((d) => d.tokens).reduce(math.max);

      final left = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('5-hour limit', style: _lbl),
        const SizedBox(height: 14),
        c.fiveHour == null
            ? Text('—', style: _serif(150, h: .8))
            : Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                AnimNum(five, style: _serif(150, h: .8)),
                Text('%', style: _serif(40, c: _t.muted, h: .8)),
              ]),
        const SizedBox(height: 16),
        _line(five / 100, _hsl(16, 95, 70)),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(children: [
            if (c.fiveHour != null && c.fiveHour!.resetsAt != null && !c.fiveHour!.isExpired(now)) ...[
              const TextSpan(text: 'Resets in '),
              TextSpan(text: dur(c.fiveHour!.resetsAt!.difference(now)), style: _t.t(14, c: _tx)),
            ] else
              TextSpan(text: resetsIn(c.fiveHour, now)),
          ]),
          style: _mu(14),
        ),
        const Spacer(),
        Row(children: [
          Text('Weekly limit', style: _lbl),
          const Spacer(),
          Text(c.sevenDay == null ? '—' : '${week.round()}%', style: _t.t(12.5, w: FontWeight.w600, c: _tx)),
        ]),
        const SizedBox(height: 8),
        _line(week / 100, _hsl(38, 95, 66)),
        const SizedBox(height: 8),
        Text(resetsAt(c.sevenDay, now, h24: s.clock24), style: _fa(12)),
      ]);

      final kv = Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        for (final (k, v) in [
          ('Tokens today', compact(c.tokens)),
          ('Output', compact(c.outputTokens)),
          ('Messages', '${c.messages}'),
          ('Last hour', compact(c.lastHourTokens)),
        ])
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(v, style: _serif(24, w: FontWeight.w400, h: 1.15)),
            Text(k, style: _mu(11.5)),
          ]),
      ]);

      final bars = BarTapTip(count: c.days.length, label: (i) => dayTokensLabel(c.days[i], now), child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final (i, d) in c.days.indexed)
          Expanded(
            child: LayoutBuilder(builder: (context, box) {
              final today = i == c.days.length - 1;
              final h = math.max(4.0, (box.maxHeight - 22) * d.tokens / mx);
              return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(end: h),
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => Container(
                    width: today ? 12 : 8,
                    height: v,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [_hsl(16, 95, 72), _hsl(16, 70, 45, .5)],
                      ),
                      boxShadow: today ? [BoxShadow(color: _hsl(16, 95, 65, .8), blurRadius: 14)] : null,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(dayLabel(d.date, now),
                    style: today ? _t.t(11, w: FontWeight.w700, c: _tx) : _fa(11)),
              ]);
            }),
          ),
      ]));

      final models = Row(children: [
        for (final m in c.modelsToday.take(3)) ...[
          Text.rich(TextSpan(children: [
            TextSpan(text: modelName(m.family), style: _t.t(12.5, w: FontWeight.w600, c: _tx)),
            TextSpan(text: '  ${compact(m.tokens)}'),
          ]), style: _mu(12.5)),
          const SizedBox(width: 22),
        ],
        const Spacer(),
        Text('Peak ${compact(peak)}', style: _mu(12.5)),
      ]);

      return _split(
        left,
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          kv,
          const SizedBox(height: 12),
          Expanded(child: bars),
          const SizedBox(height: 4),
          models,
        ]),
        fa: 90,
        fb: 120,
      );
    });
  }
}

// ------------------------------------------------------------------ calendar

class _Calendar extends ConsumerWidget {
  const _Calendar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(calendarEventsProvider);
    final s = ref.watch(settingsProvider);
    return Ticker(builder: (context, now) {
      final split = splitEvents(all, now);
      final n = nextEvent(all, now);
      final hue = GlowHue.of(context);

      final left = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(n != null ? 'Next up' : 'Today', style: _lbl),
        const SizedBox(height: 12),
        Text(n?.title ?? 'All clear', maxLines: 2, overflow: TextOverflow.ellipsis, style: _serif(46, h: 1.05)),
        if (n != null) ...[
          const SizedBox(height: 10),
          Text(_inWhen(n, now), style: _serif(24, w: FontWeight.w400, c: hue, style: FontStyle.italic)),
          const SizedBox(height: 10),
          Text(
            '${clockFull(n.start, h24: s.clock24)} to ${clockFull(n.end, h24: s.clock24)}'
            '${n.location == null ? '' : ', ${n.location}'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _mu(14),
          ),
        ],
        const Spacer(),
        Text('Later this week', style: _lbl),
        const SizedBox(height: 4),
        if (split.later.isEmpty)
          Text('Nothing else in the next 7 days', style: _mu(12.5))
        else
          for (final e in split.later.take(4))
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Row(children: [
                SizedBox(width: 100, child: Text(weekday(e.start), style: _mu(12.5))),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: e.title, style: _t.t(12.5, w: FontWeight.w600, c: _tx)),
                      TextSpan(text: ', ${e.allDay ? 'all day' : clockFull(e.start, h24: s.clock24)}'),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _mu(12.5),
                  ),
                ),
              ]),
            ),
      ]);

      return _split(left, _Timeline(events: split.today, now: now, h24: s.clock24, hue: hue), ruled: false);
    });
  }
}

/// Day timeline (`.tl`): hour labels every 2h, event blocks, a glowing "now" line.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.events, required this.now, required this.h24, required this.hue});
  final List<CalEvent> events;
  final DateTime now;
  final bool h24;
  final Color hue;

  @override
  Widget build(BuildContext context) {
    final timed = events.where((e) => !e.allDay).toList();
    double hourOf(DateTime d) => d.hour + d.minute / 60;
    var h0 = 8.0, h1 = 18.0;
    for (final e in timed) {
      h0 = math.min(h0, hourOf(e.start).floorToDouble());
      h1 = math.max(h1, math.min(24, hourOf(e.end).ceilToDouble()));
    }
    h0 = math.min(h0, now.hour.toDouble());
    h1 = math.max(h1, math.min(24, now.hour + 1.0));
    if (h0 % 2 != 0) h0 -= 1;
    if (h1 % 2 != 0) h1 = math.min(24, h1 + 1);
    final span = h1 - h0;

    return LayoutBuilder(builder: (context, c) {
      const left = 46.0;
      final h = c.maxHeight - 12;
      double y(double hour) => 6 + (hour - h0) / span * h;
      final children = <Widget>[
        Positioned(left: left, top: 0, bottom: 0, child: Container(width: 1, color: _t.line)),
      ];
      for (var hr = h0; hr <= h1; hr += 2) {
        final hh = hr.toInt() % 24;
        final label = h24 ? '${two(hh)}:00' : '${hh % 12 == 0 ? 12 : hh % 12} ${hh < 12 ? 'AM' : 'PM'}';
        children.add(Positioned(
          left: 0,
          width: 38,
          top: y(hr) - 7,
          child: Text(label, textAlign: TextAlign.right, style: _fa(11)),
        ));
      }
      for (final e in timed) {
        final top = y(hourOf(e.start));
        final bottom = y(math.min(h1, hourOf(e.end) + (e.end.day != e.start.day ? 24 : 0)));
        final col = hex(e.color, hue);
        final done = e.end.isBefore(now);
        children.add(Positioned(
          left: left + 14,
          right: 0,
          top: top,
          child: Opacity(
            opacity: done ? .45 : 1,
            child: Container(
              height: math.max(26, bottom - top),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: col.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(10),
                border: Border(left: BorderSide(color: col, width: 3)),
              ),
              alignment: Alignment.centerLeft,
              child: Row(children: [
                Flexible(
                  child: Text(e.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: _t.t(12.5, w: FontWeight.w600)),
                ),
                const SizedBox(width: 10),
                Text(clockFull(e.start, h24: h24), style: _mu(12.5)),
              ]),
            ),
          ),
        ));
      }
      final ny = y(hourOf(now));
      children.add(Positioned(
        left: left - 4,
        right: 0,
        top: ny - .75,
        child: Row(children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: hue)),
          Expanded(
            child: Container(
              height: 1.5,
              decoration: BoxDecoration(color: hue, boxShadow: [BoxShadow(color: hue, blurRadius: 8)]),
            ),
          ),
        ]),
      ));
      if (timed.isEmpty) {
        children.add(Positioned(
          left: left + 14,
          top: h / 2 - 10,
          child: Text('Nothing scheduled today', style: _mu(13)),
        ));
      }
      return Stack(clipBehavior: Clip.none, children: children);
    });
  }
}

// ------------------------------------------------------------------ weather

class _Weather extends ConsumerWidget {
  const _Weather();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(weatherProvider);
    final s = ref.watch(settingsProvider);
    if (w == null) {
      return Center(child: Text('Choose a weather location in Settings.', style: _mu(14)));
    }
    final f = s.fahrenheit;
    final lo = w.days.map((d) => temp(d.loC, f)).reduce(math.min);
    final hi = w.days.map((d) => temp(d.hiC, f)).reduce(math.max);
    final now = DateTime.now();

    final left = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(w.place, style: _lbl),
      const SizedBox(height: 8),
      Text('${temp(w.now.tempC, f)}°', style: _serif(132, h: .8)),
      const SizedBox(height: 12),
      Text(w.now.condition, style: _t.t(17, h: 1.2)),
      const SizedBox(height: 4),
      Text(
        'Feels like ${temp(w.now.feelsC, f)}°. Humidity ${w.now.humidity}%. Wind ${wind(w.now.windKmh, f)}.',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _mu(13, h: 1.3),
      ),
    ]);

    final days = Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      for (final d in w.days)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 1.5),
          child: Row(children: [
            SizedBox(width: 50, child: Text(dayLabel(d.date, now), style: _t.t(13))),
            const SizedBox(width: 10),
            SizedBox(width: 22, child: DpIcon(d.icon, size: 17, color: _t.muted)),
            const SizedBox(width: 10),
            SizedBox(
              width: 38,
              child: Text(d.precipPct > 0 ? '${d.precipPct}%' : '',
                  style: _t.t(11.5, c: _hsl(205, 90, 75))),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 28,
              child: Text('${temp(d.loC, f)}°', textAlign: TextAlign.right, style: _mu(13)),
            ),
            const SizedBox(width: 10),
            Expanded(child: _Range(a: (temp(d.loC, f) - lo) / math.max(1, hi - lo), b: (temp(d.hiC, f) - lo) / math.max(1, hi - lo))),
            const SizedBox(width: 10),
            SizedBox(width: 28, child: Text('${temp(d.hiC, f)}°', style: _t.t(13))),
          ]),
        ),
    ]);

    return LayoutBuilder(builder: (context, c) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: c.maxHeight * .58,
          child: _split(left, days, fa: 100, fb: 105, ruled: false),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: CustomPaint(
            painter: _TempCurve(
              [for (final h in w.hours) temp(h.tempC, f).toDouble()],
              [for (final (i, h) in w.hours.indexed) i == 0 ? 'Now' : (s.clock24 ? '${two(h.time.hour)}:00' : '${h.time.hour % 12 == 0 ? 12 : h.time.hour % 12} ${ampm(h.time)}')],
            ),
          ),
        ),
      ]);
    });
  }
}

/// Day range bar: the low→high span on a shared week scale (`.rng`).
class _Range extends StatelessWidget {
  const _Range({required this.a, required this.b});
  final double a, b;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 4,
        child: LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth;
          return Stack(children: [
            Container(decoration: BoxDecoration(color: _t.line, borderRadius: BorderRadius.circular(4))),
            Positioned(
              left: w * a.clamp(0, 1),
              width: math.max(4, w * (b - a).clamp(0, 1)),
              top: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: LinearGradient(colors: [_hsl(200, 80, 70), _hsl(40, 95, 68)]),
                ),
              ),
            ),
          ]);
        }),
      );
}

/// Next-12-hours temperature curve with serif values over each point.
class _TempCurve extends CustomPainter {
  _TempCurve(this.vals, this.labels);
  final List<double> vals;
  final List<String> labels;

  @override
  void paint(Canvas canvas, Size size) {
    if (vals.length < 2) return;
    final w = size.width, h = size.height;
    final n = vals.length;
    final lo = vals.reduce(math.min) - 3, hi = vals.reduce(math.max) + 2;
    final pw = w - 40, top = 22.0, ch = h - 44;
    double x(int i) => 20 + i * pw / (n - 1);
    double y(double v) => top + ch * (1 - (v - lo) / (hi - lo));
    final p = Path()..moveTo(x(0), y(vals[0]));
    for (var i = 1; i < n; i++) {
      final xm = (x(i - 1) + x(i)) / 2;
      p.cubicTo(xm, y(vals[i - 1]), xm, y(vals[i]), x(i), y(vals[i]));
    }
    final c = _hsl(205, 90, 72);
    canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = c.withValues(alpha: .15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = c);
    void text(String s, TextStyle st, double cx, double baseline) {
      final tp = TextPainter(text: TextSpan(text: s, style: st), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, baseline - tp.computeDistanceToActualBaseline(TextBaseline.alphabetic)));
    }

    for (var i = 0; i < n; i++) {
      final cx = x(i), cy = y(vals[i]);
      canvas.drawCircle(Offset(cx, cy), i == 0 ? 4 : 2.2, Paint()..color = i == 0 ? _hsl(205, 95, 80) : _tx);
      text('${vals[i].round()}°', _serif(15, w: FontWeight.w400), cx, cy - 10);
      text(labels[i], _t.t(11, w: FontWeight.w600, c: _t.muted), cx, h - 2);
    }
  }

  @override
  bool shouldRepaint(_TempCurve o) => o.vals != vals;
}

// ------------------------------------------------------------------ music

class _Music extends ConsumerWidget {
  const _Music();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = topicData<MediaData>(ref, 'media')!;
    final art = topicData<MediaArt>(ref, 'media.art');
    final skew = ref.read(agentProvider.notifier).clockSkewMs;
    if (m.title == null) {
      return Center(child: Text('Nothing playing on the laptop', style: _serif(34, w: FontWeight.w400)));
    }
    final title = m.title!;
    final b64 = art != null && art.artId == m.artId ? art.b64 : null;
    final cover = AlbumArt(title: title, b64: b64);

    return LayoutBuilder(builder: (context, c) {
      final side = math.min(c.maxHeight * .96, 300.0);
      return Row(children: [
        SizedBox(width: side, height: side, child: _glowArt(cover)),
        const SizedBox(width: 36),
        Expanded(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Playing on ${m.source ?? 'your laptop'}', style: _lbl),
            const SizedBox(height: 8),
            Text(title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _serif(42, w: FontWeight.w400, h: 1.02)),
            const SizedBox(height: 8),
            if (m.artist != null) Text(m.artist!, maxLines: 1, overflow: TextOverflow.ellipsis, style: _t.t(16, w: FontWeight.w600)),
            if (m.album != null) Text(m.album!, maxLines: 1, overflow: TextOverflow.ellipsis, style: _mu(13)),
            const SizedBox(height: 22),
            Ticker(
              period: const Duration(seconds: 1),
              builder: (context, now) {
                final pos = m.positionNow(now, skewMs: skew);
                final len = m.durationMs ?? 0;
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _Seek(
                    value: len == 0 ? 0 : pos / len,
                    enabled: m.canSeek && len > 0,
                    onSeek: (f) => act(context, ref, 'media.seek', {'position_ms': (f * len).round()}),
                  ),
                  Row(children: [
                    Text(mmss(pos), style: _mu(11.5)),
                    const Spacer(),
                    Text(len == 0 ? '' : '-${mmss(len - pos)}', style: _mu(11.5)),
                  ]),
                ]);
              },
            ),
            const SizedBox(height: 18),
            Row(children: [
              Press(
                onTap: () => act(context, ref, 'media.prev'),
                child: Padding(padding: const EdgeInsets.all(6), child: DpIcon('prev', size: 20, color: _t.muted)),
              ),
              const SizedBox(width: 20),
              Press(
                onTap: () => act(context, ref, 'media.play_pause'),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: _tx),
                  alignment: Alignment.center,
                  child: DpIcon(m.playing ? 'pause' : 'play', size: 24, color: _base),
                ),
              ),
              const SizedBox(width: 20),
              Press(
                onTap: () => act(context, ref, 'media.next'),
                child: Padding(padding: const EdgeInsets.all(6), child: DpIcon('next', size: 20, color: _t.muted)),
              ),
            ]),
          ]),
        ),
      ]);
    });
  }
}

/// Seek line with a generous touch target; tap or drag to seek.
class _Seek extends StatefulWidget {
  const _Seek({required this.value, required this.onSeek, required this.enabled});
  final double value;
  final bool enabled;
  final ValueChanged<double> onSeek;
  @override
  State<_Seek> createState() => _SeekState();
}

class _SeekState extends State<_Seek> {
  double? _drag;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        double f(Offset p) => (p.dx / c.maxWidth).clamp(0.0, 1.0);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: widget.enabled ? (d) => widget.onSeek(f(d.localPosition)) : null,
          onHorizontalDragUpdate: widget.enabled ? (d) => setState(() => _drag = f(d.localPosition)) : null,
          onHorizontalDragEnd: widget.enabled
              ? (_) {
                  if (_drag != null) widget.onSeek(_drag!);
                  setState(() => _drag = null);
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: _line(_drag ?? widget.value, _tx),
          ),
        );
      });
}

// ------------------------------------------------------------------ hotspot

/// The Hotspot Monitor Overview (the roof phone sharing mobile data).
class _Hotspot extends ConsumerWidget {
  const _Hotspot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = topicData<HotspotData>(ref, 'hotspot')!;
    final f = ref.watch(settingsProvider).fahrenheit;
    return Ticker(builder: (context, now) {
      final alert = hsAlert(d, now);
      final note = hsSessionNote(d, now);
      final stateC = hsStateColor(d, _t);
      final gc = hsGradeColor(d.grade, _t);
      final foot = [d.name, d.model].whereType<String>().join(' · ');

      final left = LayoutBuilder(builder: (context, c) {
        final roomy = c.maxHeight >= 300;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _dot(stateC),
            const SizedBox(width: 10),
            Flexible(
              child: Text(hsStateLabel(d),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: _t.t(15, w: FontWeight.w700, c: stateC)),
            ),
            const SizedBox(width: 10),
            Text(hsSeen(d, now), style: _mu(12.5)),
          ]),
          const SizedBox(height: 14),
          Text('Signal score', style: _lbl),
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(d.score == null ? '—' : '${d.score!.round()}', style: _serif(roomy ? 104 : 88, h: .86)),
            const SizedBox(width: 6),
            Text('/100', style: _t.t(20, w: FontWeight.w600, c: _t.muted)),
            const SizedBox(width: 12),
            Flexible(
              child: Text(hsGradeLabel(d.grade),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _serif(26, w: FontWeight.w400, c: gc, style: FontStyle.italic)),
            ),
          ]),
          const SizedBox(height: 10),
          _line((d.score ?? 0) / 100, gc),
          const SizedBox(height: 8),
          Text(hsSignalLine(d), maxLines: 1, overflow: TextOverflow.ellipsis, style: _mu(12)),
          const Spacer(),
          if (alert != null) ...[
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(top: 5), child: _dot(_t.bad, size: 7)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(alert,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _t.t(13.5, w: FontWeight.w600, c: _t.bad, h: 1.35)),
              ),
            ]),
            const SizedBox(height: 10),
          ],
          Text(
            '${hsNetwork(d)}${d.operator == null ? '' : ' on ${d.operator}'}.\n${hsSharing(d)}.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _t.t(13.5, w: FontWeight.w600, h: 1.4),
          ),
          if ((foot.isNotEmpty || note != null) && (alert == null || roomy)) ...[
            const SizedBox(height: 6),
            Text.rich(
              TextSpan(children: [
                if (note != null) TextSpan(text: note, style: _t.t(12, w: FontWeight.w600, c: _t.warn)),
                if (note != null && foot.isNotEmpty) const TextSpan(text: ' · '),
                TextSpan(text: foot),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _fa(12),
            ),
          ],
          const SizedBox(height: 4),
        ]);
      });

      final (rx, rxU) = hsBpsParts(d.rxBps);
      final (used, usedU) = hsBytesParts(d.cycleUsed);
      final q = d.quotaFrac;
      final qc = q == null ? null : (q >= 1 ? _t.bad : (q >= .8 ? _t.warn : GlowHue.of(context)));
      final heatC = switch (d.heat) {
        HotspotHeat.hot => _t.bad,
        HotspotHeat.warm => _t.warn,
        HotspotHeat.ok => null,
      };
      final ma = d.currentMa;

      final right = LayoutBuilder(builder: (context, c) {
        // Five metric rows, then as many events as fit below them.
        final rowH = c.maxHeight >= 320 ? 46.0 : 42.0;
        final evH = c.maxHeight - rowH * 5 - 30;
        final nEv = math.max(0, math.min(d.events.length, (evH / 22).floor()));
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _hsRow(rowH, 'Speed now', rx, '$rxU down', '${hsBps(d.txBps)} up\n${hsPingLine(d)}'),
          _hsRow(rowH, 'Battery', d.batteryPct == null ? '—' : '${d.batteryPct!.round()}', '%',
              '${hsCurrent(ma)}\n${hsPowerLine(d)}',
              color: d.lowBattery ? _t.bad : null),
          _hsRow(
            rowH,
            'Temperature',
            hsTemp(d.batteryC, fahrenheit: f),
            'battery',
            hsHeatLine(d, fahrenheit: f),
            color: heatC,
            badge: d.radioResting ? 'Radio resting' : null,
          ),
          _hsRow(rowH, 'Data this cycle', used, usedU,
              '${q == null ? 'No quota set' : '${(q * 100).round()}% of ${hsBytes(d.quota)}'}\n${hsTodayLine(d)}',
              fill: q, fillColor: qc),
          _hsRow(rowH, 'Uptime', hsUptime(d.uptimeS), 'phone', 'Agent ${hsUptime(d.agentUptimeS)}\n${hsBootLine(d)}',
              last: true),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Text('Latest events', style: _lbl)),
            if (d.events.isNotEmpty && nEv < d.events.length) Text('${d.events.length} recent', style: _fa(12)),
          ]),
          const SizedBox(height: 2),
          if (d.events.isEmpty)
            Padding(padding: const EdgeInsets.only(top: 4), child: Text('Nothing has happened lately.', style: _mu(12.5)))
          else
            for (final e in d.events.take(nEv))
              SizedBox(
                height: 22,
                child: Row(children: [
                  SizedBox(width: 34, child: Text(slackTime(e.ts, now), style: _fa(12, w: FontWeight.w600))),
                  e.severity == 'info' ? const SizedBox(width: 7) : _dot(hsEventColor(e, _t), size: 6),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(e.message,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: e.severity == 'info'
                            ? _t.t(13, w: FontWeight.w500)
                            : _t.t(13, w: FontWeight.w600, c: hsEventColor(e, _t))),
                  ),
                ]),
              ),
        ]);
      });

      return _split(left, right, fa: 100, fb: 150);
    });
  }

  /// One metric row: label, serif value + unit (an optional glowing fill under it), two muted lines.
  Widget _hsRow(double h, String label, String value, String unit, String detail,
          {Color? color, String? badge, double? fill, Color? fillColor, bool last = false}) =>
      Container(
        height: h,
        decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: _t.line))),
        child: Row(children: [
          SizedBox(width: 100, child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _lbl)),
          SizedBox(
            width: 140,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Flexible(
                  child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: _serif(28, c: color, h: 1)),
                ),
                SizedBox(width: unit == '%' ? 2 : 5),
                Text(unit, style: _t.t(12, w: FontWeight.w600, c: _t.muted)),
              ]),
              if (fill != null) ...[
                const SizedBox(height: 4),
                SizedBox(width: 120, child: _line(fill.clamp(0, 1).toDouble(), fillColor ?? _tx)),
              ],
            ]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: badge != null
                ? Row(children: [
                    _dot(_t.bad, size: 7),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text('$badge. ${detail.replaceAll('\n', ' · ')}',
                          maxLines: 2, overflow: TextOverflow.ellipsis, style: _t.t(12, w: FontWeight.w600, c: _t.bad, h: 1.3)),
                    ),
                  ])
                : Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: _mu(12, h: 1.3)),
          ),
        ]),
      );
}

// ------------------------------------------------------------------ timer

class _Timer extends ConsumerWidget {
  const _Timer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(timerProvider);
    final ctl = ref.read(timerProvider.notifier);
    final hue = GlowHue.of(context);
    final label = st.running ? 'Pause' : (st.pristine ? 'Start' : 'Resume');

    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      _Tabs(
        items: [for (final m in TimerMode.values) m.label],
        selected: st.mode.index,
        onTap: (i) => ctl.setMode(TimerMode.values[i]),
      ),
      const SizedBox(height: 12),
      Ticker(
        period: const Duration(milliseconds: 250),
        builder: (context, now) => Column(children: [
          Text(_digits(st.display(now)), style: _serif(172, h: .82)),
          const SizedBox(height: 18),
          FractionallySizedBox(widthFactor: .6, child: _line(st.progress(now), hue)),
        ]),
      ),
      const SizedBox(height: 20),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (st.mode == TimerMode.countdown && !st.running) ...[
          _Pill('−1 min', ghost: true, onTap: () => ctl.adjust(-1)),
          const SizedBox(width: 12),
        ],
        _Pill(label, onTap: ctl.toggle),
        const SizedBox(width: 12),
        _Pill('Reset', ghost: true, onTap: ctl.reset),
        if (st.mode == TimerMode.countdown && !st.running) ...[
          const SizedBox(width: 12),
          _Pill('+1 min', ghost: true, onTap: () => ctl.adjust(1)),
        ],
      ]),
      const SizedBox(height: 14),
      Text('${math.min(st.sessions, 99)} of 4 focus sessions done today', style: _fa(12)),
    ]);
  }
}

// ------------------------------------------------------------------ slack

/// Sender avatar: a softly glowing tinted disc with initials in the sender's colour.
Widget _avatar(SlackMsg m, {double size = 30, bool glow = true}) {
  final c = hex(m.senderColor, _t.cpu);
  final hsl = HSLColor.fromColor(c);
  final ink = hsl.withLightness(math.max(hsl.lightness, .74)).withSaturation(math.min(hsl.saturation, .9)).toColor();
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: c.withValues(alpha: .22),
      border: Border.all(color: c.withValues(alpha: .55)),
      boxShadow: glow ? [BoxShadow(color: c.withValues(alpha: .35), blurRadius: size * .45)] : null,
    ),
    alignment: Alignment.center,
    child: Text(m.initials, style: _t.t(size * .36, w: FontWeight.w700, c: ink, h: 1)),
  );
}

class _Slack extends ConsumerWidget {
  const _Slack();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = topicData<SlackData>(ref, 'slack')!;
    final unread = s.unreadMessages;
    final hero = unread.isEmpty ? null : unread.first;
    final rest = s.messages.where((m) => m != hero).toList();

    return Ticker(builder: (context, now) {
      final hue = GlowHue.of(context);
      final left = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.team == null ? 'Slack' : 'Slack in ${s.team}', style: _lbl),
        const SizedBox(height: 14),
        if (hero == null) ...[
          Text('All caught up.', maxLines: 2, overflow: TextOverflow.ellipsis, style: _serif(58, h: 1)),
          const SizedBox(height: 12),
          Text(
            s.messages.isEmpty ? 'No new messages. Enjoy the quiet.' : 'Nothing unread. Tap a message to open it in Slack.',
            style: _mu(13, h: 1.4),
          ),
          const Spacer(),
        ] else ...[
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text('${s.unread}', style: _serif(120, h: .82)),
            const SizedBox(width: 10),
            Text('unread', style: _t.t(24, w: FontWeight.w600, c: _t.muted)),
          ]),
          const Spacer(),
          Press(
            onTap: () => slackOpen(context, ref, hero),
            scale: .99,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _avatar(hero, size: 28),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(hero.sender,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: _t.t(14, w: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${slackWhere(hero)}, ${slackTime(hero.ts, now)}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: _mu(12.5)),
                ),
                SlackReadTick(hero, fill: _t.accent),
              ]),
              const SizedBox(height: 8),
              Text('“${hero.text}”',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _serif(21, w: FontWeight.w400, h: 1.25, style: FontStyle.italic)),
            ]),
          ),
          const SizedBox(height: 14),
          Row(children: [
            _Pill('Open in Slack', onTap: () => slackOpen(context, ref, hero)),
            const SizedBox(width: 10),
            _Pill('Mark all read', ghost: true, onTap: () => slackReadAll(context, ref)),
          ]),
          const SizedBox(height: 4),
        ],
      ]);

      final right = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(hero == null ? 'Recent' : 'Earlier', style: _lbl)),
          if (rest.isNotEmpty) Text('${rest.length} ${rest.length == 1 ? 'message' : 'messages'}', style: _fa(12)),
        ]),
        const SizedBox(height: 4),
        Expanded(
          child: rest.isEmpty
              ? Center(child: Text(hero == null ? 'No new messages' : 'Nothing else waiting', style: _mu(13)))
              : ShaderMask(
                  // Rows dissolve into the glow at the bottom edge instead of being cut off.
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (r) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF)],
                    stops: [0, .84, 1],
                  ).createShader(r),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 28),
                    itemCount: rest.length,
                    itemBuilder: (context, i) => _row(context, ref, rest[i], now, hue, last: i == rest.length - 1),
                  ),
                ),
        ),
      ]);

      // Nothing at all: just the calm statement, no empty list beside it.
      if (s.messages.isEmpty) return left;
      return _split(left, right, fa: 100, fb: 108);
    });
  }

  Widget _row(BuildContext context, WidgetRef ref, SlackMsg m, DateTime now, Color hue, {required bool last}) => Press(
        onTap: () => slackOpen(context, ref, m),
        scale: .99,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: _t.line))),
          child: Opacity(
            opacity: m.unread ? 1 : .5,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _avatar(m, glow: m.unread),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(text: m.sender, style: _t.t(14, w: m.unread ? FontWeight.w700 : FontWeight.w600)),
                          TextSpan(text: '  ${slackWhere(m)}', style: _fa(12)),
                        ]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(slackTime(m.ts, now), style: _mu(12)),
                    const SizedBox(width: 8),
                    m.unread ? _dot(hue, size: 7) : const SizedBox(width: 7),
                  ]),
                  const SizedBox(height: 3),
                  Text(m.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: m.unread ? _t.t(13, w: FontWeight.w500, h: 1.35) : _mu(13, h: 1.35)),
                ]),
              ),
              SlackReadTick(m, color: hue, fill: hue),
            ]),
          ),
        ),
      );
}

// ------------------------------------------------------------------ github

class _Github extends ConsumerWidget {
  const _Github();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = topicData<GithubData>(ref, codeTopic(ref))!;
    final now = DateTime.now();
    final dow = now.weekday % 7;
    final mx = maxOf([...g.thisWeek, ...g.lastWeek]);
    final green = _hsl(138, 70, 62);
    final top = g.topRepos.isEmpty ? 1 : g.topRepos.first.count;

    final streak = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Current streak', style: _lbl),
      const SizedBox(height: 10),
      Text('${g.streakCurrent}', style: _serif(120, h: .8)),
      const SizedBox(height: 10),
      Text(
        '${g.streakCurrent == 1 ? 'day' : 'days'} in a row. Longest ${g.streakLongest}'
        '${g.bestDay == null ? '.' : ', best day ${g.bestDay!.count} on ${month3(g.bestDay!.date)} ${g.bestDay!.date.day}.'}',
        style: _mu(13, h: 1.4),
      ),
    ]);

    final week = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('This week', style: _lbl),
      const SizedBox(height: 4),
      Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Text('${g.weekTotal}', style: _serif(40)),
        const SizedBox(width: 8),
        Text(g.weekDelta >= 0 ? '+${g.weekDelta}' : '−${-g.weekDelta}',
            style: _t.t(13, w: FontWeight.w700, c: g.weekDelta >= 0 ? _hsl(138, 70, 66) : _t.bad)),
        const SizedBox(width: 6),
        Text('vs last week', style: _fa(12)),
      ]),
      const SizedBox(height: 8),
      Expanded(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: LayoutBuilder(builder: (context, c) {
                final avail = c.maxHeight - 24;
                double h(num? v) => math.max(3, avail * (v ?? 0) / mx);
                final thisV = i < g.thisWeek.length && i <= dow ? g.thisWeek[i] : null;
                final lastV = i < g.lastWeek.length ? g.lastWeek[i] : 0;
                return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Container(
                        width: 7,
                        height: h(lastV),
                        decoration: BoxDecoration(color: _t.line, borderRadius: BorderRadius.circular(6))),
                    const SizedBox(width: 2),
                    TweenAnimationBuilder<double>(
                      tween: Tween(end: h(thisV)),
                      duration: const Duration(milliseconds: 650),
                      builder: (context, v, _) => Container(
                        width: 7,
                        height: v,
                        decoration: BoxDecoration(
                          color: green,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [BoxShadow(color: _hsl(138, 80, 50, .5), blurRadius: 10)],
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 5),
                  Text('SMTWTFS'[i],
                      style: i == dow ? _t.t(10.5, w: FontWeight.w700, c: _tx) : _fa(10.5)),
                ]);
              }),
            ),
        ]),
      ),
    ]);

    final repos = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(topReposLabel(ref), style: _lbl),
      const SizedBox(height: 8),
      for (final r in g.topRepos.take(4))
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _t.t(13))),
              const SizedBox(width: 10),
              Text('${r.count}', style: _mu(13)),
            ]),
            const SizedBox(height: 4),
            _line(r.count / top, _hsl(138, 65, 62), height: 1.5),
          ]),
        ),
    ]);

    return LayoutBuilder(builder: (context, c) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _Tabs(
                items: codeSources,
                selected: ref.watch(codeSourceProvider),
                onTap: (i) => ref.read(codeSourceProvider.notifier).set(i)),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: c.maxHeight * .56 - 12,
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(flex: 80, child: Padding(padding: const EdgeInsets.only(right: 24), child: streak)),
              Expanded(flex: 100, child: _ruled(Padding(padding: const EdgeInsets.only(right: 24), child: week), pad: 24)),
              Expanded(flex: 100, child: _ruled(repos, pad: 24)),
            ]),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Heatmap(
              weeks: g.weeks,
              style: HeatStyle.glow,
              fill: true,
              dayLabels: false,
              labelStyle: _t.t(10, w: FontWeight.w600, c: _t.faint),
            ),
          ),
        ]));
  }
}

// ------------------------------------------------------------------ shortcuts

class _Shortcuts extends ConsumerWidget {
  const _Shortcuts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sc = topicData<ShortcutsData>(ref, 'shortcuts')!;
    final order = ref.watch(settingsProvider.select((s) => s.tileOrder));
    final tiles = orderedTiles(sc.tiles, order);
    final rows = (tiles.length / 4).ceil().clamp(1, 3);
    return Column(children: [
      for (var r = 0; r < rows; r++)
        Expanded(
          child: Row(children: [
            for (var cIdx = 0; cIdx < 4; cIdx++)
              Expanded(
                child: r * 4 + cIdx < tiles.length ? _key(context, ref, tiles[r * 4 + cIdx], sc.volumePct) : const SizedBox(),
              ),
          ]),
        ),
    ]);
  }

  Widget _key(BuildContext context, WidgetRef ref, Tile t, int? vol) {
    final on = t.active;
    final red = _hsl(355, 90, 70, .7);
    final isVol = t.id == 'volume.up' || t.id == 'volume.down';
    return Press(
      onTap: () => act(context, ref, 'shortcut.run', {'id': t.id}),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? _hsl(355, 80, 62, .18) : const Color(0x00000000),
            border: Border.all(color: on ? red : const Color(0x33F4EFE6)),
            boxShadow: on ? [BoxShadow(color: _hsl(355, 90, 60, .45), blurRadius: 26)] : null,
          ),
          alignment: Alignment.center,
          child: DpIcon(tileIcon(t), size: 30, color: on ? _hsl(355, 95, 78) : _tx),
        ),
        const SizedBox(height: 12),
        Text(tileLabel(t), style: _t.t(13.5, w: FontWeight.w600, c: on ? _tx : _t.muted)),
        if (isVol && vol != null) ...[
          const SizedBox(height: 4),
          Text('$vol%', style: _fa(11.5)),
        ],
      ]),
    );
  }
}
