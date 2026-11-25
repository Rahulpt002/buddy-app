// Concept 11 — Expressive pages (Material 3 Expressive). Sizes follow
// deskpanel-concept-11-expressive.html (CSS px = logical px).
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
import '../widgets/common.dart';
import 'expressive.dart';

const _gap = 10.0;
const _clear = Color(0x00000000);

Widget expressivePage(PageId id) => switch (id) {
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

// ------------------------------------------------------------------ parts

enum _Tone { plain, p, t, s }

/// `.card` with tonal variants (`.p` primary, `.t` tertiary, `.s` secondary containers).
Widget _card(Widget child, {_Tone tone = _Tone.plain, VoidCallback? onTap, EdgeInsets? pad}) {
  final (bg, fg) = switch (tone) {
    _Tone.plain => (XC.sc, XC.on),
    _Tone.p => (XC.pric, XC.onpric),
    _Tone.t => (XC.terc, XC.onterc),
    _Tone.s => (XC.secc, XC.onsecc),
  };
  Widget c = Container(
    padding: pad ?? const EdgeInsets.fromLTRB(16, 14, 16, 14),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(26)),
    child: DefaultTextStyle.merge(
      style: TextStyle(color: fg),
      child: child,
    ),
  );
  if (onTap != null) c = Press(onTap: onTap, scale: .985, child: c);
  return c;
}

/// `.lab` inside a tonal card: inherit the card colour at 75 %.
TextStyle _labOn(_Tone tone) => switch (tone) {
  _Tone.plain => xlab(),
  _Tone.p => xlab(c: XC.onpric.withValues(alpha: .75)),
  _Tone.t => xlab(c: XC.onterc.withValues(alpha: .75)),
  _Tone.s => xlab(c: XC.onsecc.withValues(alpha: .75)),
};

TextStyle _body({Color? c, double size = 13, double w = 400}) => xt(size, w: w, c: c, h: 1.35);
TextStyle get _onv => _body(c: XC.onv);

Widget _ell(String s, TextStyle st) => Text(s, maxLines: 1, overflow: TextOverflow.ellipsis, style: st);

/// Display number + small unit, baseline aligned.
Widget _disp(String v, String unit, double size, {Color? c, bool anim = false, double? value}) => Row(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.baseline,
  textBaseline: TextBaseline.alphabetic,
  children: [
    value != null && anim ? AnimNum(value, style: xdisp(size, c: c)) : Text(v, style: xdisp(size, c: c)),
    if (unit.isNotEmpty) ...[const SizedBox(width: 2), Text(unit, style: xdispSmall(size, c: c))],
  ],
);

/// Filled / tonal / text button (`.btn`). Squares its corners while pressed.
class _Btn extends StatefulWidget {
  const _Btn(
    this.label, {
    this.onTap,
    this.icon,
    this.tonal = false,
    this.text = false,
    this.height = 40,
    this.padH = 20,
    this.size = 13.5,
    this.radius,
  });
  final String label;
  final String? icon;
  final VoidCallback? onTap;
  final bool tonal, text;
  final double height, padH, size;
  final double? radius;
  @override
  State<_Btn> createState() => _BtnState();
}

class _BtnState extends State<_Btn> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = widget.text ? (_clear, XC.pri) : (widget.tonal ? (XC.secc, XC.onsecc) : (XC.pri, XC.onpri));
    final r = _down ? 12.0 : (widget.radius ?? 99);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: Opacity(
        opacity: widget.onTap == null ? .5 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          height: widget.height,
          padding: EdgeInsets.symmetric(horizontal: widget.text ? 12 : widget.padH),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(r)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[DpIcon(widget.icon!, size: 18, color: fg), const SizedBox(width: 8)],
              Text(widget.label, style: xt(widget.size, w: 600, c: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Connected button group (`.bgrp`): outer ends round, selected segment becomes a pill.
class _Bgrp extends StatelessWidget {
  const _Bgrp({required this.items, required this.value, required this.onChanged});
  final List<String> items;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final (i, s) in items.indexed) ...[
        if (i > 0) const SizedBox(width: 2),
        Press(
          onTap: () => onChanged(i),
          scale: 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: i == value ? XC.pri : XC.secc,
              borderRadius: i == value
                  ? BorderRadius.circular(99)
                  : BorderRadius.horizontal(
                      left: Radius.circular(i == 0 ? 99 : 8),
                      right: Radius.circular(i == items.length - 1 ? 99 : 8),
                    ),
            ),
            child: Text(s, style: xt(13, w: 600, c: i == value ? XC.onpri : XC.onsecc)),
          ),
        ),
      ],
    ],
  );
}

/// Icon button (`.ib`).
Widget _ib(
  String icon,
  VoidCallback? onTap, {
  double w = 44,
  double? h,
  bool pri = false,
  double radius = 99,
  double iconSize = 18,
}) => Press(
  onTap: onTap,
  child: AnimatedContainer(
    duration: const Duration(milliseconds: 250),
    width: w,
    height: h ?? w,
    decoration: BoxDecoration(color: pri ? XC.pri : XC.secc, borderRadius: BorderRadius.circular(radius)),
    alignment: Alignment.center,
    child: DpIcon(icon, size: iconSize, color: pri ? XC.onpri : XC.onsecc),
  ),
);

/// List item (`.li`).
Widget _li(Widget lead, String title, String sup, {Widget? trail, bool first = false}) => Container(
  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
  decoration: BoxDecoration(
    border: first ? null : const Border(top: BorderSide(color: XC.outv)),
  ),
  child: Row(
    children: [
      lead,
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _ell(title, xt(14.5, w: 600, h: 1.3)),
            _ell(sup, xt(12.5, c: XC.onv, h: 1.3)),
          ],
        ),
      ),
      if (trail != null) ...[const SizedBox(width: 14), trail],
    ],
  ),
);

Widget _lead(Widget child) => Container(
  width: 40,
  height: 40,
  decoration: const BoxDecoration(color: XC.secc, shape: BoxShape.circle),
  alignment: Alignment.center,
  child: OverflowBox(
    maxWidth: 80,
    child: DefaultTextStyle.merge(
      style: xt(17, w: 650, c: XC.onsecc),
      child: child,
    ),
  ),
);

String _inText(CalEvent e, DateTime now) {
  if (!e.start.isAfter(now)) return 'Now';
  final d = e.start.difference(now);
  return d.inMinutes < 1 ? 'Starting now' : 'in ${dur(d)}';
}

// ------------------------------------------------------------------ wavy indicators

/// Wavy linear progress indicator. The wave ripples only while [moving].
class _Wave extends StatefulWidget {
  const _Wave(this.value, {this.color = XC.pri, this.moving = true, this.height = 14});
  final double value;
  final Color color;
  final bool moving;
  final double height;
  @override
  State<_Wave> createState() => _WaveState();
}

class _WaveState extends State<_Wave> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    if (widget.moving) _c.repeat();
  }

  @override
  void didUpdateWidget(_Wave old) {
    super.didUpdateWidget(old);
    if (widget.moving && !_c.isAnimating) _c.repeat();
    if (!widget.moving && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: widget.value.isNaN ? 0 : widget.value.clamp(0.0, 1.0)),
    duration: const Duration(milliseconds: 500),
    builder: (context, v, _) => SizedBox(
      height: widget.height,
      width: double.infinity,
      child: RepaintBoundary(child: CustomPaint(painter: _WavePainter(v, _c, widget.color))),
    ),
  );
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.p, this.anim, this.color) : super(repaint: anim);
  final double p;
  final Animation<double> anim;
  final Color color;

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height, mid = h / 2;
    const a = 3.0, l = 20.0;
    final x1 = w * p;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    if (x1 > 0) {
      final ph = anim.value * l;
      final path = Path();
      for (var x = -l; x <= w + l; x += 2) {
        final y = mid + a * math.sin((x + ph) / l * 2 * math.pi);
        x == -l ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      c.save();
      c.clipRect(Rect.fromLTRB(-4, -4, x1, h + 4));
      c.drawPath(path, stroke..color = color);
      c.restore();
    }
    final off0 = math.max(2.0, x1 + 8);
    if (off0 < w - 8) c.drawLine(Offset(off0, mid), Offset(w - 8, mid), stroke..color = XC.secc);
    c.drawCircle(Offset(w - 2, mid), 2, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_WavePainter o) => o.p != p || o.color != color;
}

/// Circular wavy progress (`.ring`): a full track circle with a wavy arc on top.
class _Ring extends StatefulWidget {
  const _Ring(this.value, {required this.size, this.sw = 5, this.color = XC.pri, this.child, this.moving = false});
  final double value, size, sw;
  final Color color;
  final Widget? child;
  final bool moving;
  @override
  State<_Ring> createState() => _RingState();
}

class _RingState extends State<_Ring> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 4));

  @override
  void initState() {
    super.initState();
    if (widget.moving) _c.repeat();
  }

  @override
  void didUpdateWidget(_Ring old) {
    super.didUpdateWidget(old);
    if (widget.moving && !_c.isAnimating) _c.repeat();
    if (!widget.moving && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final side = math.min(widget.size, box.maxHeight.isFinite ? box.maxHeight : widget.size);
      return SizedBox(
        width: side,
        height: side,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: widget.value.isNaN ? 0 : widget.value.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, v, child) =>
              CustomPaint(painter: _RingPainter(v, _c, widget.sw, widget.color, XC.secc), child: child),
          child: widget.child == null
              ? null
              : Center(
                  child: FittedBox(fit: BoxFit.scaleDown, child: widget.child),
                ),
        ),
      );
    },
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.anim, this.sw, this.color, this.track) : super(repaint: anim);
  final double v, sw;
  final Animation<double> anim;
  final Color color, track;

  @override
  void paint(Canvas c, Size s) {
    final k = s.width / 100;
    c.save();
    c.scale(k);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round;
    c.drawCircle(const Offset(50, 50), 40, p..color = track);
    if (v > .002) {
      final ph = anim.value * 2 * math.pi;
      final path = Path();
      final n = math.max(2, (360 * v).round());
      for (var i = 0; i <= n; i++) {
        final deg = i / n * 360 * v;
        final t = (deg - 90) * math.pi / 180;
        final r = 40 + 1.35 * math.sin(deg * math.pi / 180 * 16 - ph);
        final o = Offset(50 + r * math.cos(t), 50 + r * math.sin(t));
        i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      c.drawPath(path, p..color = color);
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.v != v || o.color != color || o.track != track;
}

// ------------------------------------------------------------------ Home

class _Home extends ConsumerWidget {
  const _Home();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void go(PageId p) => PageNav.go(context, p);
    return Ticker(
      builder: (context, now) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 297, child: _clock(ref, now, () => go(PageId.calendar))),
          const SizedBox(width: _gap),
          Expanded(
            flex: 526,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _claude(ref, now, () => go(PageId.claude))),
                      const SizedBox(width: _gap),
                      Expanded(child: _weather(ref, () => go(PageId.weather))),
                    ],
                  ),
                ),
                const SizedBox(height: _gap),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _slack(ref, now, () => go(PageId.slack))),
                      const SizedBox(width: _gap),
                      Expanded(child: _music(context, ref, () => go(PageId.music))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _clock(WidgetRef ref, DateTime now, VoidCallback onTap) {
    final h24 = ref.watch(settingsProvider.select((s) => s.clock24));
    final events = ref.watch(calendarEventsProvider);
    final n = nextEvent(events, now);
    return _card(
      tone: _Tone.p,
      onTap: onTap,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Right now', style: _labOn(_Tone.p)),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: _disp(clock(now, h24: h24), h24 ? '' : ampm(now), 120),
          ),
          const Spacer(),
          Text('Next up', style: _labOn(_Tone.p)),
          const SizedBox(height: 6),
          Row(
            children: [
              _ib('calendar', null, w: 40, pri: true),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ell(n?.title ?? 'Nothing else today', xt(15, w: 700, h: 1.3)),
                    _ell(
                      n == null
                          ? 'Free until tomorrow'
                          : '${_inText(n, now)}${n.location != null ? ', ${n.location}' : ''}',
                      _body(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _claude(WidgetRef ref, DateTime now, VoidCallback onTap) {
    final c = topicData<ClaudeData>(ref, 'claude');
    final five = limitPct(c?.fiveHour, now), week = limitPct(c?.sevenDay, now);
    return _card(
      onTap: onTap,
      Row(
        children: [
          _Ring(
            five / 100,
            size: 96,
            color: five >= 80 ? XC.err : XC.pri,
            child: c?.fiveHour == null ? Text('—', style: xdisp(30)) : _disp('${five.round()}', '%', 30),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ell('Claude, 5-hour', xttl()),
                _ell(resetsIn(c?.fiveHour, now), _onv),
                const SizedBox(height: 8),
                _ell(c?.sevenDay == null ? 'Weekly —' : 'Weekly ${week.round()}%', xlab()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _weather(WidgetRef ref, VoidCallback onTap) {
    final w = ref.watch(weatherProvider);
    final f = ref.watch(settingsProvider.select((s) => s.fahrenheit));
    String rain() {
      if (w == null) return '';
      for (final (i, d) in w.days.indexed) {
        if (d.precipPct >= 50) return 'Rain ${i == 0 ? 'today' : weekday(d.date)}';
      }
      return 'Dry all week';
    }

    return _card(
      tone: _Tone.t,
      onTap: onTap,
      Row(
        children: [
          XShapeBox(
            shape: XShape.sunny,
            color: XC.ter,
            size: 100,
            child: Text(w == null ? '—' : '${temp(w.now.tempC, f)}°', style: xdisp(38, c: XC.white)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ell(w?.now.condition ?? 'Set a location', xttl()),
                if (w != null && w.days.isNotEmpty)
                  _ell('High ${temp(w.days.first.hiC, f)}°, low ${temp(w.days.first.loC, f)}°', _body(c: XC.onv)),
                const SizedBox(height: 8),
                _ell(rain(), _labOn(_Tone.t)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Slack: unread count up top, the newest unread message below (or a calm line).
  Widget _slack(WidgetRef ref, DateTime now, VoidCallback onTap) {
    final s = topicData<SlackData>(ref, 'slack');
    final info = slackHome(ref);
    final m = info.latest;
    return _card(
      onTap: onTap,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ell(info.headline == 'Slack' ? 'Messages' : 'Slack', xlab()),
                    const SizedBox(height: 2),
                    _ell(info.headline, xt(24, w: 650, opsz: 36, h: 1.15)),
                  ],
                ),
              ),
              XShapeBox(
                shape: XShape.cookie12,
                color: m != null ? XC.pri : XC.secc,
                size: 44,
                child: DpIcon('slack', size: 20, color: m != null ? XC.onpri : XC.onsecc),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
            decoration: BoxDecoration(color: XC.surface, borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                m != null
                    ? _avatar(m, 40)
                    : const XShapeBox(
                        shape: XShape.flower,
                        color: XC.secc,
                        size: 40,
                        child: DpIcon('slack', size: 18, color: XC.onsecc),
                      ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: m == null
                        ? [_ell(info.detail, xt(14, w: 550, h: 1.3)), _ell(s?.team ?? (info.detail == 'Not set up' ? 'Tap to see how' : 'Messages'), _onv)]
                        : [
                            Row(
                              children: [
                                Expanded(child: _ell(m.sender, xt(14, w: 700, h: 1.3))),
                                const SizedBox(width: 8),
                                Text(slackTime(m.ts, now), style: xt(12, w: 650, c: XC.pri, h: 1.3)),
                              ],
                            ),
                            _ell(m.text, _onv),
                          ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _music(BuildContext context, WidgetRef ref, VoidCallback onTap) {
    final m = topicData<MediaData>(ref, 'media');
    final art = topicData<MediaArt>(ref, 'media.art');
    return _card(
      onTap: onTap,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 76,
                  height: 76,
                  child: XShapeClip(
                    shape: XShape.cookie9,
                    child: AlbumArt(title: m?.title ?? 'DeskPanel', b64: art?.artId == m?.artId ? art?.b64 : null),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ell(m?.title ?? 'Nothing playing', xttl()),
                      _ell(m?.artist ?? (m == null ? 'Laptop not connected' : ''), _onv),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: m?.title == null
                    ? const _Wave(0, moving: false)
                    : Ticker(
                        period: const Duration(seconds: 1),
                        builder: (context, now) {
                          final pos = m!.positionNow(now, skewMs: ref.read(agentProvider.notifier).clockSkewMs);
                          return _Wave((m.durationMs ?? 0) == 0 ? 0 : pos / m.durationMs!, moving: m.playing);
                        },
                      ),
              ),
              const SizedBox(width: 10),
              _ib(
                m?.playing == true ? 'pause' : 'play',
                m?.title == null ? null : () => act(context, ref, 'media.play_pause'),
                w: 40,
                pri: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ System

class _System extends ConsumerWidget {
  const _System();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(systemTabProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: _Bgrp(
            items: const ['Laptop', 'Internet'],
            value: tab,
            onChanged: ref.read(systemTabProvider.notifier).set,
          ),
        ),
        const SizedBox(height: _gap),
        Expanded(child: tab == 0 ? const _Pc() : const _Net()),
      ],
    );
  }
}

class _Pc extends ConsumerWidget {
  const _Pc();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = topicData<SystemData>(ref, 'system')!;
    final g = s.gpu;
    const gb = 1024 * 1024 * 1024;
    final (down, downU) = rate(s.downBps);
    final (up, upU) = rate(s.upBps);
    final vramPct = g.vramUsed != null && (g.vramTotal ?? 0) > 0 ? g.vramUsed! / g.vramTotal! * 100 : null;
    Widget gauge(double? pct, String label, String sub, Color c) => Expanded(
      child: _card(
        Row(
          children: [
            _Ring(
              (pct ?? 0) / 100,
              size: 86,
              color: c,
              child: pct == null ? Text('N/A', style: xdisp(24)) : _disp('', '%', 28, anim: true, value: pct),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(label, style: xttl()),
                  ),
                  _ell(sub, _onv),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            gauge(s.cpu.pct, 'Processor', s.cpu.cores != null ? '${s.cpu.cores} cores' : 'CPU', XC.pri),
            const SizedBox(width: _gap),
            gauge(
              g.available ? g.pct : null,
              'Graphics',
              !g.available ? 'Not available' : (g.tempC != null ? '${g.tempC!.round()}°C' : (g.model ?? '')),
              XC.ter,
            ),
            const SizedBox(width: _gap),
            gauge(
              s.ramTotal == 0 ? null : s.ramUsed / s.ramTotal * 100,
              'Memory',
              '${(s.ramUsed / gb).toStringAsFixed(1)}/${(s.ramTotal / gb).round()} GB',
              XC.pri,
            ),
            const SizedBox(width: _gap),
            gauge(
              vramPct,
              g.vramLabel,
              vramPct == null ? 'N/A' : '${(g.vramUsed! / gb).toStringAsFixed(1)}/${(g.vramTotal! / gb).round()} GB',
              XC.ter,
            ),
          ],
        ),
        const SizedBox(height: _gap),
        Expanded(
          child: _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text('Last minute', style: xttl()),
                    const SizedBox(width: 10),
                    XChip(icon: 'down', label: '$down $downU', iconColor: XC.on),
                    const SizedBox(width: 10),
                    XChip(icon: 'up', label: '$up $upU', iconColor: XC.on),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${s.cpu.model}${g.model != null ? ', ${g.model}' : ''}, disk ${s.diskPct.round()}%',
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: xlab(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: CustomPaint(
                    painter: _Area(
                      [
                        LineSeriesX(s.cpuHistory, XC.pri, 3.5, fill: true),
                        if (g.available) LineSeriesX(s.gpuHistory, XC.ter, 3),
                      ],
                      100,
                      .7,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class LineSeriesX {
  const LineSeriesX(this.values, this.color, this.width, {this.fill = false});
  final List<double?> values;
  final Color color;
  final double width;
  final bool fill;
}

/// Line chart with a soft primary-container area under the first filled series.
class _Area extends CustomPainter {
  _Area(this.series, this.max, this.fillAlpha);
  final List<LineSeriesX> series;
  final double max, fillAlpha;

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    const pad = 4.0;
    double y(double v) => pad + (h - 2 * pad) * (1 - v.clamp(0, max) / max);
    Path? line(List<double?> vals) {
      if (vals.length < 2) return null;
      final dx = w / (vals.length - 1);
      final p = Path();
      var pen = false;
      double px = 0, py = 0;
      for (var i = 0; i < vals.length; i++) {
        final v = vals[i];
        if (v == null) {
          pen = false;
          continue;
        }
        final x = i * dx, yy = y(v);
        if (!pen) {
          p.moveTo(x, yy);
          pen = true;
        } else {
          final xm = (px + x) / 2;
          p.cubicTo(xm, py, xm, yy, x, yy);
        }
        px = x;
        py = yy;
      }
      return p;
    }

    final fills = series.where((e) => e.fill);
    for (final f in fills) {
      final p = line(f.values);
      if (p == null) continue;
      final area = Path.from(p)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      c.drawPath(area, Paint()..color = XC.pric.withValues(alpha: fillAlpha));
    }
    // Draw unfilled series first so the primary line sits on top.
    for (final ser in [...series.where((e) => !e.fill), ...fills]) {
      final p = line(ser.values);
      if (p == null) continue;
      c.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ser.width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = ser.color,
      );
    }
  }

  @override
  bool shouldRepaint(_Area o) => true;
}

class _Net extends ConsumerWidget {
  const _Net();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = topicData<NetworkData>(ref, 'network');
    final live = ref.watch(agentProvider).live;
    if (n == null) return _card(Center(child: Text('Waiting for network data…', style: _onv)));
    final now = DateTime.now();
    final st = n.speedtest;
    final last = st.last;
    final prog = st.progress;
    final shownDown = st.running ? (prog?.downBps ?? 0) : (last?.downBps ?? 0);
    final shownUp = st.running ? (prog?.upBps ?? 0) : (last?.upBps ?? 0);
    final online = live && n.online;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 10,
                    child: _card(
                      Row(
                        children: [
                          XShapeBox(
                            shape: XShape.cookie12,
                            color: XC.pri,
                            size: 96,
                            child: n.latencyMs == null
                                ? Text('—', style: xdisp(34, c: XC.white))
                                : _disp('', 'ms', 34, c: XC.white, anim: true, value: n.latencyMs),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Latency', style: xttl()),
                                Text(
                                  'Jitter ${n.jitterMs?.toStringAsFixed(1) ?? '—'} ms\n${n.lossPct.round()}% loss',
                                  style: _onv,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: _gap),
                  Expanded(
                    flex: 10,
                    child: _card(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Connection', style: xttl()),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              XChip(
                                icon: online ? 'wifi' : 'off',
                                label: !live ? 'Unknown' : (n.online ? 'Online' : 'Offline'),
                                filled: true,
                                iconColor: online ? XC.pri : XC.err,
                              ),
                              if (n.onlineSince != null)
                                XChip(icon: 'clock', label: 'Up ${durLong(now.difference(n.onlineSince!))}'),
                              XChip(icon: 'down', label: '${bytes(n.usageToday)} today', iconColor: XC.on),
                              XChip(label: '${bytes(n.usageMonth, digits: 0)} this month'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: _gap),
                  Expanded(
                    flex: 12,
                    child: _card(
                      tone: _Tone.s,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Speed test', style: xttl()),
                          const SizedBox(height: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                _disp(last == null && !st.running ? '—' : mbps(shownDown), 'down', 44),
                                const SizedBox(width: 14),
                                _disp(last == null && !st.running ? '—' : mbps(shownUp), 'up', 44),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          _ell(
                            st.running
                                ? 'Testing now'
                                : last == null
                                ? 'Never tested'
                                : 'Tested ${ago(now.difference(last.at))}, ping ${last.pingMs.round()} ms',
                            _body(c: XC.onv),
                          ),
                          if (st.running) ...[const SizedBox(height: 8), _Wave((prog?.pct ?? 0) / 100)],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: _gap),
            Expanded(
              child: _card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Latency, last 2 minutes', style: xttl()),
                    Expanded(
                      child: CustomPaint(
                        painter: _Area([LineSeriesX(n.latencyHistory, XC.pri, 3, fill: true)], 50, .6),
                        size: Size.infinite,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        Positioned(
          right: 2,
          bottom: 12,
          child: _Fab(
            icon: 'down',
            label: st.running ? 'Testing…' : 'Run test',
            onTap: st.running
                ? null
                : () => act(context, ref, 'speedtest.run', const {}, null, null, const Duration(seconds: 90)),
          ),
        ),
      ],
    );
  }
}

/// Extended FAB (`.fab`): rounds further while pressed.
class _Fab extends StatefulWidget {
  const _Fab({required this.icon, required this.label, this.onTap});
  final String icon, label;
  final VoidCallback? onTap;
  @override
  State<_Fab> createState() => _FabState();
}

class _FabState extends State<_Fab> {
  bool _down = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
    onTapUp: (_) => setState(() => _down = false),
    onTapCancel: () => setState(() => _down = false),
    onTap: widget.onTap,
    child: Opacity(
      opacity: widget.onTap == null ? .6 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 56,
        padding: const EdgeInsets.fromLTRB(18, 0, 22, 0),
        decoration: BoxDecoration(
          color: XC.pric,
          borderRadius: BorderRadius.circular(_down ? 28 : 18),
          boxShadow: const [
            BoxShadow(color: Color(0x24000000), blurRadius: 8, offset: Offset(0, 3)),
            BoxShadow(color: Color(0x1A000000), blurRadius: 3, offset: Offset(0, 1)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DpIcon(widget.icon, size: 22, color: XC.onpric),
            const SizedBox(width: 10),
            Text(widget.label, style: xt(14, w: 650, c: XC.onpric)),
          ],
        ),
      ),
    ),
  );
}

// ------------------------------------------------------------------ Claude

class _Claude extends ConsumerWidget {
  const _Claude();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = topicData<ClaudeData>(ref, 'claude')!;
    final h24 = ref.watch(settingsProvider.select((s) => s.clock24));
    return Ticker(
      builder: (context, now) {
        final five = limitPct(c.fiveHour, now), week = limitPct(c.sevenDay, now);
        final reset = c.fiveHour?.resetsAt;
        final resetTxt = c.fiveHour == null
            ? '—'
            : c.fiveHour!.isExpired(now) || reset == null
            ? 'now'
            : dur(reset.difference(now));
        final peak = maxOf(c.days.map((d) => d.tokens));
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 12,
              child: _card(
                tone: _Tone.p,
                Row(
                  children: [
                    _Ring(
                      five / 100,
                      size: 170,
                      sw: 6,
                      color: five >= 80 ? XC.err : XC.pri,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          c.fiveHour == null
                              ? Text('—', style: xdisp(58))
                              : _disp('', '%', 58, anim: true, value: five),
                          Text('5-hour', style: _labOn(_Tone.p)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Resets in', style: xttl()),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(resetTxt, style: xdisp(34)),
                          ),
                          const SizedBox(height: 10),
                          Text('Weekly limit', style: _labOn(_Tone.p)),
                          const SizedBox(height: 6),
                          SizedBox(width: 120, child: _Wave(week / 100, color: XC.ter, moving: false)),
                          const SizedBox(height: 4),
                          Text(
                            c.sevenDay == null
                                ? 'No data yet'
                                : '${week.round()}% used, ${_lower(resetsAt(c.sevenDay, now, h24: h24))}',
                            maxLines: 3,
                            style: _body(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: _gap),
            Expanded(
              flex: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _card(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Today', style: xttl()),
                          _li(
                            _lead(const DpIcon('claude', size: 17, color: XC.onsecc)),
                            '${compact(c.tokens)} tokens',
                            '${compact(c.outputTokens)} output',
                            first: true,
                          ),
                          _li(
                            _lead(const Text('#')),
                            '${c.messages} messages',
                            '${compact(c.lastHourTokens)} in the last hour',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: _gap),
                  Expanded(
                    child: _card(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Text('Tokens, last 7 days', style: xttl()),
                              const Spacer(),
                              for (final m in c.modelsToday.take(3)) ...[
                                const SizedBox(width: 6),
                                XChip(label: '${modelName(m.family)} ${(m.tokens / 1e6).toStringAsFixed(1)}M'),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: BarTapTip(
                              count: c.days.length,
                              label: (i) => dayTokensLabel(c.days[i], now),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (final (i, d) in c.days.indexed) ...[
                                    if (i > 0) const SizedBox(width: 8),
                                    Expanded(
                                      child: _pillBar(
                                        d.tokens / peak,
                                        dayLabel(d.date, now),
                                        i == c.days.length - 1,
                                        30,
                                        12,
                                        opacity: i == c.days.length - 1 ? 1 : .55 + d.tokens / peak * .45,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

String _lower(String s) => s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

/// Rounded bar + label for the bar charts.
Widget _pillBar(double frac, String label, bool hi, double maxW, double minH, {double opacity = 1}) => Column(
  children: [
    Expanded(
      child: LayoutBuilder(
        builder: (context, c) => Align(
          alignment: Alignment.bottomCenter,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: math.max(minH, c.maxHeight * .92 * frac.clamp(0, 1))),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder: (context, h, _) => Container(
              width: math.min(maxW, c.maxWidth),
              height: h,
              decoration: BoxDecoration(
                color: (hi ? XC.ter : XC.pri).withValues(alpha: opacity),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ),
      ),
    ),
    const SizedBox(height: 4),
    Text(
      label,
      style: hi ? xlab(c: XC.ter).copyWith(fontWeight: FontWeight.w700) : xlab(),
    ),
  ],
);

// ------------------------------------------------------------------ Calendar

class _Calendar extends ConsumerWidget {
  const _Calendar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(calendarEventsProvider);
    final h24 = ref.watch(settingsProvider.select((s) => s.clock24));
    return Ticker(
      builder: (context, now) {
        final split = splitEvents(events, now);
        final n = nextEvent(events, now);
        final others = split.today.where((e) => e != n && e.end.isAfter(now)).toList();
        String hm(DateTime t) => h24 ? clock(t, h24: true) : clock(t);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 100,
              child: _card(
                tone: _Tone.p,
                n == null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Next up', style: _labOn(_Tone.p)),
                          const SizedBox(height: 8),
                          Text('Nothing else today', style: xt(30, w: 600, opsz: 36, h: 1.2)),
                          const Spacer(),
                          Text('Free until tomorrow', style: _body(size: 15)),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Next up', style: _labOn(_Tone.p)),
                          const SizedBox(height: 8),
                          Text(
                            n.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: xt(30, w: 600, opsz: 36, h: 1.2),
                          ),
                          const Spacer(),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(_inText(n, now), style: xdisp(96)),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              XChip(
                                icon: 'clock',
                                filled: true,
                                iconColor: XC.onsecc,
                                label: n.allDay
                                    ? 'All day'
                                    : '${clockFull(n.start, h24: h24)} to ${clockFull(n.end, h24: h24)}',
                              ),
                              if (n.location != null)
                                XChip(icon: 'pin', filled: true, iconColor: XC.onsecc, label: n.location!),
                            ],
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(width: _gap),
            Expanded(
              flex: 115,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _card(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Later today', style: xttl()),
                          const SizedBox(height: 4),
                          if (others.isEmpty) Text('Nothing else today', style: _onv),
                          Expanded(
                            child: ListView(
                              padding: EdgeInsets.zero,
                              children: [
                                for (final (i, e) in others.indexed)
                                  _li(
                                    _lead(Text(e.allDay ? 'All' : hm(e.start))),
                                    e.title,
                                    [
                                      if (e.location != null) e.location!,
                                      if (!e.allDay) 'until ${clockFull(e.end, h24: h24)}',
                                    ].join(', '),
                                    trail: e.calendar == null ? null : XChip(label: e.calendar!),
                                    first: i == 0,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: _gap),
                  _card(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('This week', style: xttl()),
                        const SizedBox(height: 8),
                        if (split.later.isEmpty) Text('No other events in the next 7 days', style: _onv),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final e in split.later.take(4))
                              XChip(
                                icon: 'calendar',
                                label:
                                    '${weekday3(e.start)} ${e.allDay ? 'all day' : clockFull(e.start, h24: h24)}, ${e.title}',
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ------------------------------------------------------------------ Weather

class _Weather extends ConsumerWidget {
  const _Weather();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(weatherProvider);
    final s = ref.watch(settingsProvider);
    if (w == null) return _card(Center(child: Text('Set your location in Settings → Weather', style: _onv)));
    final f = s.fahrenheit;
    final lo = w.days.isEmpty ? 0 : w.days.map((d) => temp(d.loC, f)).reduce(math.min);
    final hi = w.days.isEmpty ? 1 : w.days.map((d) => temp(d.hiC, f)).reduce(math.max);
    String hr(DateTime t, int i) =>
        i == 0 ? 'Now' : (s.clock24 ? '${two(t.hour)}:00' : '${t.hour % 12 == 0 ? 12 : t.hour % 12} ${ampm(t)}');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 100,
          child: _card(
            tone: _Tone.t,
            Row(
              children: [
                XShapeBox(
                  shape: XShape.sunny,
                  color: XC.ter,
                  size: 168,
                  child: Text('${temp(w.now.tempC, f)}°', style: xdisp(64, c: XC.white)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ell(w.now.condition, xt(24, w: 600, h: 1.2)),
                      const SizedBox(height: 4),
                      Text('Feels like ${temp(w.now.feelsC, f)}°', style: _body(c: XC.onv)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          XChip(icon: 'drop', label: '${w.now.humidity}%'),
                          XChip(icon: 'wind', label: wind(w.now.windKmh, f)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Updated ${clockFull(w.now.updated, h24: s.clock24)}', style: _labOn(_Tone.t)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: _gap),
        Expanded(
          flex: 125,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Next 12 hours', style: xttl()),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 76,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.zero,
                        children: [
                          for (final (i, h) in w.hours.indexed)
                            Container(
                              width: 54,
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: i == 0 ? XC.ter : XC.sch,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Column(
                                children: [
                                  Text(hr(h.time, i), style: xt(11, c: i == 0 ? XC.white : XC.on, h: 1.3)),
                                  const Spacer(),
                                  DpIcon(h.icon, size: 18, color: i == 0 ? XC.white : XC.on),
                                  const Spacer(),
                                  Text(
                                    '${temp(h.tempC, f)}°',
                                    style: xt(13, w: 700, c: i == 0 ? XC.white : XC.on, h: 1.3),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: _gap),
              Expanded(
                child: _card(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('This week', style: xttl()),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            for (final (i, d) in w.days.indexed)
                              Row(
                                children: [
                                  SizedBox(width: 52, child: Text(i == 0 ? 'Today' : weekday3(d.date), style: _body())),
                                  const SizedBox(width: 10),
                                  DpIcon(d.icon, size: 17, color: XC.on),
                                  const SizedBox(width: 10),
                                  SizedBox(
                                    width: 40,
                                    child: Text(d.precipPct > 0 ? '${d.precipPct}%' : '', style: xlab(c: XC.ter)),
                                  ),
                                  const SizedBox(width: 10),
                                  SizedBox(
                                    width: 28,
                                    child: Text(
                                      '${temp(d.loC, f)}°',
                                      textAlign: TextAlign.right,
                                      style: _body(c: XC.onv),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(child: _range(temp(d.loC, f), temp(d.hiC, f), lo, hi)),
                                  const SizedBox(width: 10),
                                  SizedBox(width: 28, child: Text('${temp(d.hiC, f)}°', style: _body(w: 700))),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _range(int l, int h, int lo, int hi) => LayoutBuilder(
    builder: (context, c) {
      final span = math.max(1, hi - lo);
      final a = (l - lo) / span * c.maxWidth, b = (h - lo) / span * c.maxWidth;
      return Container(
        height: 8,
        decoration: BoxDecoration(color: XC.sch, borderRadius: BorderRadius.circular(9)),
        child: Stack(
          children: [
            Positioned(
              left: a,
              width: math.max(8, b - a),
              top: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  gradient: const LinearGradient(colors: [XC.ter, XC.pri]),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

// ------------------------------------------------------------------ Music

class _Music extends ConsumerWidget {
  const _Music();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = topicData<MediaData>(ref, 'media')!;
    final art = topicData<MediaArt>(ref, 'media.art');
    final skew = ref.read(agentProvider.notifier).clockSkewMs;
    final title = m.title;
    return Row(
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final side = math.min(c.maxHeight, 330.0);
            return SizedBox(
              width: side,
              height: side,
              child: XShapeClip(
                shape: XShape.cookie9,
                child: AlbumArt(title: title ?? 'Nothing playing', b64: art?.artId == m.artId ? art?.b64 : null),
              ),
            );
          },
        ),
        const SizedBox(width: 28),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ell([m.source ?? 'Laptop', if (m.album != null) m.album!].join(', '), xlab()),
              const SizedBox(height: 8),
              Text(
                title ?? 'Nothing playing',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: xt(38, w: 650, opsz: 48, ls: -.38, h: 1.05),
              ),
              const SizedBox(height: 6),
              _ell(m.artist ?? '', xt(17, c: XC.onv, h: 1.3)),
              const SizedBox(height: 26),
              Ticker(
                period: const Duration(seconds: 1),
                builder: (context, now) {
                  final pos = m.positionNow(now, skewMs: skew);
                  final total = m.durationMs ?? 0;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SeekWave(
                        value: total == 0 ? 0 : pos / total,
                        moving: m.playing,
                        enabled: m.canSeek && total > 0,
                        onSeek: (f) => act(context, ref, 'media.seek', {'position_ms': (f * total).round()}),
                      ),
                      Row(
                        children: [
                          Text(mmss(pos), style: xlab()),
                          const Spacer(),
                          Text(total == 0 ? '' : '-${mmss(math.max(0, total - pos))}', style: xlab()),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _ib('prev', () => act(context, ref, 'media.prev'), w: 56),
                  const SizedBox(width: 6),
                  _ib(
                    m.playing ? 'pause' : 'play',
                    () => act(context, ref, 'media.play_pause'),
                    w: 76,
                    h: 64,
                    pri: true,
                    radius: m.playing ? 20 : 99,
                    iconSize: 26,
                  ),
                  const SizedBox(width: 6),
                  _ib('next', () => act(context, ref, 'media.next'), w: 56),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SeekWave extends StatefulWidget {
  const _SeekWave({required this.value, required this.moving, required this.onSeek, required this.enabled});
  final double value;
  final bool moving, enabled;
  final ValueChanged<double> onSeek;
  @override
  State<_SeekWave> createState() => _SeekWaveState();
}

class _SeekWaveState extends State<_SeekWave> {
  double? _drag;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      double f(Offset p) => (p.dx / c.maxWidth).clamp(0.0, 1.0);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: widget.enabled ? (d) => widget.onSeek(f(d.localPosition)) : null,
        onHorizontalDragStart: widget.enabled ? (d) => setState(() => _drag = f(d.localPosition)) : null,
        onHorizontalDragUpdate: widget.enabled ? (d) => setState(() => _drag = f(d.localPosition)) : null,
        onHorizontalDragEnd: widget.enabled
            ? (_) {
                widget.onSeek(_drag!);
                setState(() => _drag = null);
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: _Wave(_drag ?? widget.value, moving: widget.moving && _drag == null, height: 16),
        ),
      );
    },
  );
}

// ------------------------------------------------------------------ Hotspot

/// The Hotspot Monitor Overview (the roof phone sharing mobile data).
class _Hotspot extends ConsumerWidget {
  const _Hotspot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = topicData<HotspotData>(ref, 'hotspot')!;
    final f = ref.watch(settingsProvider).fahrenheit;
    const t = ExpressiveSkin.t;
    return Ticker(
      builder: (context, now) {
        final grade = hsGradeColor(d.grade, t);
        final (down, downU) = hsBpsParts(d.rxBps);
        final (up, upU) = hsBpsParts(d.txBps);
        final (used, usedU) = hsBytesParts(d.cycleUsed);
        final q = d.quotaFrac;
        final heatC = switch (d.heat) {
          HotspotHeat.hot => XC.err,
          HotspotHeat.warm => t.warn,
          _ => XC.on,
        };
        final temp = hsTemp(d.batteryC, fahrenheit: f);
        final sp = temp.lastIndexOf(' ');
        final row1 = [
          _tile(
            'Signal score',
            trail: Text(hsGradeLabel(d.grade), style: xt(13, w: 650, c: grade)),
            _disp(d.score == null ? '—' : '${d.score!.round()}', '/100', 32),
            bar: _Wave((d.score ?? 0) / 100, color: grade, moving: false, height: 10),
            hsSignalLine(d),
          ),
          _tile(
            'Speed now',
            tone: _Tone.s,
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const DpIcon('down', size: 16, color: XC.onsecc),
                _disp(down, downU, 32),
                const SizedBox(width: 10),
                const DpIcon('up', size: 16, color: XC.onsecc),
                _disp(up, upU, 32),
              ],
            ),
            hsPingLine(d),
          ),
          _tile(
            'Battery',
            trail: Text(hsCurrent(d.currentMa), style: xt(13, w: 650, c: XC.onv)),
            _disp(d.batteryPct == null ? '—' : '${d.batteryPct!.round()}', '%', 32, c: d.lowBattery ? XC.err : null),
            hsPowerLine(d),
          ),
        ];
        final row2 = [
          _tile(
            'Temperature',
            trail: d.radioResting ? Text('Radio resting', style: xt(13, w: 650, c: XC.err)) : null,
            _disp(sp < 0 ? temp : temp.substring(0, sp), sp < 0 ? '' : temp.substring(sp + 1), 32, c: heatC),
            hsHeatLine(d, fahrenheit: f),
          ),
          _tile(
            'Data this cycle',
            trail: Text(d.quota == null ? 'No quota' : 'of ${hsBytes(d.quota)}', style: xlab()),
            _disp(used, usedU, 32),
            bar: q == null
                ? null
                : _Wave(q, color: q >= 1 ? XC.err : (q >= .8 ? t.warn : XC.pri), moving: false, height: 10),
            hsTodayLine(d),
          ),
          _tile(
            'Uptime',
            Text(hsUptime(d.uptimeS), style: xdisp(32)),
            'Agent ${hsUptime(d.agentUptimeS)}\n${hsBootLine(d)}',
          ),
        ];
        Widget row(List<Widget> tiles) => Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, w) in tiles.indexed) ...[if (i > 0) const SizedBox(width: _gap), Expanded(child: w)],
          ],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _hsBand(d, now),
            const SizedBox(height: _gap),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 60,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: row(row1)),
                        const SizedBox(height: _gap),
                        Expanded(child: row(row2)),
                      ],
                    ),
                  ),
                  const SizedBox(width: _gap),
                  Expanded(flex: 25, child: _events(d, now)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// The status band: state, last seen, network and sharing; the alert in the error tone.
  Widget _hsBand(HotspotData d, DateTime now) {
    final alert = hsAlert(d, now);
    final bad = alert != null;
    final fg = bad ? XC.onerrc : XC.onpric;
    final sub = fg.withValues(alpha: .75);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
      decoration: BoxDecoration(color: bad ? XC.errc : XC.pric, borderRadius: BorderRadius.circular(26)),
      child: Row(
        children: [
          XShapeBox(
            shape: XShape.cookie12,
            color: hsStateColor(d, ExpressiveSkin.t),
            size: 56,
            child: DpIcon(d.online ? 'hotspot' : 'off', size: 26, color: XC.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(child: _ell(hsStateLabel(d), xt(26, w: 650, opsz: 36, h: 1.15, c: fg))),
                    const SizedBox(width: 12),
                    Text(hsSeen(d, now), style: _body(c: sub, size: 13.5)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  alert ?? [d.name ?? 'Phone', ?d.model].join(', '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: bad ? _body(c: fg, size: 13.5, w: 550) : _body(c: sub, size: 13.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          XChip(icon: 'wifi', label: hsNetwork(d), filled: true, iconColor: XC.onsecc),
          if (d.operator != null) ...[const SizedBox(width: 6), XChip(label: d.operator!, filled: true)],
          const SizedBox(width: 6),
          XChip(icon: 'users', label: hsSharing(d), filled: true, iconColor: XC.onsecc),
        ],
      ),
    );
  }

  /// A metric tile: label (+ trailing note), display value, optional wavy bar, detail line.
  Widget _tile(String title, Widget value, String small, {Widget? trail, Widget? bar, _Tone tone = _Tone.plain}) =>
      _card(
        tone: tone,
        pad: const EdgeInsets.fromLTRB(16, 12, 14, 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Expanded(child: _ell(title, _labOn(tone))),
                if (trail != null) ...[const SizedBox(width: 6), trail],
              ],
            ),
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: value),
            ?bar,
            Text(
              small,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: xt(12, c: tone == _Tone.s ? XC.onsecc.withValues(alpha: .75) : XC.onv, h: 1.3),
            ),
          ],
        ),
      );

  /// Newest events first, as many as fit.
  Widget _events(HotspotData d, DateTime now) => _card(
    pad: const EdgeInsets.fromLTRB(14, 12, 12, 8),
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _ell('Latest events', xttl())),
            if (d.events.isNotEmpty) Text('${d.events.length}', style: xlab()),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: d.events.isEmpty
              ? Center(child: Text('Nothing has happened yet', style: _onv))
              : LayoutBuilder(
                  builder: (context, box) {
                    TextStyle st(HotspotEvent e) => xt(13, w: e.severity == 'info' ? 400 : 600, h: 1.3);
                    // Whole events only: measure each message (up to 2 lines) and stop when full.
                    final shown = <HotspotEvent>[];
                    var used = 0.0;
                    for (final e in d.events) {
                      final tp = TextPainter(
                        text: TextSpan(text: e.message, style: st(e)),
                        maxLines: 2,
                        textDirection: TextDirection.ltr,
                      )..layout(maxWidth: box.maxWidth - 19 - 44);
                      final h = tp.height + 12;
                      tp.dispose();
                      if (used + h > box.maxHeight && shown.isNotEmpty) break;
                      used += h;
                      shown.add(e);
                    }
                    return Column(
                      children: [
                        for (final e in shown)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 5),
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: e.severity == 'info' ? XC.outv : hsEventColor(e, ExpressiveSkin.t),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    e.message,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: st(e),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 36,
                                  child: Text(
                                    slackTime(e.ts, now),
                                    textAlign: TextAlign.right,
                                    maxLines: 1,
                                    style: xt(12, c: XC.onv, h: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
        if (hsSessionNote(d, now) case final note?)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                DpIcon('clock', size: 15, color: ExpressiveSkin.t.warn),
                const SizedBox(width: 6),
                Expanded(child: _ell(note, xlab(c: ExpressiveSkin.t.warn))),
              ],
            ),
          ),
      ],
    ),
  );
}

// ------------------------------------------------------------------ Timer

class _Timer extends ConsumerWidget {
  const _Timer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(timerProvider);
    final ctl = ref.read(timerProvider.notifier);
    return Ticker(
      period: const Duration(seconds: 1),
      builder: (context, now) {
        final d = st.display(now);
        final digits = d.inHours > 0
            ? '${d.inHours}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}'
            : '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
        final label = st.running ? 'Pause' : (st.pristine ? 'Start' : 'Resume');
        return Row(
          children: [
            _Ring(
              st.progress(now),
              size: 300,
              sw: 4.5,
              moving: st.running,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(digits, style: xdisp(76)),
                  Text(st.mode.label, style: xlab()),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _Bgrp(
                      items: [for (final m in TimerMode.values) m.label],
                      value: st.mode.index,
                      onChanged: (i) => ctl.setMode(TimerMode.values[i]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _Btn(
                        label,
                        icon: st.running ? 'pause' : 'play',
                        onTap: ctl.toggle,
                        height: 56,
                        padH: 28,
                        size: 15,
                        radius: st.running ? 16 : 99,
                      ),
                      const SizedBox(width: 10),
                      _Btn('Reset', text: true, onTap: ctl.reset),
                      if (st.mode == TimerMode.countdown && !st.running) ...[
                        const SizedBox(width: 10),
                        _ib('down', () => ctl.adjust(-1), w: 40),
                        const SizedBox(width: 8),
                        Text('${st.countdownMin} min', style: xt(14, w: 600)),
                        const SizedBox(width: 8),
                        _ib('up', () => ctl.adjust(1), w: 40),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (st.mode.isPomodoro)
                    Row(
                      children: [
                        for (var i = 0; i < 4; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          XShapeBox(shape: XShape.cookie9, color: i < st.sessions ? XC.pri : XC.sch, size: 26),
                        ],
                        const SizedBox(width: 12),
                        Text('${st.sessions} of 4 focus sessions today', style: _onv),
                      ],
                    )
                  else
                    Text(
                      st.mode == TimerMode.stopwatch ? 'Counts up from zero' : 'Use − and + to set the minutes',
                      style: _onv,
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ------------------------------------------------------------------ Slack

/// Sender avatar: initials on a shape-library cookie in the sender's colour.
Widget _avatar(SlackMsg m, double size, {XShape shape = XShape.cookie9}) {
  final bg = hex(m.senderColor, XC.ter);
  return XShapeBox(
    shape: shape,
    color: bg,
    size: size,
    child: Text(
      m.initials,
      style: xt(size * .36, w: 700, opsz: 24, c: bg.computeLuminance() > .45 ? XC.on : XC.white, h: 1),
    ),
  );
}

class _Slack extends ConsumerWidget {
  const _Slack();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = topicData<SlackData>(ref, 'slack')!;
    final unread = s.unreadMessages;
    final top = unread.isEmpty ? null : unread.first;
    final rest = [
      for (final m in s.messages)
        if (m != top) m,
    ];
    return Ticker(
      builder: (context, now) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 100, child: _hero(context, ref, s, top, now)),
          const SizedBox(width: _gap),
          Expanded(
            flex: 116,
            child: _card(
              pad: const EdgeInsets.fromLTRB(12, 14, 12, 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                    child: Row(
                      children: [
                        Expanded(child: _ell(top == null ? 'Messages' : 'Also in your inbox', xttl())),
                        if (rest.isNotEmpty) Text('${rest.length}', style: xlab()),
                      ],
                    ),
                  ),
                  Expanded(
                    child: rest.isEmpty
                        ? _calm(
                            s.messages.isEmpty ? 'No messages yet' : 'Nothing else',
                            s.messages.isEmpty ? 'DMs and mentions land here' : 'That one is all that is new',
                          )
                        : ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: rest.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 4),
                            itemBuilder: (context, i) => _msg(context, ref, rest[i], now),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Newest unread message, big; or a calm "all caught up" when there is none.
  Widget _hero(BuildContext context, WidgetRef ref, SlackData s, SlackMsg? top, DateTime now) {
    if (top == null) {
      final last = s.messages.isEmpty ? null : s.messages.first;
      return _card(
        tone: _Tone.p,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.team ?? 'Slack', style: _labOn(_Tone.p)),
            const Spacer(),
            const XShapeBox(
              shape: XShape.cookie12,
              color: XC.pri,
              size: 96,
              child: DpIcon('slack', size: 40, color: XC.onpri),
            ),
            const SizedBox(height: 18),
            _ell('All caught up', xt(30, w: 650, opsz: 36, h: 1.15)),
            const SizedBox(height: 2),
            _ell(
              last == null
                  ? 'Nothing new. Enjoy the quiet.'
                  : 'Last message from ${last.sender}, ${slackTime(last.ts, now)}',
              _body(c: XC.onpric.withValues(alpha: .75), size: 13.5),
            ),
            const Spacer(),
          ],
        ),
      );
    }
    return _card(
      tone: _Tone.p,
      pad: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _disp('${s.unread}', '', 72),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ell(s.unread == 1 ? 'unread message' : 'unread messages', xttl()),
                    _ell(s.team == null ? 'Slack' : 'in ${s.team}', _body(c: XC.onpric.withValues(alpha: .75))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Press(
              onTap: () => slackOpen(context, ref, top),
              scale: .985,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                decoration: BoxDecoration(color: XC.surface, borderRadius: BorderRadius.circular(22)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _avatar(top, 48, shape: XShape.cookie12),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _ell(top.sender, xt(18, w: 650, opsz: 24, h: 1.25, c: XC.on)),
                              _ell(
                                slackTime(top.ts, now) == 'now' ? 'Just now' : '${slackTime(top.ts, now)} ago',
                                xt(12.5, c: XC.onv, h: 1.3),
                              ),
                            ],
                          ),
                        ),
                        SlackReadTick(top, color: XC.pri, fill: XC.pri, onFill: XC.onpri, size: 32, hit: 46),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          top.text,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: xt(17, c: XC.on, h: 1.35),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Flexible(
                          child: XChip(
                            filled: true,
                            icon: top.kind == SlackKind.group ? 'users' : 'slack',
                            iconColor: XC.onsecc,
                            label: switch (top.kind) {
                              SlackKind.dm => 'Direct message',
                              SlackKind.group => top.where,
                              SlackKind.mention => 'Mention in ${top.where}',
                            },
                          ),
                        ),
                        if (top.thread) ...[const SizedBox(width: 6), const XChip(label: 'In a thread')],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Btn('Open', icon: 'slack', onTap: () => slackOpen(context, ref, top)),
              const SizedBox(width: 8),
              Flexible(child: _Btn('Mark all read', tonal: true, onTap: () => slackReadAll(context, ref))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _msg(BuildContext context, WidgetRef ref, SlackMsg m, DateTime now) => Press(
    onTap: () => slackOpen(context, ref, m),
    scale: .985,
    child: Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      decoration: BoxDecoration(color: m.unread ? XC.surface : _clear, borderRadius: BorderRadius.circular(20)),
      child: Opacity(
        opacity: m.unread ? 1 : .6,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _avatar(m, 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: m.sender,
                                style: xt(14.5, w: m.unread ? 700 : 550, h: 1.3),
                              ),
                              TextSpan(
                                text: '   ${slackWhere(m)}',
                                style: xt(12, c: XC.onv, h: 1.3),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        slackTime(m.ts, now),
                        style: xt(12, w: m.unread ? 650 : 450, c: m.unread ? XC.pri : XC.onv, h: 1.3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    m.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: xt(13, c: m.unread ? XC.on : XC.onv, h: 1.35),
                  ),
                ],
              ),
            ),
            Transform.translate(
              offset: const Offset(6, 0),
              child: SlackReadTick(m, color: XC.pri, fill: XC.pri, onFill: XC.onpri, size: 28, hit: 42),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _calm(String title, String sub) => Center(
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const XShapeBox(
            shape: XShape.flower,
            color: XC.secc,
            size: 64,
            child: DpIcon('slack', size: 26, color: XC.onsecc),
          ),
          const SizedBox(height: 12),
          Text(title, style: xttl()),
          const SizedBox(height: 2),
          Text(sub, style: _onv, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

// ------------------------------------------------------------------ GitHub

class _Github extends ConsumerWidget {
  const _Github();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = topicData<GithubData>(ref, codeTopic(ref))!;
    final now = DateTime.now();
    final today = now.weekday % 7;
    final mx = maxOf([...g.thisWeek, ...g.lastWeek]);
    final best = g.bestDay;
    const repoColors = [XC.pri, Color(0xFF3BA99B), Color(0xFF7DCFC2), Color(0xFFB8E6DE), Color(0xFFDCEFEA)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: _Bgrp(
            items: codeSources,
            value: ref.watch(codeSourceProvider),
            onChanged: ref.read(codeSourceProvider.notifier).set,
          ),
        ),
        const SizedBox(height: _gap),
        _card(
          pad: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('Contributions', style: xttl()),
                  const Spacer(),
                  XChip(label: '${_thousands(g.total)} total'),
                  const SizedBox(width: 6),
                  XChip(label: '${g.commits} commits'),
                  const SizedBox(width: 6),
                  XChip(label: '${g.private} private'),
                ],
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, c) {
                  // Capped a little smaller than the 15.2 px design size to leave room for the source switch.
                  final cw = math.min(c.maxWidth / 53, 12.0);
                  return Center(
                    child: SizedBox(
                      width: 53 * cw,
                      height: 13 + 7 * cw,
                      child: CustomPaint(painter: _Heat(g.weeks, now)),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: _gap),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 90,
                child: _card(
                  tone: _Tone.p,
                  Row(
                    children: [
                      LayoutBuilder(
                        builder: (context, c) => XShapeBox(
                          shape: XShape.cookie9,
                          color: XC.pri,
                          size: math.min(110, c.maxHeight),
                          child: Text('${g.streakCurrent}', style: xdisp(54, c: XC.white)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Day streak', style: xttl()),
                            Text(
                              'Longest ${g.streakLongest}\nBest day ${best == null ? '—' : '${best.count}, ${month3(best.date)} ${best.date.day}'}',
                              style: _body(c: XC.onv),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: _gap),
              Expanded(
                flex: 110,
                child: _card(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text('This week', style: xttl()),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(color: XC.pri, borderRadius: BorderRadius.circular(99)),
                            child: Text(
                              '${g.weekDelta >= 0 ? '+' : ''}${g.weekDelta}',
                              style: xt(12, w: 650, c: XC.onpri),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < 7; i++) ...[
                              if (i > 0) const SizedBox(width: 6),
                              Expanded(
                                child: _pillBar(
                                  ((i < g.thisWeek.length ? g.thisWeek[i] : null) ?? 0) / mx,
                                  'SMTWTFS'[i],
                                  i == today,
                                  22,
                                  8,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: _gap),
              Expanded(
                flex: 100,
                child: _card(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(topReposLabel(ref), style: xttl()),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            for (final (i, r) in g.topRepos.take(4).indexed)
                              Padding(
                                padding: EdgeInsets.zero,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: repoColors[i],
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(child: _ell(r.name, _body())),
                                    Text('${r.count}', style: _body(w: 700)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _thousands(int n) => n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

class _Heat extends CustomPainter {
  _Heat(this.all, this.now);
  final List<List<ContribDay>> all;
  final DateTime now;

  @override
  void paint(Canvas c, Size s) {
    final weeks = all.length > 53 ? all.sublist(all.length - 53) : all;
    const top = 13.0;
    final cw = s.width / 53, cs = cw - 2.5;
    const lv = [XC.sch, Color(0xFFB8E6DE), Color(0xFF7DCFC2), Color(0xFF3BA99B), XC.pri];
    for (var x = 1; x < weeks.length - 1; x++) {
      if (weeks[x].isEmpty || weeks[x - 1].isEmpty) continue;
      if (weeks[x].first.date.month != weeks[x - 1].first.date.month) {
        final tp = TextPainter(
          text: TextSpan(
            text: month3(weeks[x].first.date),
            style: xt(9.5, c: XC.onv),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(c, Offset(x * cw, 9 - tp.computeDistanceToActualBaseline(TextBaseline.alphabetic)));
      }
    }
    for (var x = 0; x < weeks.length; x++) {
      for (final day in weeks[x]) {
        final y = day.date.weekday % 7;
        final isToday = day.date.year == now.year && day.date.month == now.month && day.date.day == now.day;
        final r = RRect.fromRectAndRadius(Rect.fromLTWH(x * cw, top + y * cw, cs, cs), Radius.circular(cs / 2.4));
        c.drawRRect(r, Paint()..color = isToday ? XC.ter : lv[day.level.clamp(0, 4)]);
      }
    }
  }

  @override
  bool shouldRepaint(_Heat o) => o.all != all;
}

// ------------------------------------------------------------------ Shortcuts

class _Shortcuts extends ConsumerWidget {
  const _Shortcuts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = topicData<ShortcutsData>(ref, 'shortcuts')!;
    final order = ref.watch(settingsProvider.select((x) => x.tileOrder));
    final tiles = orderedTiles(s.tiles, order);
    final rows = <List<Tile>>[];
    for (var i = 0; i < tiles.length; i += 4) {
      rows.add(tiles.sublist(i, math.min(i + 4, tiles.length)));
    }
    return Column(
      children: [
        for (final (ri, row) in rows.indexed) ...[
          if (ri > 0) const SizedBox(height: _gap),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(width: _gap),
                  Expanded(child: i < row.length ? _Key(row[i], s.volumePct) : const SizedBox()),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Key extends ConsumerStatefulWidget {
  const _Key(this.t, this.vol);
  final Tile t;
  final int? vol;
  @override
  ConsumerState<_Key> createState() => _KeyState();
}

class _KeyState extends ConsumerState<_Key> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final on = t.active;
    final alt = t.id.startsWith('volume') || t.id == 'lock';
    final (bg, fg) = on ? (XC.err, XC.white) : (alt ? (XC.terc, XC.onterc) : (XC.secc, XC.onsecc));
    final sub = t.id.startsWith('volume') && widget.vol != null ? 'Volume ${widget.vol}%' : t.detail;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: () => act(context, ref, 'shortcut.run', {'id': t.id}),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: const Cubic(.2, 0, 0, 1),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(on || _down ? 14 : 32)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            DpIcon(tileIcon(t), size: 30, color: fg),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ell(tileLabel(t), xt(14.5, w: 600, c: fg, h: 1.3)),
                if (sub != null) _ell(sub, xt(12, w: 500, c: fg.withValues(alpha: .75), h: 1.3)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
