import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/conn/controller.dart';
import '../../core/pages.dart';
import '../../core/settings.dart';
import '../fmt.dart';
import '../pages/kit.dart';
import '../widgets/art.dart';
import '../skin.dart';
import 'glow_pages.dart';
import '../widgets/common.dart';

/// Concept 2 — Glow: one giant serif number per page, a soft hue that carries meaning,
/// no boxes. Text navigation along the bottom.
class GlowSkin extends Skin {
  const GlowSkin();

  static const base = Color(0xFF0A0D1C);
  static const tx = Color(0xFFF4EFE6);

  static const t = SkinTokens(
    bg: base,
    surface: Color(0x14F4EFE6),
    surface2: Color(0x22F4EFE6),
    line: Color(0x1CF4EFE6), // --rule .11
    text: tx,
    muted: Color(0x99F4EFE6), // .6
    faint: Color(0x57F4EFE6), // .34
    accent: tx,
    onAccent: base,
    ok: Color(0xFF7CE3A8),
    warn: Color(0xFFF5C36B),
    bad: Color(0xFFFF8A8A),
    claude: Color(0xFFF26C3D),
    green: Color(0xFF5CF08A),
    cpu: Color(0xFF6FB6FF),
    gpu: Color(0xFF1EE3D0),
    ram: Color(0xFFB79BFF),
    vram: Color(0xFFFF7CC2),
    sky: Color(0xFF7FC4FF),
    cloud: Color(0xFFD9D4F2),
    body: 'Manrope',
    display: 'Fraunces',
    radius: 18,
  );

  /// Per-page glow: hue, centre (fractions), alpha. From the concept's CSS.
  static ({double h, double x, double y, double a}) glowFor(PageId p, bool offline) {
    if (offline) return (h: 0, x: .22, y: .40, a: .16);
    return switch (p) {
      PageId.system => (h: 178, x: .30, y: .70, a: .34),
      PageId.claude => (h: 16, x: .18, y: .45, a: .34),
      PageId.calendar => (h: 272, x: .22, y: .40, a: .34),
      PageId.weather => (h: 208, x: .20, y: .32, a: .34),
      PageId.hotspot => (h: 36, x: .20, y: .50, a: .34),
      PageId.timer => (h: 345, x: .50, y: .50, a: .30),
      PageId.github => (h: 138, x: .15, y: .30, a: .28),
      PageId.shortcuts => (h: 225, x: .50, y: .60, a: .18),
      PageId.slack => (h: 300, x: .22, y: .45, a: .30),
      _ => (h: 250, x: .22, y: .40, a: .34),
    };
  }

  static Color hue(double h, [double s = .9, double l = .72]) =>
      HSLColor.fromAHSL(1, h % 360, s, l).toColor();

  @override
  SkinId get id => SkinId.glow;
  @override
  SkinTokens get tokens => t;

  @override
  Widget page(PageId id) => glowPage(id);

  @override
  Widget card({required Widget child, EdgeInsets? padding, VoidCallback? onTap, String? label}) {
    Widget c = Padding(
      padding: padding ?? EdgeInsets.zero,
      child: label == null
          ? child
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: t.t(12.5, w: FontWeight.w600, c: t.muted)),
              const SizedBox(height: 8),
              Expanded(child: child),
            ]),
    );
    if (onTap != null) c = Press(onTap: onTap, scale: .99, child: c);
    return c;
  }

  @override
  Widget shell(ShellArgs a) => _GlowShell(skin: this, a: a);

  Widget _navItem(PageId p, bool active, VoidCallback onTap, double h) => Press(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedOpacity(
              opacity: active ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: _LitDot(color: hue(h), size: 4, halo: 9, strength: .55),
            ),
            const SizedBox(height: 5),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: t.t(12.5, w: FontWeight.w600, c: active ? t.text : t.faint),
              child: Text(p.label),
            ),
          ]),
        ),
      );

  Widget _status(ShellArgs a) {
    final s = connSummary(a.conn);
    final dot = s.ok ? t.ok : t.bad;
    final showClock = a.current != PageId.home && a.current != PageId.timer;
    return Press(
      onTap: a.onStatusTap,
      child: Ticker(
        builder: (context, now) => Row(mainAxisSize: MainAxisSize.min, children: [
          if (showClock) ...[
            Text(clock(now, h24: a.settings.clock24), style: t.t(12, w: FontWeight.w600)),
            const SizedBox(width: 10),
          ],
          _LitDot(color: dot, size: 7, halo: 8, strength: .4),
          const SizedBox(width: 8),
          Text(a.conn.status == LinkStatus.demo ? 'Demo laptop' : s.text,
              style: t.t(12, w: FontWeight.w600, c: t.muted)),
        ]),
      ),
    );
  }
}

/// Glow shell: ambient glow behind the page whose hue carries meaning. Music takes the
/// hue of the current track (same hue as its generated art), Slack the hue of the newest
/// unread sender (calm and dim when caught up); Claude glows
/// brighter as the 5-hour limit fills (concept `refresh()`).
class _GlowShell extends ConsumerWidget {
  const _GlowShell({required this.skin, required this.a});
  final GlowSkin skin;
  final ShellArgs a;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = !a.conn.live;
    var g = GlowSkin.glowFor(a.current, offline);
    var beat = false;
    if (!offline) {
      switch (a.current) {
        case PageId.music:
          final m = topicData<MediaData>(ref, 'media');
          final title = m?.title;
          if (title != null) g = (h: hueFor(title), x: g.x, y: g.y, a: g.a);
          // Music playing: the glow comes alive (a slow heartbeat, drifting on an orbit).
          beat = m?.playing ?? false;
        case PageId.slack:
          // Takes the hue of the newest unread sender; settles to a calm, dim teal when caught up.
          final sl = topicData<SlackData>(ref, 'slack');
          final first = sl == null || sl.unreadMessages.isEmpty ? null : sl.unreadMessages.first;
          g = first == null
              ? (h: 175, x: g.x, y: g.y, a: .16)
              : (h: HSLColor.fromColor(hex(first.senderColor)).hue, x: g.x, y: g.y, a: g.a);
        case PageId.claude:
          final c = topicData<ClaudeData>(ref, 'claude');
          final pct = limitPct(c?.fiveHour, DateTime.now());
          g = (h: g.h, x: g.x, y: g.y, a: .18 + pct / 100 * .45);
        default:
      }
    }
    return TweenAnimationBuilder<_Glow>(
      tween: _GlowTween(end: _Glow(g.h, g.x, g.y, g.a)),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.ease,
      builder: (context, v, child) => Stack(fit: StackFit.expand, children: [
        const ColoredBox(color: GlowSkin.base),
        _LiveGlow(glow: v, beat: beat),
        GlowHue(hue: v.h, child: child!),
      ]),
      child: Column(children: [
        Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(30, 22, 30, 4), child: a.child)),
        Padding(
          padding: const EdgeInsets.fromLTRB(30, 8, 26, 12),
          child: Row(children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final p in a.pages) skin._navItem(p, p == a.current, () => a.onSelect(p), g.h),
                ]),
              ),
            ),
            const SizedBox(width: 16),
            skin._status(a),
          ]),
        ),
      ]),
    );
  }
}

/// The page's current (animated) glow hue; pages use it as their accent (`--hue`).
class GlowHue extends InheritedWidget {
  const GlowHue({super.key, required this.hue, required super.child});
  final double hue;

  /// `hsl(h 90% 72%)` — the concept's `--hue`.
  static Color of(BuildContext c) => GlowSkin.hue(c.dependOnInheritedWidgetOfExactType<GlowHue>()?.hue ?? 250);
  static double raw(BuildContext c) => c.dependOnInheritedWidgetOfExactType<GlowHue>()?.hue ?? 250;

  @override
  bool updateShouldNotify(GlowHue old) => old.hue != hue;
}

class _Glow {
  const _Glow(this.h, this.x, this.y, this.a);
  final double h, x, y, a;
}

class _GlowTween extends Tween<_Glow> {
  _GlowTween({required _Glow end}) : super(begin: end, end: end);
  @override
  _Glow lerp(double t) {
    final b = begin!, e = end!;
    // Shortest way round the colour wheel.
    var dh = e.h - b.h;
    if (dh > 180) dh -= 360;
    if (dh < -180) dh += 360;
    double l(double x, double y) => x + (y - x) * t;
    return _Glow(b.h + dh * t, l(b.x, e.x), l(b.y, e.y), l(b.a, e.a));
  }
}

/// The page glow. Still on every page; on the Music page while music plays it comes alive:
/// it beats like a slow heart (lub-dub, every ~1.8 s) and its centre drifts on a slow
/// orbit, easing in on play and settling back to the still glow on pause. Frames run only
/// while it moves, and it repaints in its own layer.
class _LiveGlow extends StatefulWidget {
  const _LiveGlow({required this.glow, required this.beat});
  final _Glow glow;
  final bool beat;

  @override
  State<_LiveGlow> createState() => _LiveGlowState();
}

class _LiveGlowState extends State<_LiveGlow> with SingleTickerProviderStateMixin {
  late final _ticker = createTicker(_tick);
  final _frame = ValueNotifier<int>(0);
  Duration _last = Duration.zero;
  double _e = 0; // 0 = still glow, 1 = fully alive (eased in/out)
  double _beat = 0, _orbit = 0; // heartbeat and orbit phases, in cycles

  static const period = 1.8; // seconds per heartbeat
  static const orbitPeriod = 26.0; // seconds per lap of the drift

  @override
  void initState() {
    super.initState();
    if (widget.beat) _run();
  }

  @override
  void didUpdateWidget(_LiveGlow old) {
    super.didUpdateWidget(old);
    if (widget.beat != old.beat) _run();
  }

  void _run() {
    if (_ticker.isActive) return;
    _last = Duration.zero;
    _ticker.start();
  }

  void _tick(Duration elapsed) {
    final dt = math.min(.1, (elapsed - _last).inMicroseconds / 1e6);
    _last = elapsed;
    _e = (_e + (widget.beat ? dt : -dt) / 1.2).clamp(0.0, 1.0);
    _beat += dt / period;
    _orbit += dt / orbitPeriod * Curves.easeInOut.transform(_e);
    _frame.value++;
    if (!widget.beat && _e == 0) _ticker.stop();
  }

  /// One heartbeat, 0..~1: a quick thump that fades, a softer second one just after it.
  double get pulse => _pulseAt(_beat);

  /// The same beat a moment later (the far glow answers the near one).
  double get pulseLate => _pulseAt(_beat - .07);

  static double _pulseAt(double phase) {
    final x = phase % 1;
    double thump(double t) => t < 0 ? 0 : (t < .06 ? math.sin(t / .06 * math.pi / 2) : math.exp(-(t - .06) / .13));
    return thump(x) + .55 * thump(x - .19);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(painter: _GlowPainter(widget.glow, this, _frame), child: const SizedBox.expand()),
      );
}

class _GlowPainter extends CustomPainter {
  _GlowPainter(this.g, this.live, Listenable frame) : super(repaint: frame);
  final _Glow g;
  final _LiveGlowState live;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final e = Curves.easeInOut.transform(live._e);
    // While it moves it's repainted every frame: no blur then (the gradient is soft anyway).
    final soft = e == 0;
    void blob(Offset c, double rx, double ry, Color col) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.scale(1, ry / rx);
      final paint = Paint()
        ..shader = RadialGradient(colors: [col, col.withValues(alpha: 0)], stops: const [0, .72])
            .createShader(Rect.fromCircle(center: Offset.zero, radius: rx));
      if (soft) paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset.zero, rx, paint);
      canvas.restore();
    }

    final beat = e * live.pulse;
    final o = live._orbit * 2 * math.pi;
    // The centre drifts round a slow ellipse that starts at the still glow's centre and
    // swings out behind the title; each beat brightens and swells the glow.
    final x = g.x + e * .17 * (1 - math.cos(o)), y = g.y - e * .13 * math.sin(o);
    final a = (g.a * (1 - e * .12 + .7 * beat)).clamp(0.0, 1.0);
    final grow = 1 + .1 * beat;
    // radial-gradient(42% 60% at gx gy, hsl(h 85% 55% / ga), transparent 72%)
    blob(Offset(w * x, h * y), w * .42 * 1.4 * grow, h * .60 * 1.4 * grow,
        HSLColor.fromAHSL(a, g.h % 360, .85, .55).toColor());
    // radial-gradient(60% 50% at 85% 110%, hsl(h+40 70% 45% / ga*.45), transparent 70%)
    // (drifts the other way, and answers each beat a little later and softer)
    final x2 = .85 - e * .08 * (1 - math.cos(o)), y2 = 1.1 + e * .05 * math.sin(o);
    final a2 = (g.a * .45 * (1 + .6 * e * live.pulseLate)).clamp(0.0, 1.0);
    blob(Offset(w * x2, h * y2), w * .60 * 1.4, h * .50 * 1.4,
        HSLColor.fromAHSL(a2, (g.h + 40) % 360, .70, .45).toColor());
  }

  @override
  bool shouldRepaint(_GlowPainter old) =>
      old.g.h != g.h || old.g.a != g.a || old.g.x != g.x || old.g.y != g.y || old.live != live;
}

/// A lit dot with a soft halo, drawn with a radial gradient: no blur, because the glow
/// behind it may be repainted every frame (and blurs would be redone each time).
class _LitDot extends StatelessWidget {
  const _LitDot({required this.color, required this.size, required this.halo, required this.strength});
  final Color color;
  final double size, halo, strength;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _LitDotPainter(color, halo, strength));
}

class _LitDotPainter extends CustomPainter {
  _LitDotPainter(this.color, this.halo, this.strength);
  final Color color;
  final double halo, strength;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero), r = size.shortestSide / 2, out = r + halo;
    canvas.drawCircle(
      c,
      out,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: strength),
            color.withValues(alpha: strength * .55),
            color.withValues(alpha: strength * .16),
            color.withValues(alpha: 0),
          ],
          stops: [0, r / out, (r + halo * .5) / out, 1],
        ).createShader(Rect.fromCircle(center: c, radius: out)),
    );
    canvas.drawCircle(c, r, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_LitDotPainter old) => old.color != color || old.halo != halo || old.strength != strength;
}
