// Liquid (concept 16) building blocks shared by every Liquid page: the glass material,
// cards, pills, buttons, rings, bars, the seek slider, the segmented control, list rows and
// the type scale. Page files import this; the shell lives in liquid.dart.
//
// Glass here = the concept's look without its costs: a translucent tint (clear or tinted),
// a specular rim that's brightest top-left, a soft sheen, inner top/bottom edge lines and a
// hard-edged drop shadow. No backdrop blur and no blurred shadows: the wallpaper is already
// soft, and on the desk phone anything blurred is redone every frame (Impeller keeps no
// raster cache) while the wallpaper moves.
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/proto/models.dart';
import '../../core/settings.dart';
import '../fmt.dart';
import '../icons.dart';
import '../widgets/common.dart';

// ------------------------------------------------------------------ colours

const lqTx = Color(0xFFFFFFFF);
const lqMu = Color(0xB8FFFFFF); // --mu .72
const lqFa = Color(0x80FFFFFF); // --fa .5
const lqSep = Color(0x29FFFFFF); // --sep .16
const lqCyan = Color(0xFF9CF3FF);
const lqGold = Color(0xFFFFD36E);
const lqMint = Color(0xFF8CFFB0);
const lqGreen = Color(0xFF5CF29B); // the connection dot
const lqRed = Color(0xFFFF6B6B);
const lqInk = Color(0xFF111111); // text on solid white glass

// ------------------------------------------------------------------ type

/// Body text (concept: SF Pro / Inter, -0.01em).
TextStyle lqT(double size, {FontWeight w = FontWeight.w500, Color c = lqTx, double? h, double ls = -.01}) =>
    TextStyle(
      fontFamily: 'Inter',
      fontSize: size,
      fontWeight: w,
      color: c,
      height: h,
      letterSpacing: ls * size,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// `.rnd` figures: bold, tight, tabular (SF Pro Rounded where Apple has it; Inter here).
TextStyle lqN(double size, {Color c = lqTx, FontWeight w = FontWeight.w700}) =>
    lqT(size, w: w, c: c, h: .92, ls: -.02);

/// `.lab`: the small muted card label.
Widget lqLab(String s, {Color c = lqMu}) =>
    Text(s, style: lqT(12.5, w: FontWeight.w600, c: c), maxLines: 1, overflow: TextOverflow.ellipsis);

/// `.big` number with its `<small>` unit (0.42 em, muted).
Widget lqBig(String v, double size, {String? unit, Color c = lqTx}) => Text.rich(
      TextSpan(children: [
        TextSpan(text: v, style: lqN(size, c: c)),
        if (unit != null) TextSpan(text: ' $unit', style: lqT(size * .42, w: FontWeight.w600, c: lqMu)),
      ]),
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.fade,
    );

/// "in 21m" / "now" for an event.
String lqIn(CalEvent e, DateTime now) {
  final d = e.start.difference(now);
  if (d.isNegative) return 'now';
  return 'in ${dur(d)}';
}

// ------------------------------------------------------------------ glass mode

/// Clear (the default) or Tinted glass: the top-bar switch, saved as `liquid.glass`.
enum LqGlassMode { clear, tinted }

class LqGlassModeNotifier extends Notifier<LqGlassMode> {
  static const key = 'liquid.glass';

  @override
  LqGlassMode build() =>
      ref.read(prefsProvider).getString(key) == 'tinted' ? LqGlassMode.tinted : LqGlassMode.clear;

  void toggle() {
    state = state == LqGlassMode.clear ? LqGlassMode.tinted : LqGlassMode.clear;
    ref.read(prefsProvider).setString(key, state.name);
  }
}

final lqGlassModeProvider = NotifierProvider<LqGlassModeNotifier, LqGlassMode>(LqGlassModeNotifier.new);

/// Glass fill for the current mode (`--gbg`): clear white .10 / tinted rgba(22,24,38,.46).
class LqGlassTint extends InheritedWidget {
  const LqGlassTint({super.key, required this.tinted, required super.child});
  final bool tinted;
  static bool of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<LqGlassTint>()?.tinted ?? false;
  static Color fill(BuildContext c) => of(c) ? const Color(0x75161826) : const Color(0x1AFFFFFF);
  @override
  bool updateShouldNotify(LqGlassTint old) => old.tinted != tinted;
}

// ------------------------------------------------------------------ glass

/// The glass material (`.glass`). [radius] 26 for cards, 99 for pills / circles. [fill]
/// overrides the tint (e.g. `.solid` white buttons, the droplet, a lit toggle).
class LqGlass extends StatelessWidget {
  const LqGlass({super.key, required this.child, this.radius = 26, this.padding, this.fill, this.shadow = true});
  final Widget child;
  final double radius;
  final EdgeInsets? padding;
  final Color? fill;
  final bool shadow;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _GlassPainter(radius, fill ?? LqGlassTint.fill(context), shadow),
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      );
}

class _GlassPainter extends CustomPainter {
  _GlassPainter(this.radius, this.fill, this.shadow);
  final double radius;
  final Color fill;
  final bool shadow;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final r = RRect.fromRectAndRadius(rect, Radius.circular(math.min(radius, size.shortestSide / 2)));
    // box-shadow 0 10px 30px rgba(0,0,0,.16), done hard-edged (no blur).
    if (shadow) canvas.drawRRect(r.shift(const Offset(0, 4)), Paint()..color = const Color(0x1F000000));
    canvas.drawRRect(r, Paint()..color = fill);
    canvas.save();
    canvas.clipRRect(r);
    // ::after: radial highlights, top-left (white .22) and bottom-right (white .08).
    canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-.56, -1.2),
            radius: 1.1,
            colors: const [Color(0x38FFFFFF), Color(0x00FFFFFF)],
            stops: const [0, .55],
          ).createShader(rect));
    canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(.8, 1.4),
            radius: .8,
            colors: const [Color(0x14FFFFFF), Color(0x00FFFFFF)],
            stops: const [0, .6],
          ).createShader(rect));
    // inset 0 1px 0 white .42 (top edge) and inset 0 -1px 0 white .08 (bottom edge): the
    // outline nudged 1 px inwards, kept to the top / bottom third.
    void edge(double dy, double from, double to, Color c) {
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(0, size.height * from, size.width, size.height * to));
      canvas.drawRRect(r.shift(Offset(0, dy)), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = c);
      canvas.restore();
    }

    edge(1, 0, .35, const Color(0x6BFFFFFF));
    edge(-1, .65, 1, const Color(0x14FFFFFF));
    canvas.restore();
    // ::before: the specular rim, 1.2 px, 140° gradient.
    canvas.drawRRect(
        r.deflate(.6),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..shader = const LinearGradient(
            begin: Alignment(-.77, -.64),
            end: Alignment(.77, .64),
            colors: [Color(0xD9FFFFFF), Color(0x1FFFFFFF), Color(0x00FFFFFF), Color(0x2EFFFFFF), Color(0x8CFFFFFF)],
            stops: [0, .28, .55, .78, 1],
          ).createShader(rect));
  }

  @override
  bool shouldRepaint(_GlassPainter o) => o.radius != radius || o.fill != fill || o.shadow != shadow;
}

/// `.glass.card`: padding 12/16, radius 26; tappable when [onTap] is set.
class LqCard extends StatelessWidget {
  const LqCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 12)});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = LqGlass(padding: padding, child: child);
    return onTap == null ? c : Press(onTap: onTap, scale: .985, child: c);
  }
}

/// `.glass.pill`: 34 high, icon + text.
class LqPill extends StatelessWidget {
  const LqPill({super.key, required this.children, this.height = 34, this.onTap, this.fill, this.fontSize = 13.5});
  final List<Widget> children;
  final double height, fontSize;
  final VoidCallback? onTap;
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    final p = SizedBox(
      height: height,
      child: LqGlass(
        radius: 99,
        fill: fill,
        shadow: false,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: DefaultTextStyle(
          style: lqT(fontSize, w: FontWeight.w600),
          child: IconTheme(
            data: const IconThemeData(color: lqTx),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (final (i, w) in children.indexed) ...[if (i > 0) const SizedBox(width: 7), w],
            ]),
          ),
        ),
      ),
    );
    return onTap == null ? p : Press(onTap: onTap, child: p);
  }
}

/// `.glass.gbtn`: a glass button that swells when pressed (`:active scale(1.08)`).
/// [solid] = the white one (`.solid`). With [circle] it's round ([size] across).
class LqButton extends StatelessWidget {
  const LqButton({
    super.key,
    required this.child,
    required this.onTap,
    this.solid = false,
    this.height = 40,
    this.circle = false,
    this.size = 52,
    this.padding = const EdgeInsets.symmetric(horizontal: 18),
  });

  /// Icon-only round button (`.circ`).
  factory LqButton.icon(String icon, VoidCallback? onTap, {double size = 52, double iconSize = 20, bool solid = false}) =>
      LqButton(
        onTap: onTap,
        circle: true,
        size: size,
        solid: solid,
        child: DpIcon(icon, size: iconSize, color: solid ? lqInk : lqTx, stroke: 2),
      );

  final Widget child;
  final VoidCallback? onTap;
  final bool solid, circle;
  final double height, size;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final body = LqGlass(
      radius: 99,
      fill: solid ? const Color(0xEBFFFFFF) : null,
      padding: circle ? EdgeInsets.zero : padding,
      child: DefaultTextStyle(
        style: lqT(14, w: FontWeight.w600, c: solid ? lqInk : lqTx),
        child: Center(widthFactor: circle ? null : 1, child: child),
      ),
    );
    final sized = circle ? SizedBox(width: size, height: size, child: body) : SizedBox(height: height, child: body);
    if (onTap == null) return Opacity(opacity: .55, child: sized);
    return Press(onTap: onTap, scale: 1.08, child: sized);
  }
}

/// `.seg`: glass segmented control; the selected segment is solid white with dark text.
class LqSeg<T> extends StatelessWidget {
  const LqSeg({super.key, required this.items, required this.value, required this.onChanged});
  final List<(T, String)> items;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => LqGlass(
        radius: 99,
        shadow: false,
        padding: const EdgeInsets.all(3),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final (v, l) in items)
            Press(
              onTap: () => onChanged(v),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: v == value ? const Color(0xE6FFFFFF) : const Color(0x00FFFFFF),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(l, style: lqT(13, w: FontWeight.w600, c: v == value ? lqInk : lqMu)),
              ),
            ),
        ]),
      );
}

// ------------------------------------------------------------------ rings and bars

/// `.ring`: a 0..1 arc on a faint track (stroke in viewBox units of 100, like the SVG).
class LqRing extends StatelessWidget {
  const LqRing({super.key, required this.value, required this.size, this.stroke = 9, this.color = lqTx, this.child});
  final double value, size, stroke;
  final Color color;
  final Widget? child;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(value.isFinite ? value.clamp(0, 1).toDouble() : 0, stroke, color),
          child: Center(child: child),
        ),
      );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.stroke, this.color);
  final double v, stroke;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 100; // viewBox 100, r 42
    final c = size.center(Offset.zero), r = 42 * s, w = stroke * s;
    canvas.drawCircle(c, r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..color = const Color(0x33FFFFFF));
    if (v < .004) return;
    final arc = Rect.fromCircle(center: c, radius: r);
    // drop-shadow(0 0 6px white .45), done as a wider faint stroke underneath.
    canvas.drawArc(arc, -math.pi / 2, v * 2 * math.pi, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w + 6 * s
      ..color = color.withValues(alpha: .18));
    canvas.drawArc(arc, -math.pi / 2, v * 2 * math.pi, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w
      ..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.v != v || o.color != color || o.stroke != stroke;
}

/// `.bar`: rounded track (white .18) with a glowing fill.
class LqBar extends StatelessWidget {
  const LqBar({super.key, required this.value, this.color = lqTx, this.height = 8});
  final double value, height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final v = value.isFinite ? value.clamp(0.0, 1.0) : 0.0;
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(color: const Color(0x2EFFFFFF), borderRadius: BorderRadius.circular(99)),
        child: Align(
          alignment: Alignment.centerLeft,
          child: AnimatedFractionallySizedBox(
            duration: const Duration(milliseconds: 500),
            widthFactor: v,
            heightFactor: 1,
            child: DecoratedBox(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99))),
          ),
        ),
      ),
    );
  }
}

/// `.slider`: a thin white track with a glass knob; tap or drag to set (sent on release).
class LqSlider extends StatefulWidget {
  const LqSlider({super.key, required this.value, this.onChanged});
  final double value;
  final ValueChanged<double>? onChanged;
  @override
  State<LqSlider> createState() => _LqSliderState();
}

class _LqSliderState extends State<LqSlider> {
  double? _drag;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth;
        double f(Offset p) => (p.dx / w).clamp(0.0, 1.0);
        final v = (_drag ?? widget.value).clamp(0.0, 1.0);
        final on = widget.onChanged;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: on == null ? null : (d) => on(f(d.localPosition)),
          onHorizontalDragStart: on == null ? null : (d) => setState(() => _drag = f(d.localPosition)),
          onHorizontalDragUpdate: on == null ? null : (d) => setState(() => _drag = f(d.localPosition)),
          onHorizontalDragEnd: on == null
              ? null
              : (_) {
                  on(_drag!);
                  setState(() => _drag = null);
                },
          child: SizedBox(
            height: 30,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned(
                left: 0,
                right: 0,
                top: 12,
                height: 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: const Color(0x38FFFFFF), borderRadius: BorderRadius.circular(99)),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: v,
                      heightFactor: 1,
                      child: DecoratedBox(
                          decoration: BoxDecoration(color: lqTx, borderRadius: BorderRadius.circular(99))),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: v * w - 21,
                top: 2,
                width: 42,
                height: 26,
                child: const LqGlass(radius: 99, fill: Color(0x40FFFFFF), child: SizedBox.expand()),
              ),
            ]),
          ),
        );
      });
}

// ------------------------------------------------------------------ lists

/// `.li`: leading, title/subtitle, trailing; a hairline between consecutive rows
/// (pass [first] for the top one).
class LqRow extends StatelessWidget {
  const LqRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.first = false,
    this.onTap,
    this.dim = false,
  });
  final Widget? leading, trailing;
  final String title;
  final String? subtitle;
  final bool first, dim;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: lqSep))),
      child: Opacity(
        opacity: dim ? .5 : 1,
        child: Row(children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(title, style: lqT(14.5, w: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (subtitle != null)
                Text(subtitle!, style: lqT(12.5, c: lqMu), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ]),
      ),
    );
    return onTap == null ? row : Press(onTap: onTap, scale: .99, child: row);
  }
}

/// The connection dot (green, red when offline), with its glow as a faint halo.
Widget lqDot({bool ok = true, double size = 8}) {
  final c = ok ? lqGreen : lqRed;
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: c,
      border: Border.all(color: c.withValues(alpha: .35), width: 2, strokeAlign: BorderSide.strokeAlignOutside),
    ),
  );
}

/// A grid helper: [rows] of [Expanded] children with the concept's 12 px gaps.
/// Each row is (flex, [(flex, child)…]).
Widget lqGrid(List<(int, List<(int, Widget)>)> rows, {double gap = 12}) => Column(children: [
      for (final (i, (rf, cells)) in rows.indexed) ...[
        if (i > 0) SizedBox(height: gap),
        Expanded(
          flex: rf,
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final (j, (cf, w)) in cells.indexed) ...[
              if (j > 0) SizedBox(width: gap),
              Expanded(flex: cf, child: w),
            ],
          ]),
        ),
      ],
    ]);
