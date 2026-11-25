// Concept 3 — Panel: page layouts. Sizes are the concept's CSS px (design canvas 915×412).
import 'dart:math' as math;

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
import 'panel.dart';

/// PanelSkin page layouts (concept panel).
Widget panelPage(PageId id) => switch (id) {
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

// ====================================================================== primitives

const _t = PanelSkin.t;
const _ink = PanelSkin.ink, _lab = PanelSkin.lab, _wink = PanelSkin.wink, _wdim = PanelSkin.wdim;
const _wline = PanelSkin.wline, _sig = PanelSkin.sig, _g = PanelSkin.g, _a = PanelSkin.a, _r = PanelSkin.r;
const _gap = 10.0;

/// Limit level colour: <50 green, <80 amber, else red.
Color _lvl(double v) => v < 50 ? _g : (v < 80 ? _a : _r);

bool _glows(Color c) => c == _a || c == _g || c == _r || c == _sig;

/// Condensed LCD readout with optional small unit (`.rd` + `small`).
Widget _rd(String v, double size,
    {Color c = _wink,
    String? small,
    Color smallColor = _wdim,
    double smallScale = .42,
    TextAlign? align,
    int maxLines = 1}) {
  final shadows = _glows(c) ? [Shadow(color: c.withValues(alpha: .38), blurRadius: 12)] : null;
  return Text.rich(
    TextSpan(children: [
      TextSpan(text: v, style: _t.d(size, c: c, h: .9).copyWith(shadows: shadows, letterSpacing: size * .005)),
      if (small != null)
        TextSpan(
            text: ' $small',
            style: _t.d(size * smallScale, w: FontWeight.w500, c: smallColor, h: .9)
                .copyWith(letterSpacing: size * smallScale * .02)),
    ]),
    maxLines: maxLines,
    softWrap: maxLines > 1,
    overflow: TextOverflow.clip,
    textAlign: align,
  );
}

TextStyle _dim([double size = 12.5]) => _t.t(size, c: _wdim, h: 1.3);
TextStyle _wt([double size = 12.5, FontWeight w = FontWeight.w500]) => _t.t(size, w: w, c: _wink, h: 1.3);
TextStyle get _labStyle => _t.t(11, w: FontWeight.w600, c: _lab, h: 1.3);

String _comma(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

/// Printed label above a window (`.lab`): optional icon, text, spacer, trailing.
Widget _labRow(String text, {String? icon, Widget? trailing}) => Padding(
      padding: const EdgeInsets.only(left: 3, bottom: 4, right: 3),
      child: Row(children: [
        if (icon != null) ...[DpIcon(icon, size: 12, color: _lab, stroke: 2), const SizedBox(width: 6)],
        Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: _labStyle)),
        if (trailing != null) ...[const SizedBox(width: 8), trailing],
      ]),
    );

/// A labelled LCD window filling its parent (`cell()` in the concept).
class _Cell extends StatelessWidget {
  const _Cell({this.label, this.icon, this.trailing, required this.child, this.padding, this.onTap});
  final String? label, icon;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget win = PanelSkin.window(child: child, padding: padding);
    if (onTap != null) win = Press(onTap: onTap, scale: .99, child: win);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (label != null) _labRow(label!, icon: icon, trailing: trailing),
      Expanded(child: win),
    ]);
  }
}

/// Physical key (`.key`): light or dark cap, optional lit LED, latched-down state.
class _Key extends StatefulWidget {
  const _Key({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.height = 40,
    this.padding = const EdgeInsets.symmetric(horizontal: 18),
    this.dark = false,
    this.lit = false,
    this.down = false,
    this.disabled = false,
    this.align = MainAxisAlignment.center,
    this.fontSize = 13,
  });
  final Widget child;
  final VoidCallback? onTap, onLongPress;
  final double height, fontSize;
  final EdgeInsets padding;
  final bool dark, lit, down, disabled;
  final MainAxisAlignment align;

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  bool _press = false;

  @override
  Widget build(BuildContext context) {
    final pressed = widget.down || _press;
    final fg = widget.dark ? const Color(0xFFF2F3F4) : _ink;
    final grad = widget.dark
        ? const [Color(0xFF34383D), Color(0xFF23272B)]
        : (pressed ? const [Color(0xFFD6D9DC), Color(0xFFE3E5E8)] : const [Color(0xFFF1F2F4), Color(0xFFDCDFE2)]);
    final edge = widget.dark ? const Color(0xFF0D0F11) : const Color(0xFF9DA2A8);
    Widget k = AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      height: widget.height,
      padding: widget.padding,
      transform: Matrix4.translationValues(0, pressed ? 2 : 0, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: grad),
        border: pressed && !widget.dark ? const Border(top: BorderSide(color: Color(0x2E000000), width: 1.5)) : null,
        boxShadow: pressed
            ? [BoxShadow(color: edge, offset: const Offset(0, .5))]
            : [
                BoxShadow(color: edge, offset: const Offset(0, 2.5)),
                const BoxShadow(color: Color(0x33000000), offset: Offset(0, 4), blurRadius: 6),
              ],
      ),
      child: DefaultTextStyle(
        style: _t.t(widget.fontSize, w: FontWeight.w600, c: fg, h: 1.1),
        child: LayoutBuilder(
          builder: (context, c) => Row(
            mainAxisSize: c.maxWidth.isFinite ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: widget.align,
            children: [
              if (widget.lit) ...[PanelSkin.led(_sig, size: 7), const SizedBox(width: 8)],
              c.maxWidth.isFinite ? Flexible(child: widget.child) : widget.child,
            ],
          ),
        ),
      ),
    );
    if (widget.disabled) k = Opacity(opacity: .6, child: k);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _press = true),
      onTapUp: (_) => setState(() => _press = false),
      onTapCancel: () => setState(() => _press = false),
      onTap: widget.disabled ? null : widget.onTap,
      onLongPress: widget.disabled ? null : widget.onLongPress,
      child: k,
    );
  }
}

/// Dark recessed bezel holding artwork (`.bezel`).
Widget _bezel(Widget art) => Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2E33),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0xB3FFFFFF), offset: Offset(0, 1))],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x66000000)),
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(6), child: art),
    );

/// Vertical LED bar with a label underneath (`.vbar`).
Widget _vbar(double v, Color c, String label,
        {int n = 12, double maxW = 30, bool bold = false}) =>
    Column(children: [
      Expanded(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: SizedBox.expand(child: LedBar(value: v, color: c, segments: n, vertical: true)),
          ),
        ),
      ),
      const SizedBox(height: 5),
      Text(label,
          maxLines: 1,
          style: _t.t(10.5, w: bold ? FontWeight.w700 : FontWeight.w500, c: bold ? _wink : _wdim, h: 1.1)),
    ]);

/// Horizontal LED bar (`.sg`), 10px tall by default.
Widget _sg(double v, Color c, {int n = 20, double h = 10}) => LedBar(value: v, color: c, segments: n, thickness: h);

/// Row of [children] separated by [_gap] with flex weights.
Widget _row(List<(int, Widget)> kids, {double gap = _gap}) => Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, (f, w)) in kids.indexed) ...[
          if (i > 0) SizedBox(width: gap),
          Expanded(flex: f, child: w),
        ],
      ],
    );

String _digits(Duration d) {
  final s = d.inSeconds;
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
  return h > 0 ? '$h:${two(m)}:${two(sec)}' : '${two(m)}:${two(sec)}';
}

// ====================================================================== Home

class _Home extends ConsumerWidget {
  const _Home();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final sys = topicData<SystemData>(ref, 'system');
    final cl = topicData<ClaudeData>(ref, 'claude');
    final sl = slackHome(ref);
    final media = topicData<MediaData>(ref, 'media');
    final wx = ref.watch(weatherProvider);
    final events = ref.watch(calendarEventsProvider);
    void go(PageId p) => PageNav.go(context, p);

    return Ticker(builder: (context, now) {
      final next = nextEvent(events, now);
      final five = limitPct(cl?.fiveHour, now), week = limitPct(cl?.sevenDay, now);

      final clock = _Cell(
        label: 'Clock',
        child: Stack(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(longDate(now), style: _dim(13)),
            const SizedBox(height: 4),
            _rd(clockFmt(now, s.clock24), 104, c: _a, small: s.clock24 ? null : ampm(now), smallColor: _a),
          ]),
          Positioned(
            left: 0,
            right: 0,
            bottom: -4,
            child: Column(children: [
              _strip(
                led: next != null ? _sig : _wdim,
                title: next?.title ?? 'Nothing else today',
                sub: next == null
                    ? 'Free until tomorrow'
                    : '${_inText(next, now)}, ${clockFull(next.start, h24: s.clock24)}'
                        '${next.location != null ? ', ${next.location}' : ''}',
                onTap: () => go(PageId.calendar),
              ),
              _strip(
                led: media?.playing == true ? _g : _wdim,
                title: media?.title ?? 'Nothing playing',
                sub: media?.artist ?? '—',
                onTap: () => go(PageId.music),
              ),
            ]),
          ),
        ]),
      );

      final weather = _Cell(
        label: 'Weather',
        icon: 'weather',
        onTap: () => go(PageId.weather),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _rd(wx == null ? '—' : '${temp(wx.now.tempC, s.fahrenheit)}°', 54),
          const SizedBox(height: 6),
          Text(wx?.now.condition ?? 'No weather yet', style: _wt()),
          if (wx != null)
            Text('High ${temp(wx.days.first.hiC, s.fahrenheit)}°, low ${temp(wx.days.first.loC, s.fahrenheit)}°',
                style: _dim()),
        ]),
      );

      final claude = _Cell(
        label: 'Claude',
        icon: 'claude',
        onTap: () => go(PageId.claude),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _rd(cl == null ? '—' : '${five.round()}', 54, c: _lvl(five), small: cl == null ? null : '%'),
            const Spacer(),
            Text('5-hour\n${cl == null ? '' : resetsIn(cl.fiveHour, now).toLowerCase()}',
                textAlign: TextAlign.right, style: _dim(11.5)),
          ]),
          const SizedBox(height: 10),
          _sg(five / 100, _lvl(five)),
          const SizedBox(height: 10),
          Row(children: [
            Text('Weekly', style: _dim(11.5)),
            const Spacer(),
            Text(cl == null ? '—' : '${week.round()}%', style: _t.t(11.5, c: _lvl(week))),
          ]),
          const SizedBox(height: 4),
          _sg(week / 100, _lvl(week)),
        ]),
      );

      // Slack: unread count on the LCD (signal orange when there's something new, calm green
      // at zero), then the newest unread sender and one line of it.
      final off = sl.headline == 'Slack'; // not connected / not set up
      final slLed = off ? PanelSkin.off : (sl.unread > 0 ? _sig : _g);
      final latest = sl.latest;
      final slack = _Cell(
        label: 'Slack',
        icon: 'slack',
        onTap: () => go(PageId.slack),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _rd(off ? '—' : '${sl.unread}', 54, c: off ? _wdim : slLed, small: off ? null : 'unread'),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                PanelSkin.led(slLed, size: 7),
                const SizedBox(width: 6),
                Text(off ? 'Off' : (sl.unread > 0 ? 'New' : 'Clear'), style: _dim(11.5)),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          Container(height: 1, color: _wline),
          const SizedBox(height: 9),
          if (latest != null)
            Row(children: [
              _badge(latest, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                    Expanded(
                      child: Text(latest.sender,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: _wt(13, FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    _rd(slackTime(latest.ts, now), 14, c: _a),
                  ]),
                  Text(latest.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: _dim(12)),
                ]),
              ),
            ])
          else ...[
            Text(off ? (sl.detail == '—' ? 'No Slack data' : sl.detail) : sl.headline,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: _wt(13, FontWeight.w600)),
            if (!off) Text(sl.detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: _dim(12)),
          ],
        ]),
      );

      Widget meter(String l, double? v, Color c) => Row(children: [
            SizedBox(width: 30, child: Text(l, style: _dim(11))),
            const SizedBox(width: 8),
            Expanded(child: _sg((v ?? 0) / 100, c)),
            const SizedBox(width: 8),
            SizedBox(width: 30, child: _rd(v == null ? '—' : '${v.round()}', 17, align: TextAlign.right)),
          ]);
      final system = _Cell(
        label: 'System',
        icon: 'system',
        onTap: () => go(PageId.system),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          meter('CPU', sys?.cpu.pct, PanelSkin.b),
          const SizedBox(height: 9),
          meter('GPU', sys?.gpu.pct, PanelSkin.tq),
          const SizedBox(height: 9),
          meter('RAM', sys == null ? null : sys.ramUsed / sys.ramTotal * 100, PanelSkin.v),
        ]),
      );

      return _row([
        (135, clock),
        (100, Column(children: [Expanded(child: weather), const SizedBox(height: _gap), Expanded(child: slack)])),
        (100, Column(children: [Expanded(child: claude), const SizedBox(height: _gap), Expanded(child: system)])),
      ]);
    });
  }

  static String _inText(CalEvent e, DateTime now) {
    final d = e.start.difference(now);
    if (d.isNegative) return 'Now';
    if (d.inMinutes < 1) return 'Starting now';
    return 'in ${dur(d)}';
  }

  Widget _strip({required Color led, required String title, required String sub, VoidCallback? onTap}) => Press(
        onTap: onTap,
        scale: 1,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: _wline))),
          child: Row(children: [
            PanelSkin.led(led, size: 6),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _wt(13.5, FontWeight.w600)),
                Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: _dim(12)),
              ]),
            ),
          ]),
        ),
      );
}

String clockFmt(DateTime t, bool h24) => clock(t, h24: h24);

// ====================================================================== System

class _Tabs extends ConsumerWidget {
  const _Tabs();
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      _keyTabs(const ['Laptop', 'Internet'], ref.watch(systemTabProvider), ref.read(systemTabProvider.notifier).set);
}

/// A row of latching keys, one lit (the System Laptop | Internet switch).
Widget _keyTabs(List<String> items, int value, ValueChanged<int> onChanged) {
  Widget k(String l, int i) => _Key(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        fontSize: 11.5,
        down: value == i,
        lit: value == i,
        onTap: () => onChanged(i),
        child: Text(l),
      );
  return Row(mainAxisSize: MainAxisSize.min, children: [
    for (final (i, l) in items.indexed) ...[if (i > 0) const SizedBox(width: 8), k(l, i)],
  ]);
}

class _System extends ConsumerWidget {
  const _System();
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref.watch(systemTabProvider) == 0 ? const _PC() : const _Net();
}

Widget _header(String label) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Padding(padding: const EdgeInsets.only(left: 3), child: Text(label, style: _labStyle)),
        const Spacer(),
        const _Tabs(),
      ]),
    );

/// Oscilloscope window with a legend in the top-right corner.
Widget _scope({required Widget chart, required List<Widget> legend}) => PanelSkin.window(
      padding: const EdgeInsets.all(6),
      child: Stack(children: [
        Positioned.fill(child: chart),
        Positioned(
          top: 2,
          right: 6,
          child: Row(children: [
            for (final (i, w) in legend.indexed) ...[if (i > 0) const SizedBox(width: 12), w],
          ]),
        ),
      ]),
    );

class _PC extends ConsumerWidget {
  const _PC();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = topicData<SystemData>(ref, 'system')!;
    String gb(int b) => (b / (1 << 30)).toStringAsFixed(1);
    final ramPct = s.ramUsed / s.ramTotal * 100;
    final g = s.gpu;
    final vramPct = g.vramUsed != null && (g.vramTotal ?? 0) > 0 ? g.vramUsed! / g.vramTotal! * 100 : null;
    final (down, downU) = rate(s.downBps);
    final (up, upU) = rate(s.upBps);

    Widget ch(String label, double? v, Color c, String sub) => _Cell(
          label: label,
          padding: const EdgeInsets.all(10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            LedBar(value: (v ?? 0) / 100, color: c, segments: 16, vertical: true, thickness: 14),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                v == null
                    ? _rd('N/A', 50)
                    : Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                        AnimNum(v, style: _t.d(50, c: _wink, h: .9)),
                        Text(' %', style: _t.d(21, w: FontWeight.w500, c: _wdim, h: .9)),
                      ]),
                const Spacer(),
                Text(sub, style: _dim(11.5)),
              ]),
            ),
          ]),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _header('Channels'),
      Expanded(
        flex: 47,
        child: _row([
          (1, ch('CPU', s.cpu.pct, PanelSkin.b,
              s.cpu.cores != null ? '${s.cpu.cores} cores\n${s.cpu.threads ?? s.cpu.cores} threads' : s.cpu.model)),
          (1, ch('GPU', g.available ? g.pct : null, PanelSkin.tq, g.tempC != null ? '${g.tempC!.round()} °C' : (g.model ?? 'Not available'))),
          (1, ch('RAM', ramPct, PanelSkin.v, '${gb(s.ramUsed)} / ${gb(s.ramTotal).replaceAll('.0', '')} GB')),
          (1, ch(g.vramLabel, vramPct, PanelSkin.pk,
              vramPct == null ? 'N/A' : '${gb(g.vramUsed!)} / ${gb(g.vramTotal!).replaceAll('.0', '')} GB')),
        ]),
      ),
      const SizedBox(height: _gap),
      Expanded(
        flex: 53,
        child: _scope(
          chart: LineChart(
            grid: ChartGrid.scope,
            gridColor: const Color(0xFF1E2226),
            pad: 0,
            series: [
              LineSeries(s.gpuHistory, PanelSkin.tq, width: 1.8, step: true, glow: true, halo: 3),
              LineSeries(s.cpuHistory, PanelSkin.b, width: 1.8, step: true, glow: true, halo: 3),
            ],
          ),
          legend: [
            Text('CPU', style: _t.t(11.5, w: FontWeight.w600, c: PanelSkin.b)),
            Text('GPU', style: _t.t(11.5, w: FontWeight.w600, c: PanelSkin.tq)),
            Text('$down $downU down', style: _dim(11.5)),
            Text('$up $upU up', style: _dim(11.5)),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(3, 5, 3, 0),
        child: Row(children: [
          Expanded(
            child: Text('${s.cpu.model}${g.model != null ? ' / ${g.model}' : ''}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: _labStyle),
          ),
          Text('Disk ${s.diskPct.round()}% used', style: _labStyle),
        ]),
      ),
    ]);
  }
}

class _Net extends ConsumerWidget {
  const _Net();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = topicData<NetworkData>(ref, 'network');
    final st = n?.speedtest;
    final running = st?.running ?? false;
    final down = running ? st?.progress?.downBps : st?.last?.downBps;
    final up = running ? st?.progress?.upBps : st?.last?.upBps;
    final online = n?.online ?? false;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _header('Network'),
      SizedBox(
        height: 104,
        child: _row([
          (100, _Cell(
            label: 'Latency',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _rd(n?.latencyMs == null ? '—' : '${n!.latencyMs!.round()}', 46, c: _a, small: 'ms', smallColor: _a),
              const SizedBox(height: 6),
              Text(n == null ? 'No data' : 'Jitter ${n.jitterMs?.toStringAsFixed(1) ?? '—'} ms, loss ${n.lossPct.round()}%',
                  style: _dim(11.5)),
            ]),
          )),
          (100, _Cell(
            label: 'Status',
            child: Ticker(builder: (context, now) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    PanelSkin.led(n == null ? _wdim : (online ? _g : _r), size: 10),
                    const SizedBox(width: 6),
                    _rd(n == null ? 'No data' : (online ? 'Online' : 'Offline'), 38, c: n == null ? _wdim : (online ? _g : _r)),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    n == null
                        ? '—'
                        : 'Up ${n.onlineSince == null ? '—' : durLong(now.difference(n.onlineSince!))}, '
                            'last drop ${n.lastDrop == null ? 'never' : ago(now.difference(n.lastDrop!))}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _dim(11.5),
                  ),
                ])),
          )),
          (125, _Cell(
            label: 'Data used',
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _quad(n == null ? '—' : _gbNum(n.usageToday), 'GB', 'Today')),
              const SizedBox(width: 14),
              Expanded(child: _quad(n == null ? '—' : (n.usageMonth / (1 << 30)).round().toString(), 'GB', 'This month')),
            ]),
          )),
        ]),
      ),
      const SizedBox(height: _gap),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _labRow('Latency, last 2 minutes'),
          Expanded(
            child: _scope(
              chart: LineChart(
                min: 0,
                max: 50,
                pad: 3,
                grid: ChartGrid.scope,
                gridColor: const Color(0xFF1E2226),
                series: [if (n != null) LineSeries(n.latencyHistory, _a, width: 1.5, glow: true, halo: 3)],
              ),
              legend: [Text('Scale 0–50 ms', style: _dim(11.5))],
            ),
          ),
        ]),
      ),
      const SizedBox(height: _gap),
      SizedBox(
        height: 96,
        child: _row([
          (200, _Cell(
            label: 'Speed test',
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Row(children: [
                _rd(down == null ? '—' : mbps(down), 38, small: 'Mbps down'),
                const SizedBox(width: 24),
                _rd(up == null ? '—' : mbps(up), 38, small: 'Mbps up'),
                const Spacer(),
                Ticker(builder: (context, now) => Text(
                      running
                          ? 'Testing now'
                          : (st?.last == null ? 'Never tested' : 'Tested ${ago(now.difference(st!.last!.at))}'),
                      textAlign: TextAlign.right,
                      style: _dim(11.5),
                    )),
              ]),
              if (running) ...[
                const SizedBox(height: 8),
                _sg((st?.progress?.pct ?? 0) / 100, _sig),
              ] else if (st?.last != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('Ping ${st!.last!.pingMs.round()} ms', style: _dim(11.5)),
                ),
            ]),
          )),
          (125, Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _Key(
              height: 58,
              fontSize: 14,
              lit: running,
              down: running,
              disabled: running || n == null,
              onTap: () => act(context, ref, 'speedtest.run', const {}, null, null, const Duration(seconds: 90)),
              child: Text(running ? 'Testing…' : 'Run test'),
            ),
            const SizedBox(height: 3),
          ])),
        ]),
      ),
    ]);
  }

  static String _gbNum(int b) => (b / (1 << 30)).toStringAsFixed(1);
}

Widget _quad(String v, String unit, String label, {double size = 26}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _rd(v, size, small: unit),
        const SizedBox(height: 2),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _dim(11)),
      ],
    );

// ====================================================================== Claude

class _Claude extends ConsumerWidget {
  const _Claude();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = topicData<ClaudeData>(ref, 'claude')!;
    final h24 = ref.watch(settingsProvider).clock24;
    return Ticker(builder: (context, now) {
      final five = limitPct(c.fiveHour, now), week = limitPct(c.sevenDay, now);
      final peak = maxOf(c.days.map((d) => d.tokens));
      final mx = maxOf(c.modelsToday.map((m) => m.tokens));

      Widget limit(String label, LimitWindow? w, double v, String reset) => _Cell(
            label: label,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _rd(w == null ? '—' : '${v.round()}', 58, c: w == null ? _wdim : _lvl(v), small: w == null ? null : '%'),
              const SizedBox(height: 10),
              _sg(v / 100, _lvl(v)),
              const SizedBox(height: 8),
              Text.rich(TextSpan(children: [
                TextSpan(text: reset.startsWith('Resets in ') ? 'Resets in ' : (reset.startsWith('Resets ') ? 'Resets ' : ''),
                    style: _dim()),
                TextSpan(text: reset.replaceFirst(RegExp(r'^Resets (in )?'), ''), style: _wt()),
              ]), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          );

      return Column(children: [
        SizedBox(
          height: 140,
          child: _row([
            (100, limit('5-hour limit', c.fiveHour, five, resetsIn(c.fiveHour, now))),
            (100, limit('Weekly limit', c.sevenDay, week, resetsAt(c.sevenDay, now, h24: h24))),
            (110, _Cell(
              label: 'Today',
              child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  Expanded(child: _quad(compact(c.tokens), '', 'Tokens')),
                  const SizedBox(width: 14),
                  Expanded(child: _quad(compact(c.outputTokens), '', 'Output')),
                ]),
                Row(children: [
                  Expanded(child: _quad('${c.messages}', '', 'Messages')),
                  const SizedBox(width: 14),
                  Expanded(child: _quad(compact(c.lastHourTokens), '', 'Last hour')),
                ]),
              ]),
            )),
          ]),
        ),
        const SizedBox(height: _gap),
        Expanded(
          child: _row([
            (210, _Cell(
              label: 'Last 7 days',
              trailing: Text('Peak ${compact(peak)} tokens', style: _labStyle),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: BarTapTip(count: c.days.length, label: (i) => dayTokensLabel(c.days[i], now), child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (final (i, d) in c.days.indexed) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                        child: _vbar(d.tokens / peak, _sig, dayLabel(d.date, now), bold: i == c.days.length - 1)),
                  ],
                ])),
              ),
            )),
            (110, _Cell(
              label: 'Models today',
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final (i, m) in c.modelsToday.indexed) ...[
                  if (i > 0) const SizedBox(height: 14),
                  Row(children: [
                    Text(modelName(m.family), style: _wt(12.5, FontWeight.w600)),
                    const Spacer(),
                    _rd(compact(m.tokens), 18),
                  ]),
                  const SizedBox(height: 5),
                  _sg(m.tokens / mx, _sig),
                ],
                if (c.modelsToday.isEmpty) Text('No usage yet today', style: _dim()),
              ]),
            )),
          ]),
        ),
      ]);
    });
  }
}

// ====================================================================== Calendar

class _Calendar extends ConsumerWidget {
  const _Calendar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(calendarEventsProvider);
    final h24 = ref.watch(settingsProvider).clock24;
    return Ticker(builder: (context, now) {
      final split = splitEvents(events, now);
      final next = nextEvent(events, now);

      Widget ag(CalEvent e) {
        final isNext = identical(e, next);
        final past = e.end.isBefore(now);
        final where = [e.location, e.calendar?.toLowerCase()].whereType<String>().join(', ');
        return Opacity(
          opacity: past ? .4 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _wline))),
            child: Row(children: [
              SizedBox(
                width: 88,
                child: _rd(clock(e.start, h24: h24), 26,
                    c: isNext ? _a : _wink, small: h24 ? null : ampm(e.start), smallColor: isNext ? _a : _wdim),
              ),
              const SizedBox(width: 12),
              PanelSkin.led(hex(e.color, _sig), size: 6),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _wt(15, FontWeight.w600)),
                  Text('${where.isEmpty ? '' : '$where, '}until ${clockFull(e.end, h24: h24)}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: _dim()),
                ]),
              ),
              if (isNext) ...[
                const SizedBox(width: 12),
                _rd(e.start.isAfter(now) ? 'in ${dur(e.start.difference(now))}' : 'now', 18, c: _sig),
              ],
            ]),
          ),
        );
      }

      return _row([
        (150, _Cell(
          label: 'Today, ${longDate(now)}',
          child: split.today.isEmpty
              ? Center(child: Text('Nothing on the calendar today', style: _dim(13.5)))
              : SingleChildScrollView(child: Column(children: [for (final e in split.today) ag(e)])),
        )),
        (100, _Cell(
          label: 'Later this week',
          child: Stack(children: [
            SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 22),
              child: Column(children: [
                for (final e in split.later)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _wline))),
                    child: Row(children: [
                      PanelSkin.led(hex(e.color, _sig), size: 6),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _wt(13.5, FontWeight.w600)),
                          Text('${weekday(e.start)}, ${clockFull(e.start, h24: h24)}', style: _dim()),
                        ]),
                      ),
                    ]),
                  ),
              ]),
            ),
            Positioned(
              left: 0,
              bottom: 0,
              child: Text(split.later.isEmpty ? 'Nothing in the next 7 days' : 'Nothing else in the next 7 days',
                  style: _dim(11.5)),
            ),
          ]),
        )),
      ]);
    });
  }
}

// ====================================================================== Weather

class _Weather extends ConsumerWidget {
  const _Weather();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(weatherProvider);
    final s = ref.watch(settingsProvider);
    if (w == null) {
      return _Cell(child: Center(child: Text('Set a weather location in Settings', style: _dim(14))));
    }
    final f = s.fahrenheit;
    final hrs = w.hours.map((h) => temp(h.tempC, f)).toList();
    final lo = hrs.reduce(math.min) - 4, hi = hrs.reduce(math.max);

    return Column(children: [
      Expanded(
        child: _row([
          (100, _Cell(
            label: w.place,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _rd('${temp(w.now.tempC, f)}°', 80),
                const Spacer(),
                DpIcon(w.now.icon, size: 44, color: _wink, stroke: 1.6),
              ]),
              const SizedBox(height: 6),
              Text(w.now.condition, style: _wt(16)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _quad('${temp(w.now.feelsC, f)}°', '', 'Feels like', size: 20)),
                Expanded(child: _quad('${w.now.humidity}%', '', 'Humidity', size: 20)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _quad(wind(w.now.windKmh, f), '', 'Wind', size: 20)),
                Expanded(child: _quad(clockFull(w.now.updated, h24: s.clock24), '', 'Updated', size: 20)),
              ]),
            ]),
          )),
          (160, _Cell(
            label: 'Next 12 hours',
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final (i, h) in w.hours.indexed) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Column(children: [
                    _rd('${hrs[i]}°', 17),
                    const SizedBox(height: 4),
                    Expanded(
                      child: LedBar(
                          value: (hrs[i] - lo) / math.max(1, hi - lo), color: PanelSkin.b, segments: 10, vertical: true, thickness: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(i == 0 ? 'Now' : _hourLabel(h.time, s.clock24),
                        maxLines: 1, style: _t.t(10.5, c: _wdim, h: 1.1)),
                  ]),
                ),
              ],
            ]),
          )),
        ]),
      ),
      const SizedBox(height: _gap),
      SizedBox(
        height: 92,
        child: PanelSkin.window(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Row(children: [
            for (final (i, d) in w.days.indexed)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(border: i == 0 ? null : const Border(left: BorderSide(color: _wline))),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(i == 0 ? 'Today' : weekday3(d.date), style: _t.t(11, c: _wdim, h: 1.2)),
                    const SizedBox(height: 3),
                    DpIcon(d.icon, size: 18, color: _wink),
                    const SizedBox(height: 3),
                    _rd('${temp(d.hiC, f)}°', 19, small: '${temp(d.loC, f)}°', smallColor: _wdim, smallScale: .8),
                    const SizedBox(height: 3),
                    SizedBox(
                      height: 14,
                      child: Text(d.precipPct > 0 ? '${d.precipPct}% rain' : '',
                          style: _t.t(11, c: PanelSkin.b, h: 1.2)),
                    ),
                  ]),
                ),
              ),
          ]),
        ),
      ),
    ]);
  }

  static String _hourLabel(DateTime t, bool h24) =>
      h24 ? '${two(t.hour)}:00' : '${t.hour % 12 == 0 ? 12 : t.hour % 12} ${ampm(t)}';
}

// ====================================================================== Music

class _Music extends ConsumerWidget {
  const _Music();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = topicData<MediaData>(ref, 'media')!;
    final art = topicData<MediaArt>(ref, 'media.art');
    final skew = ref.read(agentProvider.notifier).clockSkewMs;
    final title = m.title ?? 'Nothing playing';
    final b64 = art != null && art.artId == m.artId ? art.b64 : null;

    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AspectRatio(aspectRatio: 1, child: _bezel(AlbumArt(title: title, b64: b64))),
      const SizedBox(width: _gap),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: _Cell(
              label: 'Now playing${m.source != null ? ', ${m.source}' : ''}',
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 6),
                Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _t.d(34, c: _wink, h: 1).copyWith(letterSpacing: .17)),
                const SizedBox(height: 4),
                if (m.artist != null) Text(m.artist!, maxLines: 1, overflow: TextOverflow.ellipsis, style: _wt(15, FontWeight.w600)),
                if (m.album != null) Text(m.album!, maxLines: 1, overflow: TextOverflow.ellipsis, style: _dim()),
                const Spacer(),
                Ticker(
                  period: const Duration(seconds: 1),
                  builder: (context, now) {
                    final pos = m.positionNow(now, skewMs: skew);
                    final len = m.durationMs ?? 0;
                    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _SeekLed(
                        value: len == 0 ? 0 : pos / len,
                        enabled: m.canSeek && len > 0,
                        onSeek: (f) => act(context, ref, 'media.seek', {'position_ms': (f * len).round()}),
                      ),
                      const SizedBox(height: 4),
                      Row(children: [
                        _rd(mmss(pos), 18, c: _g),
                        const Spacer(),
                        _rd(len == 0 ? '—' : mmss(len), 18, c: _wdim),
                      ]),
                    ]);
                  },
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              flex: 10,
              child: _Key(height: 52, onTap: () => act(context, ref, 'media.prev'), child: const DpIcon('prev', size: 22)),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 15,
              child: _Key(
                height: 52,
                dark: true,
                lit: m.playing,
                onTap: () => act(context, ref, 'media.play_pause'),
                child: DpIcon(m.playing ? 'pause' : 'play', size: 22),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 10,
              child: _Key(height: 52, onTap: () => act(context, ref, 'media.next'), child: const DpIcon('next', size: 22)),
            ),
          ]),
          const SizedBox(height: 3),
        ]),
      ),
    ]);
  }
}

/// LED seek bar: tap or drag to seek.
class _SeekLed extends StatefulWidget {
  const _SeekLed({required this.value, required this.onSeek, this.enabled = true});
  final double value;
  final bool enabled;
  final ValueChanged<double> onSeek;
  @override
  State<_SeekLed> createState() => _SeekLedState();
}

class _SeekLedState extends State<_SeekLed> {
  double? _drag;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        double f(Offset p) => (p.dx / c.maxWidth).clamp(0.0, 1.0);
        final bar = Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: _sg(_drag ?? widget.value, _g, n: 40),
        );
        if (!widget.enabled) return bar;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => widget.onSeek(f(d.localPosition)),
          onHorizontalDragStart: (d) => setState(() => _drag = f(d.localPosition)),
          onHorizontalDragUpdate: (d) => setState(() => _drag = f(d.localPosition)),
          onHorizontalDragEnd: (_) {
            if (_drag != null) widget.onSeek(_drag!);
            setState(() => _drag = null);
          },
          child: bar,
        );
      });
}

// ====================================================================== Hotspot

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
      return LayoutBuilder(builder: (context, c) {
        // Two rows of labelled windows; small dim lines go first when the rows get short.
        final body = c.maxHeight - (alert == null ? 0 : 34 + _gap);
        final inner = (body - _gap) / 2 - 18 - 22;
        final lines = inner >= 108 ? 2 : (inner >= 92 ? 1 : 0);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (alert != null) ...[
            SizedBox(
              height: 34,
              child: PanelSkin.window(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(children: [
                  PanelSkin.led(_r, size: 9),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(alert,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _t.t(13.5, w: FontWeight.w600, c: _r, h: 1.2)
                            .copyWith(shadows: [Shadow(color: _r.withValues(alpha: .38), blurRadius: 10)])),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: _gap),
          ],
          Expanded(
            child: _row([
              (
                64,
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: _row([(1, _hsScore(d, lines)), (1, _hsSpeed(d, lines)), (1, _hsBattery(d, lines))])),
                  const SizedBox(height: _gap),
                  Expanded(child: _row([(1, _hsTemp(d, f, lines)), (1, _hsData(d, lines)), (1, _hsUptime(d, lines))])),
                ]),
              ),
              (
                36,
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SizedBox(height: note == null ? 108 : 124, child: _hsStatus(d, stateC, note, now)),
                  const SizedBox(height: _gap),
                  Expanded(child: _hsEvents(d, now)),
                ]),
              ),
            ]),
          ),
        ]);
      });
    });
  }

  /// Dim helper line(s) pinned to the bottom of a window.
  static Widget _foot(String s, int lines) =>
      lines == 0 ? const SizedBox.shrink() : Text(s, maxLines: lines, overflow: TextOverflow.ellipsis, style: _dim(11.5));

  static Widget _hsScore(HotspotData d, int lines) {
    final gc = hsGradeColor(d.grade, _t);
    return _Cell(
      label: 'Signal score',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          _rd(d.score == null ? '—' : '${d.score!.round()}', 44, c: gc, small: '/100'),
          const Spacer(),
          _rd(hsGradeLabel(d.grade), 18, c: gc),
        ]),
        const SizedBox(height: 8),
        _sg((d.score ?? 0) / 100, gc, n: 16),
        const Spacer(),
        _foot(hsSignalLine(d), lines),
      ]),
    );
  }

  static Widget _hsSpeed(HotspotData d, int lines) {
    final (rx, rxU) = hsBpsParts(d.rxBps);
    final (tx, txU) = hsBpsParts(d.txBps);
    return _Cell(
      label: 'Speed now',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _rd(rx, 40, small: '$rxU down'),
        const SizedBox(height: 6),
        _rd(tx, 26, small: '$txU up', smallScale: .55),
        const Spacer(),
        _foot(hsPingLine(d), lines),
      ]),
    );
  }

  static Widget _hsBattery(HotspotData d, int lines) {
    final pct = d.batteryPct;
    final c = d.lowBattery ? _r : _g;
    final ma = d.currentMa;
    return _Cell(
      label: 'Battery',
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        LedBar(value: (pct ?? 0) / 100, color: c, segments: 10, vertical: true, thickness: 12),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _rd(pct == null ? '—' : '${pct.round()}', 40, c: d.lowBattery ? _r : _wink, small: '%'),
            const SizedBox(height: 6),
            _rd(hsCurrent(ma), 17, c: ma == null || ma == 0 ? _wdim : (ma < 0 ? _a : _g)),
            const Spacer(),
            _foot(hsPowerLine(d), lines),
          ]),
        ),
      ]),
    );
  }

  static Widget _hsTemp(HotspotData d, bool f, int lines) {
    final c = switch (d.heat) {
      HotspotHeat.hot => _r,
      HotspotHeat.warm => _a,
      HotspotHeat.ok => _wink,
    };
    return _Cell(
      label: 'Temperature',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _rd(hsTemp(d.batteryC, fahrenheit: f), 40, c: c),
        const SizedBox(height: 6),
        d.radioResting
            ? Row(children: [
                PanelSkin.led(_r, size: 7),
                const SizedBox(width: 6),
                Text('Radio resting', style: _t.t(12, w: FontWeight.w700, c: _r, h: 1.2)),
              ])
            : Text('Battery', style: _dim(11.5)),
        const Spacer(),
        _foot(hsHeatLine(d, fahrenheit: f), lines),
      ]),
    );
  }

  static Widget _hsData(HotspotData d, int lines) {
    final (v, u) = hsBytesParts(d.cycleUsed);
    final q = d.quotaFrac;
    final qc = q == null ? _sig : (q >= 1 ? _r : (q >= .8 ? _a : _g));
    return _Cell(
      label: 'Data this cycle',
      trailing: q == null ? null : Text('${(q * 100).round()}% of ${hsBytes(d.quota)}', style: _labStyle),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Align(alignment: Alignment.centerLeft, child: _rd(v, 40, small: u)),
        const SizedBox(height: 8),
        q == null ? Text('No quota set', style: _dim(11.5)) : _sg(q.clamp(0, 1).toDouble(), qc, n: 16),
        const Spacer(),
        _foot(hsTodayLine(d), lines),
      ]),
    );
  }

  static Widget _hsUptime(HotspotData d, int lines) {
    Widget col(String v, String k) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _rd(v, 28),
            const SizedBox(height: 4),
            Text(k, maxLines: 1, style: _dim(11)),
          ]),
        );
    return _Cell(
      label: 'Uptime',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [col(hsUptime(d.uptimeS), 'Phone'), const SizedBox(width: 8), col(hsUptime(d.agentUptimeS), 'Agent')]),
        const Spacer(),
        _foot(hsBootLine(d), lines),
      ]),
    );
  }

  static Widget _hsStatus(HotspotData d, Color stateC, String? note, DateTime now) => _Cell(
        label: 'Status',
        icon: 'hotspot',
        trailing: d.name == null ? null : Text(d.name!, style: _labStyle),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            PanelSkin.led(stateC, size: 10),
            const SizedBox(width: 8),
            Flexible(child: _rd(hsStateLabel(d), 30, c: stateC)),
          ]),
          const Spacer(),
          Text('${hsNetwork(d)}${d.operator == null ? '' : ' · ${d.operator}'}',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: _wt(12.5, FontWeight.w600)),
          Text('${hsSharing(d)} · ${hsSeen(d, now)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: _dim(12)),
          if (note != null)
            Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: _t.t(12, w: FontWeight.w600, c: _a, h: 1.3)),
        ]),
      );

  static Widget _hsEvents(HotspotData d, DateTime now) => _Cell(
        label: 'Latest events',
        trailing: d.events.isEmpty ? null : Text('${d.events.length}', style: _labStyle),
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
        child: d.events.isEmpty
            ? Center(child: Text('No events yet', style: _dim(12.5)))
            : LayoutBuilder(builder: (context, c) {
                const rowH = 25.0;
                final n = math.min(d.events.length, (c.maxHeight / rowH).floor());
                return Column(children: [
                  for (final (i, e) in d.events.take(n).indexed)
                    Container(
                      height: rowH,
                      decoration: BoxDecoration(border: i == 0 ? null : const Border(top: BorderSide(color: _wline))),
                      child: Row(children: [
                        PanelSkin.led(e.severity == 'info' ? PanelSkin.off : hsEventColor(e, _t), size: 7),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(e.message,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: e.severity == 'info'
                                  ? _wt(12.5)
                                  : _t.t(12.5, w: FontWeight.w600, c: hsEventColor(e, _t), h: 1.3)),
                        ),
                        const SizedBox(width: 8),
                        Padding(padding: const EdgeInsets.only(top: 3), child: _rd(slackTime(e.ts, now), 15, c: _wdim)),
                      ]),
                    ),
                ]);
              }),
      );
}

// ====================================================================== Timer

class _Timer extends ConsumerWidget {
  const _Timer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(timerProvider);
    final ctl = ref.read(timerProvider.notifier);
    final label = st.running ? 'Pause' : (st.pristine ? 'Start' : 'Resume');

    return _row([
      (170, _Cell(
        label: st.mode.label,
        child: Ticker(
          period: const Duration(seconds: 1),
          builder: (context, now) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: _rd(_digits(st.display(now)), 168, c: st.running ? _sig : _a),
            ),
            const SizedBox(height: 18),
            FractionallySizedBox(
              widthFactor: .88,
              child: _sg(st.progress(now), _sig, n: 25, h: 12),
            ),
          ]),
        ),
      )),
      (100, Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _labRow('Mode'),
        for (final m in TimerMode.values) ...[
          _Key(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            align: MainAxisAlignment.start,
            down: st.mode == m,
            lit: st.mode == m,
            onTap: () => ctl.setMode(m),
            child: Row(children: [
              Text(m.label),
              const Spacer(),
              Text(
                switch (m) {
                  TimerMode.stopwatch => 'count up',
                  TimerMode.countdown => '${st.countdownMin} min',
                  _ => '${m.defaultMin} min',
                },
                style: _t.t(13, w: FontWeight.w500, c: _lab),
              ),
            ]),
          ),
          const SizedBox(height: 7),
        ],
        const SizedBox(height: 2),
        _labRow('Control'),
        Row(children: [
          Expanded(
            child: _Key(height: 46, dark: true, lit: st.running, onTap: ctl.toggle, child: Text(label)),
          ),
          if (st.mode == TimerMode.countdown && !st.running) ...[
            const SizedBox(width: 8),
            _Key(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              onTap: () => ctl.adjust(-1),
              onLongPress: () => ctl.adjust(-5),
              child: const Text('−'),
            ),
            const SizedBox(width: 6),
            _Key(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              onTap: () => ctl.adjust(1),
              onLongPress: () => ctl.adjust(5),
              child: const Text('+'),
            ),
          ],
          const SizedBox(width: 8),
          _Key(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            onTap: ctl.reset,
            child: const DpIcon('reset', size: 18),
          ),
        ]),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.only(left: 3),
          child: Row(children: [
            Text('${st.sessions} of 4 focus sessions today', style: _labStyle),
            for (var i = 0; i < 4; i++) ...[
              const SizedBox(width: 4),
              i < st.sessions
                  ? PanelSkin.led(_sig)
                  : Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFB3B7BC))),
            ],
          ]),
        ),
      ])),
    ]);
  }
}

// ====================================================================== Slack

/// Sender badge: a lit LCD tile with the initials in the sender's colour.
Widget _badge(SlackMsg m, {double size = 28, bool lit = true}) {
  final c = hex(m.senderColor, PanelSkin.b);
  final hsl = HSLColor.fromColor(c);
  final ink = hsl.withLightness(math.max(hsl.lightness, .68)).toColor();
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: c.withValues(alpha: lit ? .2 : .1),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: c.withValues(alpha: lit ? .75 : .35)),
    ),
    alignment: Alignment.center,
    child: Text(
      m.initials,
      style: _t.d(size * .5, c: lit ? ink : _wdim, h: 1).copyWith(
        shadows: lit ? [Shadow(color: c.withValues(alpha: .5), blurRadius: 8)] : null,
      ),
    ),
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
      final count = Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        _rd('${s.unread}', 64, c: hero == null ? _g : _sig, small: 'unread'),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            PanelSkin.led(hero == null ? _g : _sig, size: 7),
            const SizedBox(width: 6),
            Text(hero == null ? 'Clear' : 'New', style: _dim(11.5)),
          ]),
        ),
      ]);

      final Widget body = hero == null
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              count,
              const SizedBox(height: 12),
              Container(height: 1, color: _wline),
              const Spacer(),
              Text('All caught up', style: _wt(17, FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                s.messages.isEmpty ? 'No new messages' : 'No unread messages${s.team == null ? '' : ' in ${s.team}'}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _dim(12.5),
              ),
              const Spacer(),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              count,
              const SizedBox(height: 12),
              Container(height: 1, color: _wline),
              const SizedBox(height: 10),
              Row(children: [
                _badge(hero, size: 32),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(hero.sender, maxLines: 1, overflow: TextOverflow.ellipsis, style: _wt(15, FontWeight.w600)),
                    Text(slackWhere(hero), maxLines: 1, overflow: TextOverflow.ellipsis, style: _dim(12)),
                  ]),
                ),
                const SizedBox(width: 8),
                _rd(slackTime(hero.ts, now), 18, c: _a),
                SlackReadTick(hero, color: _wdim, fill: _a, hit: 36),
              ]),
              const SizedBox(height: 9),
              Expanded(
                child: LayoutBuilder(builder: (context, c) {
                  const size = 16.0, lh = 1.3;
                  final lines = (c.maxHeight / (size * lh)).floor().clamp(1, 5);
                  return Text(hero.text,
                      maxLines: lines, overflow: TextOverflow.ellipsis, style: _t.t(size, c: _wink, h: lh));
                }),
              ),
            ]);

      final left = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: _Cell(
            label: 'Slack',
            icon: 'slack',
            trailing: s.team == null ? null : Text(s.team!, style: _labStyle),
            onTap: hero == null ? null : () => slackOpen(context, ref, hero),
            child: body,
          ),
        ),
        const SizedBox(height: _gap),
        Row(children: [
          Expanded(
            child: _Key(
              lit: hero != null,
              disabled: hero == null,
              onTap: hero == null ? null : () => slackOpen(context, ref, hero),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: const Text('Open', maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
          const SizedBox(width: _gap),
          Expanded(
            child: _Key(
              dark: true,
              disabled: s.unread == 0,
              onTap: s.unread == 0 ? null : () => slackReadAll(context, ref),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: const Text('Mark all read', maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ]),
        const SizedBox(height: 3),
      ]);

      final list = _Cell(
        label: hero == null ? 'Messages' : 'Earlier',
        trailing: rest.isEmpty ? null : Text('${rest.length} ${hero == null ? 'recent' : 'more'}', style: _labStyle),
        padding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
        child: rest.isEmpty
            ? Center(child: _rd(hero == null ? 'NO MESSAGES' : 'NOTHING ELSE', 26, c: _wdim))
            : ListView.builder(
                padding: const EdgeInsets.only(right: 8),
                itemCount: rest.length,
                itemBuilder: (context, i) => _line(context, ref, rest[i], now, last: i == rest.length - 1),
              ),
      );

      return _row([(100, left), (132, list)]);
    });
  }

  Widget _line(BuildContext context, WidgetRef ref, SlackMsg m, DateTime now, {required bool last}) => Press(
        onTap: () => slackOpen(context, ref, m),
        scale: 1,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: _wline))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 11),
              child: PanelSkin.led(m.unread ? _sig : PanelSkin.off, size: 6),
            ),
            const SizedBox(width: 9),
            _badge(m, lit: m.unread),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(
                            text: m.sender,
                            style: m.unread
                                ? _wt(13.5, FontWeight.w600)
                                : _t.t(13.5, w: FontWeight.w500, c: _wdim, h: 1.3)),
                        TextSpan(text: '  ${slackWhere(m)}', style: _dim(12)),
                      ]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _rd(slackTime(m.ts, now), 15, c: m.unread ? _a : _wdim),
                ]),
                const SizedBox(height: 2),
                Text(m.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: m.unread ? _wt(12.5) : _t.t(12.5, c: _wdim.withValues(alpha: .8), h: 1.3)),
              ]),
            ),
            SlackReadTick(m, color: _wdim, fill: _a),
          ]),
        ),
      );
}

// ====================================================================== GitHub

class _Github extends ConsumerWidget {
  const _Github();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = topicData<GithubData>(ref, codeTopic(ref))!;
    final now = DateTime.now();
    final td = now.weekday % 7;
    final mx = maxOf([...g.thisWeek, ...g.lastWeek]);
    final repoMax = g.topRepos.isEmpty ? 1 : g.topRepos.first.count;
    final best = g.bestDay;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Padding(padding: const EdgeInsets.only(left: 3), child: Text('Last year', style: _labStyle)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
                '${_comma(g.total)} contributions, ${g.commits} commits, ${g.private} private, '
                '${g.issues} issue${g.issues == 1 ? '' : 's'}',
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _labStyle),
          ),
          const SizedBox(width: 16),
          _keyTabs(codeSources, ref.watch(codeSourceProvider), ref.read(codeSourceProvider.notifier).set),
        ]),
      ),
      PanelSkin.window(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Heatmap(
          weeks: g.weeks,
          style: HeatStyle.panel,
          labelStyle: _t.t(9, w: FontWeight.w600, c: _wdim, h: 1),
          dayLabels: true,
        ),
      ),
      const SizedBox(height: _gap),
      Expanded(
        child: _row([
          (80, _Cell(
            label: 'Streak',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _rd('${g.streakCurrent}', 72, c: _g, small: g.streakCurrent == 1 ? 'day' : 'days'),
              const Spacer(),
              Text.rich(TextSpan(style: _dim(), children: [
                const TextSpan(text: 'Longest '),
                TextSpan(text: '${g.streakLongest} days', style: _wt()),
                const TextSpan(text: '\nBest '),
                TextSpan(
                    text: best == null ? '—' : '${best.count} on ${month3(best.date)} ${best.date.day}', style: _wt()),
              ])),
            ]),
          )),
          (100, _Cell(
            label: 'This week',
            trailing: Text('${g.weekDelta >= 0 ? '+' : ''}${g.weekDelta} vs last',
                style: _t.t(11, w: FontWeight.w600, c: const Color(0xFF1F8A4C), h: 1.3)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Align(alignment: Alignment.topLeft, child: _rd('${g.weekTotal}', 44)),
              const SizedBox(width: 12),
              Expanded(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (var i = 0; i < 7; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: _vbar(
                        ((i < g.thisWeek.length ? g.thisWeek[i] : null) ?? 0) / mx,
                        _g,
                        'SMTWTFS'[i],
                        n: 10,
                        maxW: 18,
                        bold: i == td,
                      ),
                    ),
                  ],
                ]),
              ),
            ]),
          )),
          (110, _Cell(
            label: topReposLabel(ref),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final r in g.topRepos.take(4))
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Expanded(child: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _wt(12.5))),
                      _rd('${r.count}', 16),
                    ]),
                    const SizedBox(height: 3),
                    _sg(r.count / repoMax, _g, n: 24, h: 5),
                  ]),
                ),
              if (g.topRepos.isEmpty) Text('No contributions yet', style: _dim()),
            ]),
          )),
        ]),
      ),
    ]);
  }
}

// ====================================================================== Shortcuts

class _Shortcuts extends ConsumerWidget {
  const _Shortcuts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = topicData<ShortcutsData>(ref, 'shortcuts')!;
    final tiles = orderedTiles(s.tiles, ref.watch(settingsProvider).tileOrder);
    final cols = 4;
    final rows = (tiles.length / cols).ceil().clamp(1, 3);
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Column(children: [
        for (var r = 0; r < rows; r++) ...[
          if (r > 0) const SizedBox(height: 14),
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var c = 0; c < cols; c++) ...[
                if (c > 0) const SizedBox(width: 14),
                Expanded(
                  child: r * cols + c < tiles.length
                      ? _Cap(
                          tile: tiles[r * cols + c],
                          onTap: () => act(context, ref, 'shortcut.run', {'id': tiles[r * cols + c].id}),
                        )
                      : const SizedBox(),
                ),
              ],
            ]),
          ),
        ],
      ]),
    );
  }
}

/// Big keycap (`.cap`): light, dark (terminal) or signal-orange (lock).
class _Cap extends StatefulWidget {
  const _Cap({required this.tile, required this.onTap});
  final Tile tile;
  final VoidCallback onTap;
  @override
  State<_Cap> createState() => _CapState();
}

class _CapState extends State<_Cap> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tile;
    final tone = t.id == 'lock' ? 2 : (t.id == 'terminal' ? 1 : 0);
    final on = t.active;
    final pressed = _down;
    final (grad, edge, fg, sub) = switch (tone) {
      2 => (const [Color(0xFFFF7A45), Color(0xFFF0531A)], const Color(0xFFB33A0E), const Color(0xFFFFFFFF), const Color(0xCCFFFFFF)),
      1 => (const [Color(0xFF3A3E43), Color(0xFF25292D)], const Color(0xFF0D0F11), const Color(0xFFF2F3F4), const Color(0xFF9BA1A8)),
      _ => (const [Color(0xFFF3F4F6), Color(0xFFD8DBDF)], const Color(0xFF969BA1), _ink, _lab),
    };
    final dy = pressed ? 3.0 : (on ? 2.0 : 0.0);
    final edgeH = pressed ? 1.0 : (on ? 2.0 : 4.0);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        transform: Matrix4.translationValues(0, dy, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: grad),
          border: Border(top: BorderSide(color: tone == 0 ? const Color(0xFFFFFFFF) : const Color(0x33FFFFFF))),
          boxShadow: [
            BoxShadow(color: edge, offset: Offset(0, edgeH)),
            BoxShadow(color: const Color(0x33000000), offset: Offset(0, edgeH + 3), blurRadius: pressed ? 4 : 10),
          ],
        ),
        child: Stack(children: [
          Positioned(
            top: 9,
            right: 10,
            child: on
                ? PanelSkin.led(_r, size: 7)
                : Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: tone == 2 ? const Color(0x66FFFFFF) : const Color(0xFFB3B7BC))),
          ),
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DpIcon(tileIcon(t), size: 34, stroke: 1.6, color: fg),
              const SizedBox(height: 10),
              Text(tileLabel(t), textAlign: TextAlign.center, style: _t.t(13.5, w: FontWeight.w600, c: fg, h: 1.2)),
              if (t.detail != null) ...[
                const SizedBox(height: 4),
                Text(t.detail!, style: _t.t(11, c: sub, h: 1.2)),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}
