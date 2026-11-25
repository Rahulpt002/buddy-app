import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/pages.dart';
import '../../core/settings.dart';
import '../fmt.dart';
import '../icons.dart';
import '../pages/kit.dart';
import '../skin.dart';
import '../widgets/common.dart';
import 'expressive_pages.dart';

/// Material 3 Expressive tonal palette (seed #006A62), light scheme.
class XC {
  static const surface = Color(0xFFF4FBF8);
  static const sc = Color(0xFFE8EFEC); // surface container
  static const sch = Color(0xFFE2E9E6); // surface container high
  static const schh = Color(0xFFDCE4E1);
  static const pri = Color(0xFF006A62);
  static const onpri = Color(0xFFFFFFFF);
  static const pric = Color(0xFF9EF2E6);
  static const onpric = Color(0xFF00201D);
  static const sec = Color(0xFF4A635F);
  static const secc = Color(0xFFCCE8E2);
  static const onsecc = Color(0xFF051F1C);
  static const ter = Color(0xFF3D5F90);
  static const terc = Color(0xFFD5E3FF);
  static const onterc = Color(0xFF001B3C);
  static const err = Color(0xFFBA1A1A);
  static const errc = Color(0xFFFFDAD6);
  static const onerrc = Color(0xFF410002);
  static const on = Color(0xFF171D1C);
  static const onv = Color(0xFF3F4947);
  static const outl = Color(0xFF6F7977);
  static const outv = Color(0xFFBEC9C6);
  static const white = Color(0xFFFFFFFF);
}

const _font = 'Roboto Flex';

FontWeight _fw(double w) => FontWeight.values[((w / 100).round() - 1).clamp(0, 8)];

/// Roboto Flex with explicit axes (wght, opsz, wdth).
TextStyle xt(double size, {double w = 400, Color? c, double? h, double? ls, double opsz = 14, double wdth = 100}) =>
    TextStyle(
      fontFamily: _font,
      fontSize: size,
      fontWeight: _fw(w),
      fontVariations: [FontVariation('wght', w), FontVariation('opsz', opsz), FontVariation('wdth', wdth)],
      color: c,
      height: h,
      letterSpacing: ls,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// `.disp`: condensed heavy display numbers.
TextStyle xdisp(double size, {Color? c}) => xt(size, w: 650, opsz: 144, wdth: 45, ls: -.01 * size, h: .9, c: c);

/// `.disp small`.
TextStyle xdispSmall(double size, {Color? c}) => xt(size * .38, w: 600, opsz: 48, wdth: 80, h: .9, c: c);

/// `.lab`
TextStyle xlab({Color? c}) => xt(12, w: 550, c: c ?? XC.onv, ls: .12);

/// `.ttl`
TextStyle xttl({Color? c}) => xt(16, w: 600, opsz: 24, c: c);

class ExpressiveSkin extends Skin {
  const ExpressiveSkin();

  static const t = SkinTokens(
    bg: XC.surface,
    surface: XC.sc,
    surface2: XC.sch,
    line: XC.outv,
    text: XC.on,
    muted: XC.onv,
    faint: XC.outl,
    accent: XC.pri,
    onAccent: XC.onpri,
    ok: XC.pri,
    warn: Color(0xFF8B5000),
    bad: XC.err,
    claude: Color(0xFFB5532F),
    green: Color(0xFF1E7F3A),
    cpu: XC.pri,
    gpu: XC.ter,
    ram: XC.pri,
    vram: XC.ter,
    sky: XC.ter,
    cloud: XC.onv,
    body: _font,
    display: _font,
    radius: 26,
    dark: false,
  );

  @override
  SkinId get id => SkinId.expressive;
  @override
  SkinTokens get tokens => t;

  @override
  ToastStyle get toastStyle => const ToastStyle(bg: Color(0xFF2C3230), fg: Color(0xFFECF2EF), font: _font, radius: 8);

  @override
  Widget page(PageId id) => expressivePage(id);

  @override
  Widget card({required Widget child, EdgeInsets? padding, VoidCallback? onTap, String? label}) {
    Widget c = Container(
      padding: padding ?? const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(color: XC.sc, borderRadius: BorderRadius.circular(26)),
      child: label == null
          ? child
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: xttl()),
                const SizedBox(height: 8),
                Expanded(child: child),
              ],
            ),
    );
    if (onTap != null) c = Press(onTap: onTap, scale: .985, child: c);
    return c;
  }

  @override
  Widget shell(ShellArgs a) => _Shell(a);
}

const _titles = {
  PageId.home: 'Home',
  PageId.system: 'System',
  PageId.claude: 'Claude usage',
  PageId.calendar: 'Calendar',
  PageId.weather: 'Weather',
  PageId.music: 'Music',
  PageId.hotspot: 'Hotspot',
  PageId.timer: 'Timer',
  PageId.slack: 'Slack',
  PageId.github: 'GitHub',
  PageId.shortcuts: 'Shortcuts',
};

class _Shell extends StatelessWidget {
  const _Shell(this.a);
  final ShellArgs a;

  @override
  Widget build(BuildContext context) {
    final bottom = a.settings.navStyle == NavStyle.bottom;
    final main = Padding(
      padding: EdgeInsets.only(right: 10, left: bottom ? 10 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AppBar(a),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: bottom ? 6 : 10),
              child: bottom ? _fitHeight(a.child, 342) : a.child,
            ),
          ),
        ],
      ),
    );
    return ColoredBox(
      color: XC.surface,
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: XC.on, fontFamily: _font, fontSize: 13),
        child: bottom
            ? Column(
                children: [
                  Expanded(child: main),
                  _BottomBar(a),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 72, child: _Rail(a)),
                  Expanded(child: main),
                ],
              ),
      ),
    );
  }
}

/// Lays [child] out at least [designH] tall and scales it down when the space is
/// shorter (bottom-nav layout), so the dense pages never overflow.
Widget _fitHeight(Widget child, double designH) => LayoutBuilder(
  builder: (context, box) {
    if (!box.maxHeight.isFinite || box.maxHeight >= designH) return child;
    final k = box.maxHeight / designH;
    return FittedBox(
      fit: BoxFit.contain,
      alignment: Alignment.topLeft,
      child: SizedBox(width: box.maxWidth / k, height: designH, child: child),
    );
  },
);

class _Rail extends StatelessWidget {
  const _Rail(this.a);
  final ShellArgs a;

  @override
  Widget build(BuildContext context) {
    final s = connSummary(a.conn);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
      child: Column(
        children: [
          for (final p in a.pages)
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Press(
                  onTap: () => a.onSelect(p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 52,
                    height: 36,
                    decoration: BoxDecoration(
                      color: p == a.current ? XC.secc : const Color(0x00000000),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    alignment: Alignment.center,
                    child: DpIcon(
                      p.icon,
                      size: 19,
                      color: p == a.current ? XC.onsecc : XC.onv,
                      stroke: p == a.current ? 2.2 : 1.8,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 6),
          Press(
            onTap: a.onStatusTap,
            child: Container(
              width: 52,
              height: 30,
              decoration: BoxDecoration(color: s.ok ? XC.pric : XC.errc, borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: DpIcon(s.icon, size: 15, color: s.ok ? XC.onpric : XC.onerrc),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar(this.a);
  final ShellArgs a;

  @override
  Widget build(BuildContext context) => Container(
    height: 56,
    color: XC.sc,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: Row(
      children: [
        for (final p in a.pages)
          Expanded(
            child: Press(
              onTap: () => a.onSelect(p),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 52,
                  height: 32,
                  decoration: BoxDecoration(
                    color: p == a.current ? XC.secc : const Color(0x00000000),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  alignment: Alignment.center,
                  child: DpIcon(p.icon, size: 20, color: p == a.current ? XC.onsecc : XC.onv),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _AppBar extends ConsumerWidget {
  const _AppBar(this.a);
  final ShellArgs a;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = connSummary(a.conn);
    return Ticker(
      builder: (context, now) {
        final sub = switch (a.current) {
          PageId.home || PageId.calendar => longDate(now),
          PageId.system => 'Your laptop, live',
          PageId.claude => 'Claude Code plan limits',
          PageId.weather => ref.watch(weatherProvider)?.place ?? 'No location set',
          PageId.music => 'Playing on ${topicData<MediaData>(ref, 'media')?.source ?? 'your laptop'}',
          PageId.hotspot => topicData<HotspotData>(ref, 'hotspot')?.name ?? 'Roof phone',
          PageId.timer => 'Focus and breaks',
          PageId.slack => topicData<SlackData>(ref, 'slack')?.team ?? 'Messages',
          PageId.github => 'Last 12 months',
          PageId.shortcuts => 'Control your laptop',
        };
        return Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_titles[a.current]!, style: xt(22, w: 500, opsz: 28, h: 1.2)),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: xlab(c: XC.onv).copyWith(height: 1.35),
                    ),
                  ],
                ),
              ),
              XChip(icon: 'clock', label: a.settings.clock24 ? clock(now, h24: true) : '${clock(now)} ${ampm(now)}'),
              const SizedBox(width: 10),
              XChip(icon: 'monitor', label: s.text, onTap: a.onStatusTap, iconColor: s.ok ? XC.pri : XC.err),
            ],
          ),
        );
      },
    );
  }
}

/// Assist / filter chip (`.chip`, `.chip.f`).
class XChip extends StatelessWidget {
  const XChip({super.key, this.icon, required this.label, this.filled = false, this.onTap, this.iconColor, this.lead});
  final String? icon;
  final String label;
  final bool filled;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Widget? lead;

  @override
  Widget build(BuildContext context) {
    final c = Container(
      height: 30,
      padding: EdgeInsets.fromLTRB(icon != null || lead != null ? 8 : 12, 0, 12, 0),
      decoration: BoxDecoration(
        color: filled ? XC.secc : null,
        borderRadius: BorderRadius.circular(10),
        border: filled ? null : Border.all(color: XC.outv),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (lead != null) ...[lead!, const SizedBox(width: 6)],
          if (icon != null) ...[DpIcon(icon!, size: 16, color: iconColor ?? XC.pri), const SizedBox(width: 6)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: xt(12.5, w: 550, c: filled ? XC.onsecc : XC.on),
            ),
          ),
        ],
      ),
    );
    return onTap == null ? c : Press(onTap: onTap, child: c);
  }
}

// ------------------------------------------------------------------ Material shape library

/// Polar approximations of the M3 shape library (cookie, sunny, clover, flower).
enum XShape {
  cookie9(9, .07),
  cookie12(12, .05),
  sunny(8, .1),
  clover(4, .22),
  flower(6, .13);

  const XShape(this.n, this.a);
  final int n;
  final double a;

  Path path(Size s) {
    final c = Offset(s.width / 2, s.height / 2);
    final side = math.min(s.width, s.height);
    final r0 = side / 2 / (1 + a);
    final p = Path();
    for (var i = 0; i <= 200; i++) {
      final t = i / 200 * 2 * math.pi;
      final r = r0 * (1 + a * math.cos(n * t));
      final o = c + Offset(r * math.cos(t - math.pi / 2), r * math.sin(t - math.pi / 2));
      i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
    }
    return p..close();
  }
}

/// A filled shape with [child] centred on it.
class XShapeBox extends StatelessWidget {
  const XShapeBox({super.key, required this.shape, required this.color, required this.size, this.child});
  final XShape shape;
  final Color color;
  final double size;
  final Widget? child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: _ShapePainter(shape, color),
      child: child == null ? null : Center(child: child),
    ),
  );
}

class _ShapePainter extends CustomPainter {
  const _ShapePainter(this.shape, this.color);
  final XShape shape;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(shape.path(size), Paint()..color = color);
  @override
  bool shouldRepaint(_ShapePainter o) => o.shape != shape || o.color != color;
}

/// Clips [child] to a shape-library shape.
class XShapeClip extends StatelessWidget {
  const XShapeClip({super.key, required this.shape, required this.child});
  final XShape shape;
  final Widget child;
  @override
  Widget build(BuildContext context) => ClipPath(clipper: _ShapeClipper(shape), child: child);
}

class _ShapeClipper extends CustomClipper<Path> {
  const _ShapeClipper(this.shape);
  final XShape shape;
  @override
  Path getClip(Size size) => shape.path(size);
  @override
  bool shouldReclip(_ShapeClipper o) => o.shape != shape;
}
