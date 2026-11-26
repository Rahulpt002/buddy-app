// Concept 4 — Ink pages. Sizes follow deskpanel-concept-4-ink.html (CSS px = logical px).
// Monochrome: black ink on grey paper; dot / hatch / checker patterns stand in for colour.
// Nothing animates (no tweens) — e-paper redraws in place. The one moving thing, the record
// on the Music page, turns in coarse steps like an e-ink screen refreshing.
import 'dart:async';
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
import '../widgets/art.dart';
import '../widgets/common.dart';
import 'ink.dart';

const _paper = InkSkin.paper;
const _ink = InkSkin.ink;
const _ink2 = InkSkin.ink2;
const _ink3 = InkSkin.ink3;
const _gap = 9.0;
const _tab = [ui.FontFeature.tabularFigures()];

Widget inkPage(PageId id) => switch (id) {
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

// ------------------------------------------------------------------ type

/// Atkinson Hyperlegible body text (400 / 700).
TextStyle _tx(double s, {FontWeight w = FontWeight.w400, Color c = _ink, double h = 1.35, double? ls}) => TextStyle(
  fontFamily: 'Atkinson Hyperlegible',
  fontSize: s,
  fontWeight: w,
  color: c,
  height: h,
  letterSpacing: ls,
  fontFeatures: _tab,
);

/// Bricolage Grotesque condensed ExtraBold (`.n`, headings, kv values).
TextStyle _bri(
  double s, {
  double w = 800,
  double wdth = 78,
  double opsz = 96,
  Color c = _ink,
  double h = .86,
  double ls = -.005,
}) => TextStyle(
  fontFamily: 'Bricolage Grotesque',
  fontSize: s,
  fontWeight: w >= 750 ? FontWeight.w800 : FontWeight.w700,
  fontVariations: [FontVariation('wght', w), FontVariation('wdth', wdth), FontVariation('opsz', opsz)],
  color: c,
  height: h,
  letterSpacing: ls * s,
  fontFeatures: _tab,
);

Color _on(bool blk, [double a = 1]) => (blk ? _paper : _ink).withValues(alpha: a);

/// `.n` big number with an optional `.38em` unit, baseline-aligned.
Widget _n(String v, double size, {String? unit, double unitK = .38, Color c = _ink, bool fit = true}) {
  final row = Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      Text(v, maxLines: 1, style: _bri(size, c: c)),
      if (unit != null) ...[
        const SizedBox(width: 2),
        Text(unit, maxLines: 1, style: _bri(size * unitK, w: 700, c: c, ls: 0)),
      ],
    ],
  );
  return fit ? FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: row) : row;
}

/// `.mh` module heading (12 / 700, optional icon).
Widget _mh(String s, {String? icon, bool blk = false, Widget? trailing}) {
  final c = _on(blk, blk ? .85 : 1);
  final title = Text(
    s,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: _tx(12, w: FontWeight.w700, c: c),
  );
  return Row(
    children: [
      if (icon != null) ...[DpIcon(icon, size: 12, color: c, stroke: 2), const SizedBox(width: 6)],
      if (trailing == null) Flexible(child: title) else title,
      if (trailing != null) ...[
        const SizedBox(width: 10),
        Expanded(
          child: Align(alignment: Alignment.centerRight, child: trailing),
        ),
      ],
    ],
  );
}

/// `.sub` secondary text.
TextStyle _subS({bool blk = false, double size = 12, FontWeight w = FontWeight.w400}) =>
    _tx(size, w: w, c: blk ? _paper.withValues(alpha: .75) : _ink2);

Widget _sub(String s, {bool blk = false, int lines = 1, TextAlign? align, double size = 12}) => Text(
  s,
  maxLines: lines,
  overflow: TextOverflow.ellipsis,
  textAlign: align,
  style: _subS(blk: blk, size: size),
);

// ------------------------------------------------------------------ patterns

enum _Pat {
  solid,
  paper,

  /// `--d1`: dots on a 4 px grid.
  d1,

  /// `--d2`: dense dots on a 2.6 px grid.
  d2,

  /// `--hatch`: 45° rules, 1.3 px every 4.2 px.
  hatch,

  /// `--check`: 1.5 px checkerboard.
  check,

  /// SVG pattern `s`: sparse dots (4.5 px).
  sparse,

  /// SVG pattern `d`: dots on 3.2 px.
  dots,

  /// SVG pattern `h`: 45° rules, 1.5 px every 4 px.
  rules,

  /// SVG pattern `c`: 1.2 px checker.
  fine,
}

void _dotsAt(Canvas c, Rect r, double step, double rad, Color col) {
  final pts = <Offset>[];
  for (var y = r.top + step / 2; y < r.bottom + rad; y += step) {
    for (var x = r.left + step / 2; x < r.right + rad; x += step) {
      pts.add(Offset(x, y));
    }
  }
  c.drawPoints(
    ui.PointMode.points,
    pts,
    Paint()
      ..color = col
      ..strokeWidth = rad * 2
      ..strokeCap = StrokeCap.round,
  );
}

void _rulesAt(Canvas c, Rect r, double period, double th, Color col) {
  final p = Paint()
    ..color = col
    ..strokeWidth = th;
  final step = period * math.sqrt2;
  for (var k = r.left + r.top - step; k < r.right + r.bottom + step; k += step) {
    c.drawLine(Offset(k - r.top, r.top), Offset(k - r.bottom, r.bottom), p);
  }
}

void _checkAt(Canvas c, Rect r, double cell, Color col) {
  final h = cell / 2;
  final path = Path();
  for (var y = r.top; y < r.bottom; y += cell) {
    for (var x = r.left; x < r.right; x += cell) {
      path
        ..addRect(Rect.fromLTWH(x + h, y, h, h))
        ..addRect(Rect.fromLTWH(x, y + h, h, h));
    }
  }
  c.drawPath(path, Paint()..color = col);
}

/// Fills [r] with [p]. Callers clip to the shape first.
void _fill(Canvas c, Rect r, _Pat p, [Color col = _ink]) {
  c.save();
  c.clipRect(r);
  _fillRaw(c, r, p, col);
  c.restore();
}

void _fillRaw(Canvas c, Rect r, _Pat p, Color col) {
  switch (p) {
    case _Pat.solid:
      c.drawRect(r, Paint()..color = col);
    case _Pat.paper:
      c.drawRect(r, Paint()..color = _paper);
    case _Pat.d1:
      _dotsAt(c, r, 4, 1.05, col);
    case _Pat.d2:
      _dotsAt(c, r, 2.6, 1.12, col);
    case _Pat.hatch:
      _rulesAt(c, r, 4.2, 1.3, col);
    case _Pat.check:
      _checkAt(c, r, 3, col);
    case _Pat.sparse:
      _dotsAt(c, r, 4.5, .7, col);
    case _Pat.dots:
      _dotsAt(c, r, 3.2, .75, col);
    case _Pat.rules:
      _rulesAt(c, r, 4, 1.5, col);
    case _Pat.fine:
      _checkAt(c, r, 2.4, col);
  }
}

/// A rounded box filled with a pattern and an ink outline (`.cols i`, spools, keys).
class _PatBox extends CustomPainter {
  _PatBox(this.pat, {this.radius = BorderRadius.zero, this.bw = 2});
  final _Pat pat;
  final BorderRadius radius;
  final double bw;
  final Color? bg = _paper;
  final Color border = _ink;

  @override
  void paint(Canvas canvas, Size size) {
    final rr = radius.toRRect(Offset.zero & size);
    canvas.save();
    canvas.clipRRect(rr);
    if (bg != null) canvas.drawRect(Offset.zero & size, Paint()..color = bg!);
    _fill(canvas, Offset.zero & size, pat);
    canvas.restore();
    if (bw > 0) {
      canvas.drawRRect(
        rr.deflate(bw / 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = bw
          ..color = border,
      );
    }
  }

  @override
  bool shouldRepaint(_PatBox o) => o.pat != pat || o.radius != radius || o.bg != bg || o.border != border;
}

/// `.bar`: 2 px outlined pill, filled to [value] with a pattern.
class _Bar extends StatelessWidget {
  const _Bar(this.value, {this.pat = _Pat.solid, this.height = 13, this.blk = false});
  final double value, height;
  final _Pat pat;
  final bool blk;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: CustomPaint(painter: _BarPainter(value.clamp(0.0, 1.0), pat, blk)),
  );
}

class _BarPainter extends CustomPainter {
  _BarPainter(this.v, this.pat, this.blk);
  final double v;
  final _Pat pat;
  final bool blk;
  @override
  void paint(Canvas canvas, Size size) {
    final outer = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.height / 2));
    final inner = outer.deflate(2);
    canvas.drawRRect(outer, Paint()..color = blk ? _paper : _ink);
    canvas.drawRRect(inner, Paint()..color = blk ? _ink : _paper);
    if (v <= 0) return;
    canvas.save();
    canvas.clipRRect(inner);
    _fill(
      canvas,
      Rect.fromLTWH(inner.left, inner.top, inner.width * v, inner.height),
      blk ? _Pat.solid : pat,
      blk ? _paper : _ink,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BarPainter o) => o.v != v || o.pat != pat || o.blk != blk;
}

/// 1.5 px dotted rule (`border-bottom: 1.5px dotted var(--ink3)`).
class _Dots extends CustomPainter {
  const _Dots();
  @override
  void paint(Canvas canvas, Size size) {
    final pts = <Offset>[for (var x = .75; x < size.width; x += 3) Offset(x, size.height / 2)];
    canvas.drawPoints(
      ui.PointMode.points,
      pts,
      Paint()
        ..color = _ink3
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_Dots o) => false;
}

const Widget _rule = SizedBox(
  height: 1.5,
  width: double.infinity,
  child: CustomPaint(painter: _Dots()),
);

// ------------------------------------------------------------------ containers

/// `.mod`: 2 px ink outline, radius 12.
Widget _mod(Widget child, {EdgeInsets pad = const EdgeInsets.fromLTRB(12, 9, 12, 9), VoidCallback? onTap}) {
  Widget c = Container(
    padding: pad,
    decoration: BoxDecoration(
      color: _paper,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _ink, width: 2),
    ),
    child: child,
  );
  if (onTap != null) c = GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: c);
  return c;
}

/// `.blk`: solid ink block, radius 14, paper text.
Widget _blk(Widget child, {EdgeInsets pad = const EdgeInsets.fromLTRB(15, 11, 15, 11), VoidCallback? onTap}) {
  Widget c = Container(
    padding: pad,
    decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(14)),
    child: child,
  );
  if (onTap != null) c = GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: c);
  return c;
}

/// `.head`: big condensed title, extras on the right.
Widget _head(String title, [Widget? right]) => Padding(
  padding: const EdgeInsets.only(bottom: _gap),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Flexible(
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _bri(25, wdth: 80, opsz: 48, h: 1, ls: -.02),
        ),
      ),
      if (right != null) ...[const SizedBox(width: 10), right],
    ],
  ),
);

Widget _kv(String k, String v, {bool last = false, double pad = 3}) => Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    Padding(
      padding: EdgeInsets.symmetric(vertical: pad),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(k, maxLines: 1, overflow: TextOverflow.ellipsis, style: _tx(13)),
          ),
          const SizedBox(width: 8),
          Text(v, style: _bri(18, wdth: 80, h: 1.1)),
        ],
      ),
    ),
    if (!last) _rule,
  ],
);

/// `.btn`: 38 px outlined pill; [inv] = black.
Widget _btn(String label, VoidCallback? onTap, {bool inv = false, double height = 38, String? icon}) => GestureDetector(
  behavior: HitTestBehavior.opaque,
  onTap: onTap,
  child: Opacity(
    opacity: onTap == null ? .6 : 1,
    child: Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: inv ? _ink : _paper,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: _ink, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            DpIcon(icon, size: 17, color: inv ? _paper : _ink, stroke: 2),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: _tx(13.5, w: FontWeight.w700, c: inv ? _paper : _ink, h: 1),
          ),
        ],
      ),
    ),
  ),
);

/// `.round`: circular control.
Widget _round(String icon, VoidCallback onTap, {bool inv = false, double size = 46, double? iconSize}) =>
    GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: inv ? _ink : null,
          border: Border.all(color: _ink, width: 2),
        ),
        alignment: Alignment.center,
        child: DpIcon(icon, size: iconSize ?? (inv ? 24 : 18), color: inv ? _paper : _ink, stroke: 2.2),
      ),
    );

Widget _tag(String s) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
  decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(6)),
  child: Text(
    s,
    style: _tx(12, w: FontWeight.w700, c: _paper),
  ),
);

/// `.seg`: pill segmented control.
Widget _seg(List<String> items, int value, ValueChanged<int> onChanged) => Container(
  padding: const EdgeInsets.all(2),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(99),
    border: Border.all(color: _ink, width: 2),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final (i, s) in items.indexed)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(i),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 3),
            decoration: BoxDecoration(color: i == value ? _ink : null, borderRadius: BorderRadius.circular(99)),
            child: Text(
              s,
              style: _tx(12.5, w: FontWeight.w700, c: i == value ? _paper : _ink),
            ),
          ),
        ),
    ],
  ),
);

/// `.frame`: art in a 2 px outline.
Widget _frame(Widget child, {double radius = 12, double bw = 2}) => Container(
  decoration: BoxDecoration(
    color: _paper,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: _ink, width: bw),
  ),
  child: ClipRRect(borderRadius: BorderRadius.circular(math.max(0, radius - bw)), child: child),
);

String _inText(CalEvent e, DateTime now) {
  if (!e.start.isAfter(now)) return 'now';
  final d = e.start.difference(now);
  return d.inMinutes < 1 ? 'now' : 'in ${dur(d)}';
}

String _time(DateTime t, bool h24) => clockFull(t, h24: h24);

// ------------------------------------------------------------------ art

/// Monochrome cover art (the concept's `inkArt`): a sun over hills, drawn with dither
/// patterns, viewBox 100×100 cropped like `xMidYMid slice`.
class _InkArt extends CustomPainter {
  _InkArt(this.seed);
  final int seed;
  static const w = 100.0;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.max(size.width / w, size.height / 100);
    canvas.clipRect(Offset.zero & size);
    canvas.translate((size.width - w * s) / 2, (size.height - 100 * s) / 2);
    canvas.scale(s);
    final box = Rect.fromLTWH(0, 0, w, 100);
    final k = w / 100;
    final sx = (30 + (seed * 37) % 40) * k, sy = 32.0 + (seed * 13) % 12;
    canvas.drawRect(box, Paint()..color = _paper);
    if (seed % 3 == 0) _fill(canvas, box, _Pat.sparse);
    final sun = Offset(sx, sy);
    canvas.drawCircle(sun, 17, Paint()..color = _paper);
    canvas.drawCircle(
      sun,
      17,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = _ink,
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: sun, radius: 11)));
    _fill(canvas, Rect.fromCircle(center: sun, radius: 11), _Pat.dots);
    canvas.restore();
    canvas.save();
    canvas.scale(k, 1);
    final back = Path()
      ..moveTo(0, 62)
      ..cubicTo(22, 53, 42, 68, 66, 58)
      ..cubicTo(90, 48, 100, 54, 100, 54)
      ..lineTo(100, 100)
      ..lineTo(0, 100)
      ..close();
    canvas.save();
    canvas.clipPath(back);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 100, 100), Paint()..color = _paper);
    _fill(canvas, const Rect.fromLTWH(0, 40, 100, 60), _Pat.rules);
    canvas.restore();
    canvas.drawPath(
      back,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 / s
        ..color = _ink,
    );
    final front = Path()
      ..moveTo(0, 78)
      ..cubicTo(28, 70, 58, 86, 100, 72)
      ..lineTo(100, 100)
      ..lineTo(0, 100)
      ..close();
    canvas.drawPath(front, Paint()..color = _ink);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_InkArt o) => o.seed != seed;
}

const _gray = ColorFilter.matrix([
  .2126, .7152, .0722, 0, 0, //
  .2126, .7152, .0722, 0, 0, //
  .2126, .7152, .0722, 0, 0, //
  0, 0, 0, 1, 0,
]);

Widget _inkArt(int seed) => CustomPaint(painter: _InkArt(seed), size: Size.infinite);

/// Real cover art goes grey on e-paper; without one, the dithered fallback.
Widget _cover(String title, {String? b64}) {
  if (b64 == null || b64.isEmpty) return _inkArt((stableHash(title) % 7) + 1);
  return ColorFiltered(
    colorFilter: _gray,
    child: AlbumArt(title: title, b64: b64),
  );
}

// ------------------------------------------------------------------ step chart

class _StepChart extends CustomPainter {
  _StepChart({required this.main, this.dashed, required this.hi, required this.fill, this.width = 2.4});
  final List<double?> main;
  final List<double?>? dashed;
  final double hi, width;
  final _Pat fill;

  /// The concept's `stepPath`: M0 y0, then H x V y per sample, H w. Nulls break the run.
  List<Path> _runs(List<double?> vals, Size s) {
    final out = <Path>[];
    if (vals.isEmpty) return out;
    final dx = s.width / vals.length;
    double y(double v) => s.height * (1 - v.clamp(0, hi) / hi);
    Path? p;
    double? py;
    for (var i = 0; i < vals.length; i++) {
      final v = vals[i];
      if (v == null) {
        if (p != null) {
          p.lineTo(i * dx, py!);
          out.add(p);
        }
        p = null;
        continue;
      }
      final ny = y(v);
      if (p == null) {
        p = Path()..moveTo(i * dx, ny);
      } else {
        p
          ..lineTo(i * dx, py!)
          ..lineTo(i * dx, ny);
      }
      py = ny;
    }
    if (p != null) out.add(p..lineTo(s.width, py!));
    return out;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..color = _ink;
    for (final r in _runs(main, size)) {
      final b = r.getBounds();
      final area = Path.from(r)
        ..lineTo(b.right, size.height)
        ..lineTo(b.left, size.height)
        ..close();
      canvas.save();
      canvas.clipPath(area);
      _fill(canvas, Offset.zero & size, fill);
      canvas.restore();
    }
    if (dashed != null) {
      for (final r in _runs(dashed!, size)) {
        final d = Path();
        for (final m in r.computeMetrics()) {
          for (var t = 0.0; t < m.length; t += 10) {
            d.addPath(m.extractPath(t, math.min(t + 6, m.length)), Offset.zero);
          }
        }
        canvas.drawPath(d, line..strokeWidth = 2.2);
      }
    }
    for (final r in _runs(main, size)) {
      canvas.drawPath(r, line..strokeWidth = width);
    }
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      Paint()
        ..color = _ink
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_StepChart o) => true;
}

/// Legend swatch: a 22 px solid or dashed rule.
Widget _legend(String s, {bool dashed = false}) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    SizedBox(width: 22, height: 6, child: CustomPaint(painter: _LegendLine(dashed))),
    const SizedBox(width: 5),
    Text(s, style: _tx(12, w: FontWeight.w700)),
  ],
);

class _LegendLine extends CustomPainter {
  _LegendLine(this.dashed);
  final bool dashed;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = _ink
      ..strokeWidth = 2.4;
    final y = size.height / 2;
    if (!dashed) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    } else {
      for (var x = 0.0; x < size.width; x += 8) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 5, size.width), y), p);
      }
    }
  }

  @override
  bool shouldRepaint(_LegendLine o) => false;
}

// ------------------------------------------------------------------ Home

class _Home extends ConsumerWidget {
  const _Home();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void go(PageId p) => PageNav.go(context, p);
    return Ticker(
      builder: (context, now) => Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 1150, child: _clock(ref, now, () => go(PageId.calendar))),
                const SizedBox(width: _gap),
                Expanded(
                  flex: 2090,
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _weather(ref, () => go(PageId.weather))),
                            const SizedBox(width: _gap),
                            Expanded(child: _claude(ref, now, () => go(PageId.claude))),
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
                            Expanded(child: _laptop(ref, () => go(PageId.system))),
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
          Row(
            children: [
              const Spacer(flex: 1150),
              const SizedBox(width: _gap),
              Expanded(flex: 2090, child: _music(context, ref, () => go(PageId.music))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _clock(WidgetRef ref, DateTime now, VoidCallback onTap) {
    final h24 = ref.watch(settingsProvider.select((s) => s.clock24));
    final n = nextEvent(ref.watch(calendarEventsProvider), now);
    return _blk(
      onTap: onTap,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _mh(longDate(now), blk: true),
          const SizedBox(height: 12),
          _n(
            clock(now, h24: h24),
            128,
            unit: h24 ? null : ampm(now),
            unitK: .3,
            c: _paper,
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _paper, width: 2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n?.title ?? 'Nothing else today',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _tx(15, w: FontWeight.w700, c: _paper),
                ),
                _sub(
                  n == null ? 'Free until tomorrow' : [_inText(n, now), _time(n.start, h24), ?n.location].join(', '),
                  blk: true,
                ),
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
    String note = 'Set a location in Settings';
    if (w != null) {
      note = w.now.condition;
      if (w.days.isNotEmpty) note += ', high ${temp(w.days.first.hiC, f)}°.';
      final rain = w.days.indexed.where((e) => e.$1 > 0 && e.$2.icon == 'rain').firstOrNull;
      if (rain != null) note += ' Rain ${rain.$1 == 1 ? 'tomorrow' : weekday(rain.$2.date)}.';
    }
    return _mod(
      onTap: onTap,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _mh('Weather', icon: w?.now.icon ?? 'cloud'),
          const SizedBox(height: 6),
          _n(w == null ? '—' : '${temp(w.now.tempC, f)}°', 64),
          const Spacer(),
          _sub(note),
        ],
      ),
    );
  }

  Widget _claude(WidgetRef ref, DateTime now, VoidCallback onTap) {
    final c = topicData<ClaudeData>(ref, 'claude');
    final five = limitPct(c?.fiveHour, now), week = limitPct(c?.sevenDay, now);
    final reset = c?.fiveHour == null ? '—' : resetsIn(c!.fiveHour, now).replaceFirst('Resets in ', '');
    return _mod(
      onTap: onTap,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _mh('Claude, 5-hour', icon: 'claude'),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 6, 0, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                c?.fiveHour == null ? _n('—', 64) : _n('${five.round()}', 64, unit: '%'),
                const Spacer(),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'resets in\n'),
                      TextSpan(
                        text: reset,
                        style: _tx(12, w: FontWeight.w700),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.right,
                  style: _subS(),
                ),
              ],
            ),
          ),
          _Bar(five / 100, pat: _Pat.d2),
          const SizedBox(height: 7),
          Row(
            children: [
              Text('Weekly', style: _subS()),
              const Spacer(),
              Text(c?.sevenDay == null ? '—' : '${week.round()}%', style: _tx(12, w: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 3),
          _Bar(week / 100, pat: _Pat.hatch, height: 9),
        ],
      ),
    );
  }

  /// Unread count, then the newest unread message (avatar, sender, one line). Calm when
  /// nothing is waiting: "0 unread" over "All caught up".
  Widget _slack(WidgetRef ref, DateTime now, VoidCallback onTap) {
    final info = slackHome(ref);
    final top = info.latest;
    final live = info.headline != 'Slack';
    return _mod(
      onTap: onTap,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _mh('Slack', icon: 'slack', trailing: top == null ? null : _sub(slackTime(top.ts, now))),
          const SizedBox(height: 6),
          live ? _n('${info.unread}', 64, unit: ' unread') : _n('—', 64),
          const Spacer(),
          if (top != null)
            Row(
              children: [
                _Avatar(top, size: 32),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${top.sender}, ${slackWhere(top)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _tx(13, w: FontWeight.w700, h: 1.25),
                      ),
                      _sub(top.text),
                    ],
                  ),
                ),
              ],
            )
          else if (live || info.detail != '—')
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  live ? info.headline : info.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _tx(13, w: FontWeight.w700, h: 1.25),
                ),
                if (live) _sub(info.detail),
              ],
            ),
        ],
      ),
    );
  }

  Widget _laptop(WidgetRef ref, VoidCallback onTap) {
    final s = topicData<SystemData>(ref, 'system');
    final rows = [
      ('CPU', s?.cpu.pct, _Pat.d2),
      ('GPU', s == null || !s.gpu.available ? null : s.gpu.pct, _Pat.hatch),
      ('RAM', s == null ? null : s.ramUsed / s.ramTotal * 100, _Pat.check),
    ];
    return _mod(
      onTap: onTap,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _mh('Laptop', icon: 'system'),
          const SizedBox(height: 8),
          for (final (i, (l, v, pat)) in rows.indexed) ...[
            if (i > 0) const SizedBox(height: 6),
            Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(l, style: _tx(13, w: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                Expanded(child: _Bar((v ?? 0) / 100, pat: pat, height: 11)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 34,
                  child: Text(
                    v == null ? 'N/A' : '${v.round()}%',
                    textAlign: TextAlign.right,
                    style: _tx(13, w: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _music(BuildContext context, WidgetRef ref, VoidCallback onTap) {
    final m = topicData<MediaData>(ref, 'media');
    final art = topicData<MediaArt>(ref, 'media.art');
    final has = m?.title != null;
    return _mod(
      onTap: onTap,
      pad: const EdgeInsets.fromLTRB(8, 5, 8, 5),
      Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: _frame(_cover(m?.title ?? 'DeskPanel', b64: art?.artId == m?.artId ? art?.b64 : null), radius: 8),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  m?.title ?? 'Nothing playing',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _tx(14, w: FontWeight.w700),
                ),
                _sub(m == null ? 'Laptop not connected' : (m.artist ?? '')),
              ],
            ),
          ),
          if (has) ...[
            const SizedBox(width: 12),
            SizedBox(
              width: 160,
              child: Ticker(
                period: const Duration(seconds: 1),
                builder: (context, now) {
                  final pos = m!.positionNow(now, skewMs: ref.read(agentProvider.notifier).clockSkewMs);
                  final total = m.durationMs ?? 0;
                  return _Bar(total == 0 ? 0 : pos / total, pat: _Pat.d2, height: 9);
                },
              ),
            ),
            const SizedBox(width: 12),
            _round(m!.playing ? 'pause' : 'play', () => act(context, ref, 'media.play_pause'), size: 38, iconSize: 14),
          ],
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
    final seg = _seg(const ['Laptop', 'Internet'], tab, ref.read(systemTabProvider.notifier).set);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head(tab == 0 ? 'System' : 'Internet', seg),
        Expanded(child: tab == 0 ? const _Pc() : const _Internet()),
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
    final f = ref.watch(settingsProvider).fahrenheit;
    final cpuTemp = s.cpu.tempC == null ? '' : ', ${temp(s.cpu.tempC!, f)}°${f ? 'F' : 'C'}';
    final rows = [
      (
        'Graphics',
        g.tempC != null ? '${g.tempC!.round()}°C' : (g.model ?? 'GPU'),
        g.available ? g.pct : null,
        _Pat.hatch,
      ),
      (
        'Memory',
        '${(s.ramUsed / gb).toStringAsFixed(1)} of ${(s.ramTotal / gb).round()} GB',
        s.ramUsed / s.ramTotal * 100,
        _Pat.d2,
      ),
      (
        g.vramLabel == 'VRAM' ? 'Video memory' : g.vramLabel,
        vramPct == null
            ? 'Not available'
            : '${(g.vramUsed! / gb).toStringAsFixed(1)} of ${(g.vramTotal! / gb).round()} GB',
        vramPct,
        _Pat.check,
      ),
    ];
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 85,
                child: _blk(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _mh('Processor', blk: true),
                      const SizedBox(height: 8),
                      _n('${s.cpu.pct.round()}', 124, unit: '%', c: _paper),
                      const SizedBox(height: 4),
                      _sub(
                        '${s.cpu.cores != null ? '${s.cpu.cores} cores, ${s.cpu.threads ?? s.cpu.cores} threads' : s.cpu.model}'
                        '$cpuTemp',
                        blk: true,
                      ),
                      const SizedBox(height: 10),
                      _Bar(s.cpu.pct / 100, blk: true),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: _gap),
              Expanded(
                flex: 150,
                child: _mod(
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final (i, (l, sub, v, pat)) in rows.indexed) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 108,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: _tx(13.5, w: FontWeight.w700),
                                    ),
                                    _sub(sub),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(width: 70, child: v == null ? _n('N/A', 46) : _n('${v.round()}', 46, unit: '%')),
                              const SizedBox(width: 12),
                              Expanded(child: _Bar((v ?? 0) / 100, pat: pat)),
                            ],
                          ),
                        ),
                        if (i < rows.length - 1) _rule,
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: _gap),
        Expanded(
          child: _mod(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Last minute', style: _tx(12, w: FontWeight.w700)),
                    const SizedBox(width: 16),
                    _legend('CPU'),
                    const SizedBox(width: 8),
                    if (g.available) _legend('GPU', dashed: true),
                    const Spacer(),
                    Text('$down $downU down, $up $upU up', style: _tx(12, w: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _StepChart(
                      main: s.cpuHistory,
                      dashed: g.available ? s.gpuHistory : null,
                      hi: 100,
                      fill: _Pat.sparse,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(child: _sub('${s.cpu.model}${g.model != null ? ' with ${g.model}' : ''}')),
                    _sub('Disk ${s.diskPct.round()}% used'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Internet extends ConsumerWidget {
  const _Internet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = topicData<NetworkData>(ref, 'network');
    final live = ref.watch(agentProvider).live;
    if (n == null) return _mod(Center(child: _sub('Waiting for network data…', size: 14)));
    final sys = topicData<SystemData>(ref, 'system');
    final st = n.speedtest, last = st.last, prog = st.progress;
    final dl = st.running ? prog?.downBps : last?.downBps;
    final ul = st.running ? prog?.upBps : last?.upBps;
    return Ticker(
      builder: (context, now) => Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 85,
                  child: _blk(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _mh('Latency', blk: true),
                        const SizedBox(height: 6),
                        n.latencyMs == null
                            ? _n('Timeout', 60, c: _paper)
                            : _n(n.latencyMs!.round().toString(), 96, unit: 'ms', c: _paper),
                        const SizedBox(height: 4),
                        _sub(
                          'Jitter ${n.jitterMs?.toStringAsFixed(1) ?? '—'} ms, ${n.lossPct.round()}% loss',
                          blk: true,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: _gap),
                Expanded(
                  flex: 100,
                  child: _mod(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _mh('Connection'),
                        const SizedBox(height: 8),
                        _n(!live ? 'Unknown' : (n.online ? 'Online' : 'Offline'), 40),
                        const SizedBox(height: 6),
                        _sub(
                          '${n.onlineSince != null ? 'Up ${durLong(now.difference(n.onlineSince!))}.' : ''}'
                          '${n.lastDrop != null ? ' Last drop ${ago(now.difference(n.lastDrop!))}.' : ''}',
                          lines: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: _gap),
                Expanded(
                  flex: 100,
                  child: _mod(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _mh('Data used'),
                        const SizedBox(height: 6),
                        _kv('Today', bytes(n.usageToday)),
                        _kv('This month', bytes(n.usageMonth, digits: 0), last: true),
                      ],
                    ),
                  ),
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
                  flex: 150,
                  child: _mod(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _mh('Latency, last 2 minutes', trailing: _sub('0 to 50 ms')),
                        const SizedBox(height: 6),
                        Expanded(
                          child: CustomPaint(
                            size: Size.infinite,
                            painter: _StepChart(main: n.latencyHistory, hi: 50, fill: _Pat.dots, width: 2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (sys != null) ...[const SizedBox(width: _gap), Expanded(flex: 100, child: _MacNet(sys))],
              ],
            ),
          ),
          const SizedBox(height: _gap),
          _mod(
            pad: const EdgeInsets.fromLTRB(12, 7, 7, 7),
            Column(
              children: [
                Row(
                  children: [
                    Text('Speed test', style: _tx(12, w: FontWeight.w700)),
                    const SizedBox(width: 22),
                    _n(dl == null ? '—' : mbps(dl), 34, unit: 'down', fit: false),
                    const SizedBox(width: 22),
                    _n(ul == null ? '—' : mbps(ul), 34, unit: 'up', fit: false),
                    const SizedBox(width: 22),
                    Expanded(
                      child: _sub(
                        st.running
                            ? 'Testing now'
                            : last == null
                            ? 'Never tested'
                            : 'Tested ${ago(now.difference(last.at))}, ping ${last.pingMs.round()} ms',
                        lines: 2,
                      ),
                    ),
                    _btn(
                      st.running ? 'Testing…' : 'Run test',
                      st.running
                          ? null
                          : () => act(context, ref, 'speedtest.run', const {}, null, null, const Duration(seconds: 90)),
                      inv: true,
                    ),
                  ],
                ),
                if (st.running) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: _Bar((prog?.pct ?? 0) / 100, pat: _Pat.d2, height: 10),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What the Mac is moving right now: down / up rates and the last minute as a step chart
/// (down solid over dots, up dashed), on the same scale.
class _MacNet extends StatelessWidget {
  const _MacNet(this.s);
  final SystemData s;

  @override
  Widget build(BuildContext context) {
    final (down, downU) = rate(s.downBps);
    final (up, upU) = rate(s.upBps);
    final hi = maxOf([...s.downHistory, ...s.upHistory, s.downBps, s.upBps], floor: 64 * 1024) * 1.12;
    return _mod(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _mh(
            'This Mac now',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [_legend('Down'), const SizedBox(width: 8), _legend('Up', dashed: true)],
            ),
          ),
          const SizedBox(height: 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                _n(down, 32, unit: '$downU down', fit: false),
                const SizedBox(width: 16),
                _n(up, 32, unit: '$upU up', fit: false),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: s.downHistory.length < 2
                ? Center(child: _sub('Collecting the last minute…'))
                : CustomPaint(
                    size: Size.infinite,
                    painter: _StepChart(main: s.downHistory, dashed: s.upHistory, hi: hi, fill: _Pat.sparse, width: 2),
                  ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ Claude

class _Claude extends ConsumerWidget {
  const _Claude();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = topicData<ClaudeData>(ref, 'claude')!;
    final h24 = ref.watch(settingsProvider.select((s) => s.clock24));
    final peak = maxOf(c.days.map((d) => d.tokens));
    final top = maxOf(c.modelsToday.map((m) => m.tokens));
    return Ticker(
      builder: (context, now) {
        final five = limitPct(c.fiveHour, now), week = limitPct(c.sevenDay, now);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _head('Claude usage', _sub('Peak ${compact(peak)} tokens this week', size: 12.5)),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _blk(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _mh('5-hour limit', blk: true),
                          const SizedBox(height: 6),
                          c.fiveHour == null
                              ? _n('—', 100, c: _paper)
                              : _n('${five.round()}', 100, unit: '%', c: _paper),
                          const SizedBox(height: 8),
                          _Bar(five / 100, blk: true),
                          const SizedBox(height: 8),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: c.fiveHour == null ? 'No data yet' : 'Resets in '),
                                if (c.fiveHour != null)
                                  TextSpan(
                                    text: resetsIn(c.fiveHour, now).replaceFirst('Resets in ', ''),
                                    style: _tx(12, w: FontWeight.w700, c: _paper.withValues(alpha: .75)),
                                  ),
                              ],
                            ),
                            style: _subS(blk: true),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: _gap),
                  Expanded(
                    child: _mod(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _mh('Weekly limit'),
                          const SizedBox(height: 6),
                          c.sevenDay == null ? _n('—', 100) : _n('${week.round()}', 100, unit: '%'),
                          const SizedBox(height: 8),
                          _Bar(week / 100, pat: _Pat.hatch),
                          const SizedBox(height: 8),
                          _sub(resetsAt(c.sevenDay, now, h24: h24)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: _gap),
                  Expanded(
                    child: _mod(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _mh('Today'),
                          const SizedBox(height: 4),
                          _kv('Tokens', compact(c.tokens)),
                          _kv('Output', compact(c.outputTokens)),
                          _kv('Messages', '${c.messages}'),
                          _kv('Last hour', compact(c.lastHourTokens), last: true),
                        ],
                      ),
                    ),
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
                    flex: 2 * 1000 + 30,
                    child: _mod(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _mh('Tokens, last 7 days'),
                          const SizedBox(height: 6),
                          Expanded(
                            child: BarTapTip(
                              count: c.days.length,
                              label: (i) => dayTokensLabel(c.days[i], now),
                              child: _Cols(
                                gap: 8,
                                items: [
                                  for (final (i, d) in c.days.indexed)
                                    _Col(
                                      label: dayLabel(d.date, now),
                                      bars: [
                                        (
                                          d.tokens / peak,
                                          i == c.days.length - 1
                                              ? _Pat.solid
                                              : (d.tokens / peak < .2 ? _Pat.paper : _Pat.d1),
                                          40.0,
                                          2.0,
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: _gap),
                  Expanded(
                    flex: 1000,
                    child: _mod(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _mh('Models today'),
                          const SizedBox(height: 6),
                          if (c.modelsToday.isEmpty) _sub('No messages yet today'),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                for (final (i, m) in c.modelsToday.take(3).indexed)
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(modelName(m.family), style: _tx(13, w: FontWeight.w700)),
                                          ),
                                          Text(compact(m.tokens), style: _tx(13, w: FontWeight.w700)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      _Bar(m.tokens / top, pat: const [_Pat.solid, _Pat.d2, _Pat.hatch][i]),
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
      },
    );
  }
}

/// One column of `.cols`: bars (value 0..1, fill, max width, border) and a label.
class _Col {
  const _Col({required this.label, required this.bars});
  final String label;
  final List<(double, _Pat, double, double)> bars;
}

/// `.cols`: bottom-aligned pattern bars with labels. A bar is `v%` of the column height,
/// shrunk to fit above its label (CSS flex-shrink), never under 6 px.
class _Cols extends StatelessWidget {
  const _Cols({required this.items, this.gap = 8});
  final List<_Col> items;
  final double gap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      const labelH = 16.0;
      final full = c.maxHeight;
      final room = math.max(6.0, full - labelH - 4);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, it) in items.indexed) ...[
            if (i > 0) SizedBox(width: gap),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final (j, (v, pat, maxW, bw)) in it.bars.indexed) ...[
                        if (j > 0) const SizedBox(width: 2),
                        Flexible(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: maxW),
                            child: SizedBox(
                              width: double.infinity,
                              height: math.max(6, math.min(room, full * v.clamp(0.0, 1.0))),
                              child: CustomPaint(
                                painter: _PatBox(
                                  pat,
                                  bw: bw,
                                  radius: const BorderRadius.vertical(
                                    top: Radius.circular(6),
                                    bottom: Radius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: labelH,
                    child: Text(it.label, maxLines: 1, style: _tx(11.5, w: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
}

// ------------------------------------------------------------------ Calendar

class _Calendar extends ConsumerWidget {
  const _Calendar();

  static String _len(Duration d) {
    final m = d.inMinutes;
    if (m < 60) return '$m min';
    if (m % 60 == 0) return m == 60 ? '1 hour' : '${m ~/ 60} hours';
    return '${m ~/ 60} h ${m % 60} min';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(calendarEventsProvider);
    final h24 = ref.watch(settingsProvider.select((s) => s.clock24));
    return Ticker(
      builder: (context, now) {
        final split = splitEvents(events, now);
        final n = nextEvent(events, now);
        final timed = split.today.where((e) => !e.allDay).toList();
        final free = timed.isEmpty
            ? 'Nothing on the calendar today.'
            : 'Free after ${_time(timed.map((e) => e.end).reduce((a, b) => a.isAfter(b) ? a : b), h24)}.';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _head(
              'Today',
              Text(
                longDate(now),
                style: _tx(13, w: FontWeight.w700, c: _ink2),
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 150,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final (i, e) in split.today.indexed) ...[
                                  if (i > 0) const SizedBox(height: 7),
                                  _event(e, now, e == n, h24),
                                ],
                              ],
                            ),
                          ),
                        ),
                        _sub(free),
                      ],
                    ),
                  ),
                  const SizedBox(width: _gap),
                  Expanded(
                    flex: 100,
                    child: _mod(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _mh('Later this week'),
                          if (split.later.isEmpty) ...[const SizedBox(height: 8), _sub('Nothing in the next 7 days')],
                          for (final (i, e) in split.later.take(5).indexed)
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              e.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: _bri(14, wdth: 80, h: 1.1, ls: 0),
                                            ),
                                            _sub(e.location ?? e.calendar ?? ''),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(weekday(e.start), style: _tx(13, w: FontWeight.w700)),
                                          Text(
                                            e.allDay ? 'All day' : _time(e.start, h24),
                                            style: _tx(12, w: FontWeight.w700, c: _ink2),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (i < math.min(split.later.length, 5) - 1) _rule,
                              ],
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

  Widget _event(CalEvent e, DateTime now, bool next, bool h24) {
    final past = !next && e.end.isBefore(now);
    final fg = next ? _paper : (past ? _ink3 : _ink);
    final mu = next ? _paper.withValues(alpha: .78) : (past ? _ink3 : _ink2);
    final row = Row(
      children: [
        SizedBox(
          width: 72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                e.allDay ? 'All day' : clock(e.start, h24: h24),
                style: _bri(19, wdth: 78, h: 1, ls: 0, c: fg),
              ),
              const SizedBox(height: 3),
              Text(
                [if (!e.allDay && !h24) ampm(e.start), if (!e.allDay) _len(e.end.difference(e.start))].join(', '),
                maxLines: 1,
                style: _tx(11, w: FontWeight.w700, c: mu, h: 1.2),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                e.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _tx(15, w: FontWeight.w700, c: fg),
              ),
              Text(
                [
                  e.location,
                  if (e.calendar != null) '${e.calendar!.toLowerCase()} calendar',
                ].whereType<String>().join(', '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _tx(12, c: mu),
              ),
            ],
          ),
        ),
        if (next) ...[const SizedBox(width: 12), _n(_inText(e, now), 24, c: _paper, fit: false)],
      ],
    );
    const pad = EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    if (past) {
      return CustomPaint(
        painter: _Dashed(),
        child: Padding(padding: pad, child: row),
      );
    }
    return Container(
      padding: pad,
      decoration: BoxDecoration(
        color: next ? _ink : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _ink, width: 2),
      ),
      child: row,
    );
  }
}

/// 2 px dashed rounded outline (`.ev.past`).
class _Dashed extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius((Offset.zero & size).deflate(1), const Radius.circular(11));
    final path = Path()..addRRect(rr);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = _ink;
    for (final m in path.computeMetrics()) {
      for (var t = 0.0; t < m.length; t += 10) {
        canvas.drawPath(m.extractPath(t, math.min(t + 6, m.length)), p);
      }
    }
  }

  @override
  bool shouldRepaint(_Dashed o) => false;
}

// ------------------------------------------------------------------ Weather

class _Weather extends ConsumerWidget {
  const _Weather();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(weatherProvider);
    final s = ref.watch(settingsProvider);
    if (w == null) {
      return _mod(Center(child: _sub('Set your location in Settings, then Weather', size: 14)));
    }
    final f = s.fahrenheit;
    final lo = w.days.isEmpty ? 0.0 : w.days.map((d) => d.loC).reduce(math.min);
    final hi = w.days.isEmpty ? 1.0 : w.days.map((d) => d.hiC).reduce(math.max);
    final span = math.max(1e-6, hi - lo);
    String hourLabel(int i, DateTime t) =>
        i == 0 ? 'Now' : (s.clock24 ? '${two(t.hour)}:00' : '${t.hour % 12 == 0 ? 12 : t.hour % 12} ${ampm(t)}');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head(w.place, _sub('Updated ${_time(w.now.updated, s.clock24)}', size: 12.5)),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 80,
                child: _blk(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _mh(w.now.condition, icon: w.now.icon, blk: true),
                      const SizedBox(height: 8),
                      _n('${temp(w.now.tempC, f)}°', 116, c: _paper),
                      const SizedBox(height: 6),
                      _sub(
                        'Feels like ${temp(w.now.feelsC, f)}°\nHumidity ${w.now.humidity}%, wind ${wind(w.now.windKmh, f)}',
                        blk: true,
                        lines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: _gap),
              Expanded(
                flex: 200,
                child: _mod(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _mh('Next 12 hours'),
                      const Spacer(),
                      Row(
                        children: [
                          for (final (i, h) in w.hours.take(12).indexed)
                            Expanded(
                              child: Column(
                                children: [
                                  Text(hourLabel(i, h.time), maxLines: 1, style: _tx(11, w: FontWeight.w700)),
                                  const SizedBox(height: 5),
                                  DpIcon(h.icon, size: 19, color: _ink, stroke: 2),
                                  const SizedBox(height: 5),
                                  Text('${temp(h.tempC, f)}°', style: _bri(17, wdth: 80, h: 1.2, ls: 0)),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: _gap),
        Expanded(
          child: _mod(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _mh('This week'),
                const SizedBox(height: 4),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final (i, d) in w.days.indexed)
                        Row(
                          children: [
                            SizedBox(
                              width: 48,
                              child: Text(i == 0 ? 'Today' : weekday3(d.date), style: _tx(13, w: FontWeight.w700)),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(width: 22, child: DpIcon(d.icon, size: 17, color: _ink, stroke: 2)),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 38,
                              child: Text(
                                d.precipPct > 0 ? '${d.precipPct}%' : '',
                                style: _tx(12, w: FontWeight.w700, c: _ink2),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 30,
                              child: Text(
                                '${temp(d.loC, f)}°',
                                textAlign: TextAlign.right,
                                style: _tx(13, w: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SizedBox(
                                height: 11,
                                child: CustomPaint(painter: _Range((d.loC - lo) / span, (d.hiC - lo) / span)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 30,
                              child: Text('${temp(d.hiC, f)}°', style: _tx(13, w: FontWeight.w700)),
                            ),
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
    );
  }
}

/// `.rng`: outlined pill with a hatched lo..hi span.
class _Range extends CustomPainter {
  _Range(this.a, this.b);
  final double a, b;
  @override
  void paint(Canvas canvas, Size size) {
    final outer = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.height / 2));
    final inner = outer.deflate(2);
    canvas.drawRRect(outer, Paint()..color = _ink);
    canvas.drawRRect(inner, Paint()..color = _paper);
    canvas.save();
    canvas.clipRRect(inner);
    final r = Rect.fromLTRB(inner.left + inner.width * a, inner.top, inner.left + inner.width * b, inner.bottom);
    _fill(canvas, r, _Pat.hatch);
    final e = Paint()..color = _ink;
    canvas.drawRect(Rect.fromLTWH(r.left, r.top, 2, r.height), e);
    canvas.drawRect(Rect.fromLTWH(r.right - 2, r.top, 2, r.height), e);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Range o) => o.a != a || o.b != b;
}

// ------------------------------------------------------------------ Music

class _Music extends ConsumerWidget {
  const _Music();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = topicData<MediaData>(ref, 'media')!;
    final art = topicData<MediaArt>(ref, 'media.art');
    final skew = ref.read(agentProvider.notifier).clockSkewMs;
    return Row(
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final side = math.min(c.maxHeight, 360.0);
            return SizedBox(
              width: side,
              height: side,
              child: _frame(_cover(m.title ?? 'Nothing playing', b64: art?.artId == m.artId ? art?.b64 : null)),
            );
          },
        ),
        const SizedBox(width: 26),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _tag(m.source ?? 'Laptop'),
              const SizedBox(height: 12),
              Text(m.title ?? 'Nothing playing', maxLines: 2, overflow: TextOverflow.ellipsis, style: _bri(44, h: .95)),
              const SizedBox(height: 6),
              if (m.artist != null)
                Text(
                  m.artist!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _tx(16, w: FontWeight.w700),
                ),
              if (m.album != null) _sub(m.album!),
              const SizedBox(height: 16),
              // Transport on the left, the turntable beside it (as big as the height allows).
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 176),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Ticker(
                              period: const Duration(seconds: 1),
                              builder: (context, now) {
                                final pos = m.positionNow(now, skewMs: skew);
                                final total = m.durationMs ?? 0;
                                return Column(
                                  children: [
                                    _InkSeek(
                                      value: total == 0 ? 0 : pos / total,
                                      enabled: m.canSeek && total > 0,
                                      onSeek: (f) =>
                                          act(context, ref, 'media.seek', {'position_ms': (f * total).round()}),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(mmss(pos), style: _tx(12, w: FontWeight.w700)),
                                        const Spacer(),
                                        Text(total == 0 ? '' : mmss(total), style: _tx(12, w: FontWeight.w700)),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                _round('prev', () => act(context, ref, 'media.prev')),
                                const SizedBox(width: 16),
                                _round(
                                  m.playing ? 'pause' : 'play',
                                  () => act(context, ref, 'media.play_pause'),
                                  inv: true,
                                  size: 62,
                                ),
                                const SizedBox(width: 16),
                                _round('next', () => act(context, ref, 'media.next')),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 18),
                      AspectRatio(aspectRatio: 1, child: _Vinyl(playing: m.playing)),
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

/// The record on the deck, in ink line-art: grooves as thin rings, a hatched label with a
/// solid mark, a tonearm. While music plays it turns in coarse steps (one e-paper refresh
/// every 0.6 s, the last mark position left as a faint ghost); paused, it stands still
/// with the arm back on its rest. The timer runs only while playing and on screen.
class _Vinyl extends StatefulWidget {
  const _Vinyl({required this.playing});
  final bool playing;
  @override
  State<_Vinyl> createState() => _VinylState();
}

class _VinylState extends State<_Vinyl> {
  static const _refresh = Duration(milliseconds: 600);
  Timer? _timer;
  int _step = 0;
  bool _onScreen = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Off while another route covers the page (the same switch that pauses Tickers).
    _onScreen = TickerMode.valuesOf(context).enabled;
    _sync();
  }

  @override
  void didUpdateWidget(_Vinyl old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final run = widget.playing && _onScreen;
    if (run && _timer == null) {
      _timer = Timer.periodic(_refresh, (_) => setState(() => _step++));
    } else if (!run && _timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(painter: _VinylPainter(_step, widget.playing), size: Size.infinite),
  );
}

class _VinylPainter extends CustomPainter {
  _VinylPainter(this.step, this.playing);
  final int step;
  final bool playing;

  /// Degrees per refresh: 9 positions per turn, so each step reads as a clear jump.
  static const _deg = 40.0;

  @override
  void paint(Canvas canvas, Size size) {
    // Laid out in a 100×100 box, drawn at pixel scale so strokes and patterns stay crisp.
    final k = math.min(size.width, size.height) / 100;
    final o = Offset((size.width - 100 * k) / 2, (size.height - 100 * k) / 2);
    Offset p(double x, double y) => o + Offset(x * k, y * k);
    final c = p(42, 56);
    final r = 41 * k;
    Paint stroke(double w, [Color col = _ink]) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..color = col;

    // Disc: paper, a firm rim, grooves as thin rings with blank bands between tracks.
    canvas.drawCircle(c, r, Paint()..color = _paper);
    final groove = stroke(.7, _ink2);
    const gaps = [(24.2, 26.0), (31.0, 32.8)];
    for (var g = 17.6; g < 39.6; g += 1.55) {
      if (gaps.any((b) => g > b.$1 && g < b.$2)) continue;
      canvas.drawCircle(c, g * k, groove);
    }
    canvas.drawCircle(c, r - 1, stroke(2));
    canvas.drawCircle(c, 38.6 * k, stroke(1.2));

    // Label (turns with the record): hatched, with a solid mark and the spindle.
    final lr = 15 * k;
    final a = step * _deg * math.pi / 180;
    void mark(Paint paint, double angle) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(angle);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTRB(-2.7 * k, -14 * k, 2.7 * k, -6.2 * k), Radius.circular(1 * k)),
        paint,
      );
      canvas.restore();
    }

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(a);
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: lr)));
    canvas.drawCircle(Offset.zero, lr, Paint()..color = _paper);
    _fillRaw(canvas, Rect.fromCircle(center: Offset.zero, radius: lr), _Pat.hatch, _ink);
    canvas.restore();
    canvas.restore();
    // E-ink ghosting: the previous position lingers faintly until the next refresh.
    if (playing && step > 0) mark(Paint()..color = _ink3, a - _deg * math.pi / 180);
    mark(Paint()..color = _ink, a);
    canvas.drawCircle(c, lr, stroke(2));
    canvas.drawCircle(c, 4.2 * k, Paint()..color = _ink);
    canvas.drawCircle(c, 1.5 * k, Paint()..color = _paper);

    // Tonearm: pivot top right; on the record while playing, back on its rest when paused.
    final pv = p(88, 13);
    // The rest: a small cradle the arm lies across when lifted.
    canvas.drawPath(
      Path()
        ..moveTo(p(84, 60).dx, p(84, 60).dy)
        ..lineTo(p(84, 63).dx, p(84, 63).dy)
        ..lineTo(p(92, 63).dx, p(92, 63).dy)
        ..lineTo(p(92, 60).dx, p(92, 60).dy),
      stroke(2)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final ang = (playing ? 112.0 : 90.0) * math.pi / 180;
    final dir = Offset(math.cos(ang), math.sin(ang));
    final len = 60 * k;
    final tip = pv + dir * len;
    // Counterweight behind the pivot.
    canvas.save();
    canvas.translate(pv.dx - dir.dx * 11 * k, pv.dy - dir.dy * 11 * k);
    canvas.rotate(ang);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 7 * k, height: 8 * k),
        Radius.circular(1.5 * k),
      ),
      Paint()..color = _ink,
    );
    canvas.restore();
    // Arm tube, then the headshell set at an angle at its end.
    canvas.drawLine(
      pv - dir * 7 * k,
      tip - dir * 4 * k,
      Paint()
        ..color = _ink
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    canvas.rotate(ang + .42);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(-5 * k, -2.6 * k, 9 * k, 5.2 * k), Radius.circular(1 * k)),
      Paint()..color = _ink,
    );
    canvas.restore();
    // Pivot on top.
    canvas.drawCircle(pv, 6.5 * k, Paint()..color = _paper);
    canvas.drawCircle(pv, 6.5 * k, stroke(2));
    canvas.drawCircle(pv, 2.4 * k, Paint()..color = _ink);
  }

  @override
  bool shouldRepaint(_VinylPainter o) => o.step != step || o.playing != playing;
}

/// Tap / drag the dotted bar to seek; one seek is sent on release.
class _InkSeek extends StatefulWidget {
  const _InkSeek({required this.value, required this.onSeek, required this.enabled});
  final double value;
  final bool enabled;
  final ValueChanged<double> onSeek;
  @override
  State<_InkSeek> createState() => _InkSeekState();
}

class _InkSeekState extends State<_InkSeek> {
  double? _drag;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      double f(Offset p) => (p.dx / c.maxWidth).clamp(0.0, 1.0);
      final on = widget.enabled;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: on ? (d) => widget.onSeek(f(d.localPosition)) : null,
        onHorizontalDragStart: on ? (d) => setState(() => _drag = f(d.localPosition)) : null,
        onHorizontalDragUpdate: on ? (d) => setState(() => _drag = f(d.localPosition)) : null,
        onHorizontalDragEnd: on
            ? (_) {
                widget.onSeek(_drag!);
                setState(() => _drag = null);
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: _Bar(_drag ?? widget.value, pat: _Pat.d2),
        ),
      );
    },
  );
}

// ------------------------------------------------------------------ Hotspot

/// "37.5 °C" -> ("37.5", "°C").
(String, String?) _hsTempParts(double? c, bool f) {
  final s = hsTemp(c, fahrenheit: f).split(' ');
  return (s.first, s.length > 1 ? s[1] : null);
}

/// The Hotspot Monitor Overview (the roof phone sharing mobile data). No colour here:
/// trouble turns a module into a solid ink block, a warning gets a black tag.
class _Hotspot extends ConsumerWidget {
  const _Hotspot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = topicData<HotspotData>(ref, 'hotspot')!;
    final f = ref.watch(settingsProvider).fahrenheit;
    return Ticker(
      builder: (context, now) {
        final alert = hsAlert(d, now);
        final note = hsSessionNote(d, now);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The alert (if any) sits in the heading as a black pill; otherwise name + state.
            Padding(
              padding: const EdgeInsets.only(bottom: _gap),
              child: Row(
                children: [
                  const SizedBox(height: 30),
                  Text('Hotspot', maxLines: 1, style: _bri(25, wdth: 80, opsz: 48, h: 1, ls: -.02)),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: alert == null
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (d.name case final name?) ...[_sub(name, size: 12.5), const SizedBox(width: 12)],
                                _tag(hsStateLabel(d)),
                              ],
                            )
                          : Container(
                              height: 30,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(99)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const DpIcon('hotspot', size: 15, color: _paper, stroke: 2.2),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      alert,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: _tx(13.5, w: FontWeight.w700, c: _paper, h: 1.2),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final roomy = c.maxHeight >= 300;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(flex: 96, child: _status(d, now)),
                            const SizedBox(width: _gap),
                            Expanded(flex: 106, child: _signal(d)),
                            const SizedBox(width: _gap),
                            Expanded(flex: 90, child: _speed(d)),
                          ],
                        ),
                      ),
                      const SizedBox(height: _gap),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _battery(d, roomy)),
                            const SizedBox(width: _gap),
                            Expanded(child: _temp(d, f, roomy)),
                            const SizedBox(width: _gap),
                            Expanded(child: _data(d, roomy)),
                            const SizedBox(width: _gap),
                            Expanded(child: _uptime(d, roomy)),
                          ],
                        ),
                      ),
                      const SizedBox(height: _gap),
                      Expanded(child: _events(d, now, note)),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// An outlined module, or a solid block when [blk].
  Widget _box(bool blk, Widget child) => blk ? _blk(pad: const EdgeInsets.fromLTRB(12, 9, 12, 9), child) : _mod(child);

  Widget _status(HotspotData d, DateTime now) => _mod(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _mh('Status', icon: 'hotspot', trailing: _sub(hsSeen(d, now))),
        const SizedBox(height: 8),
        _n(hsStateLabel(d), 40),
        const SizedBox(height: 6),
        _sub([hsNetwork(d), if (d.operator != null) d.operator!].join(' · '), size: 13),
        _sub(hsSharing(d), size: 13),
      ],
    ),
  );

  Widget _signal(HotspotData d) => _blk(
    pad: const EdgeInsets.fromLTRB(12, 9, 12, 9),
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _mh(
          'Signal score',
          blk: true,
          trailing: Text(
            hsGradeLabel(d.grade),
            style: _tx(13, w: FontWeight.w700, c: _paper, h: 1),
          ),
        ),
        const SizedBox(height: 4),
        _n(d.score == null ? '—' : '${d.score!.round()}', 46, unit: '/100', c: _paper),
        const SizedBox(height: 6),
        _Bar((d.score ?? 0) / 100, blk: true, height: 12),
        const Spacer(),
        const SizedBox(height: 6),
        _sub(hsSignalLine(d), blk: true, size: 11),
      ],
    ),
  );

  Widget _speed(HotspotData d) {
    final (dn, dnU) = hsBpsParts(d.rxBps);
    final (up, upU) = hsBpsParts(d.txBps);
    return _mod(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _mh('Speed now'),
          const SizedBox(height: 6),
          _n(dn, 36, unit: '$dnU down', unitK: .42),
          const SizedBox(height: 4),
          _n(up, 26, unit: '$upU up', unitK: .5),
          const Spacer(),
          const SizedBox(height: 6),
          _sub(hsPingLine(d), size: 11),
        ],
      ),
    );
  }

  /// One of the four small modules: heading (+ tag), number, a line or bar, small print.
  Widget _small(
    String title, {
    required bool blk,
    String? tag,
    required Widget number,
    Widget? bar,
    required String line,
    String? badge,
    String? small,
  }) => _box(
    blk,
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _mh(
          title,
          blk: blk,
          trailing: tag == null
              ? null
              : blk
              ? Text(
                  tag,
                  maxLines: 1,
                  style: _tx(12, w: FontWeight.w700, c: _paper, h: 1),
                )
              : _tag(tag),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(child: number),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: badge != null
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: _on(blk), borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        badge,
                        maxLines: 1,
                        style: _tx(12, w: FontWeight.w700, c: _on(!blk)),
                      ),
                    )
                  : Text(
                      line,
                      maxLines: 1,
                      style: _subS(blk: blk, size: 12.5, w: FontWeight.w700),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (bar != null) ...[bar, const SizedBox(height: 5)],
        if (small != null) _sub(small, blk: blk, size: 11.5, lines: bar == null ? 2 : 1),
      ],
    ),
  );

  Widget _battery(HotspotData d, bool roomy) {
    final blk = d.lowBattery;
    return _small(
      'Battery',
      blk: blk,
      tag: blk ? 'Low' : null,
      number: _n(d.batteryPct == null ? '—' : '${d.batteryPct!.round()}', 34, unit: '%', c: _on(blk)),
      line: hsCurrent(d.currentMa),
      small: roomy ? hsPowerLine(d) : null,
    );
  }

  Widget _temp(HotspotData d, bool f, bool roomy) {
    final hot = d.heat == HotspotHeat.hot;
    final (v, u) = _hsTempParts(d.batteryC, f);
    return _small(
      'Temperature',
      blk: hot,
      tag: hot ? 'Hot' : (d.heat == HotspotHeat.warm ? 'Warm' : null),
      badge: d.radioResting ? 'Radio resting' : null,
      number: _n(v, 34, unit: u, c: _on(hot)),
      line: 'Battery',
      small: roomy ? hsHeatLine(d, fahrenheit: f) : null,
    );
  }

  Widget _data(HotspotData d, bool roomy) {
    final q = d.quotaFrac;
    final full = q != null && q >= 1;
    final (v, u) = hsBytesParts(d.cycleUsed);
    return _small(
      'Data this cycle',
      blk: full,
      tag: q == null ? null : '${(q * 100).round()}%',
      number: _n(v, 34, unit: u, c: _on(full)),
      bar: q == null ? null : _Bar(q, pat: q >= .8 ? _Pat.check : _Pat.hatch, height: 10, blk: full),
      line: q == null ? 'No quota' : 'of ${hsBytes(d.quota)}',
      small: roomy ? hsTodayLine(d) : null,
    );
  }

  Widget _uptime(HotspotData d, bool roomy) => _small(
    'Uptime',
    blk: false,
    number: _n(hsUptime(d.uptimeS), 34),
    line: 'Agent ${hsUptime(d.agentUptimeS)}',
    small: roomy ? hsBootLine(d) : null,
  );

  Widget _events(HotspotData d, DateTime now, String? note) {
    final foot = [?note, ?d.model].join(' · ');
    return _mod(
      pad: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _mh('Latest events', icon: 'clock', trailing: foot.isEmpty ? null : _sub(foot)),
          const SizedBox(height: 2),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                const rowH = 22.0;
                final n = math.min(d.events.length, (c.maxHeight / rowH).floor());
                if (d.events.isEmpty) {
                  return Padding(padding: const EdgeInsets.only(top: 4), child: _sub('Nothing has happened lately.'));
                }
                return Column(
                  children: [
                    for (final e in d.events.take(n))
                      SizedBox(
                        height: rowH,
                        child: Row(
                          children: [
                            _mark(e.severity),
                            const SizedBox(width: 9),
                            SizedBox(
                              width: 42,
                              child: Text(
                                slackTime(e.ts, now),
                                maxLines: 1,
                                style: _tx(12, w: FontWeight.w700, c: _ink2),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                e.message,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _tx(
                                  13.5,
                                  w: e.severity == 'info' ? FontWeight.w400 : FontWeight.w700,
                                  c: e.severity == 'info' ? _ink2 : _ink,
                                  h: 1.2,
                                ),
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
        ],
      ),
    );
  }

  /// Severity mark: critical = solid square, warning = hatched square, info = ring.
  Widget _mark(String severity) => SizedBox(
    width: 12,
    height: 12,
    child: switch (severity) {
      'critical' => Container(color: _ink),
      'warning' => CustomPaint(painter: _PatBox(_Pat.hatch, bw: 1.5)),
      _ => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _ink3, width: 1.5),
        ),
      ),
    },
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 170,
              child: _blk(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _mh(st.mode.label, blk: true),
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(digits, maxLines: 1, style: _bri(196, c: _paper)),
                          ),
                        ),
                      ),
                    ),
                    _Bar(st.progress(now), blk: true),
                  ],
                ),
              ),
            ),
            const SizedBox(width: _gap),
            Expanded(
              flex: 100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Timer', style: _bri(25, wdth: 80, opsz: 48, h: 1, ls: -.02)),
                  const SizedBox(height: 10),
                  for (final (i, m) in TimerMode.values.indexed) ...[
                    if (i > 0) const SizedBox(height: 6),
                    _mode(m, st, ctl),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _btn(label, ctl.toggle, inv: true, height: 46)),
                      const SizedBox(width: 8),
                      _btn('Reset', ctl.reset, height: 46),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      for (var i = 0; i < 4; i++)
                        Container(
                          width: 18,
                          height: 18,
                          margin: const EdgeInsets.only(right: 5),
                          decoration: BoxDecoration(
                            color: i < st.sessions ? _ink : null,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: _ink, width: 2),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _sub('${st.sessions} of 4 focus sessions today'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _mode(TimerMode m, TimerState st, TimerNotifier ctl) {
    final on = st.mode == m;
    final adjustable = on && m == TimerMode.countdown && !st.running;
    Widget small(String s, VoidCallback onTap) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 20,
        height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _ink, width: 2),
        ),
        child: Text(s, style: _tx(13, w: FontWeight.w700, h: 1)),
      ),
    );
    final mins = m == TimerMode.stopwatch
        ? 'count up'
        : '${m == TimerMode.countdown ? st.countdownMin : m.defaultMin} min';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => ctl.setMode(m),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _ink, width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on ? _ink : null,
                border: Border.all(color: _ink, width: 2),
              ),
            ),
            const SizedBox(width: 10),
            Text(m.label, style: _tx(13, w: FontWeight.w700)),
            const Spacer(),
            if (adjustable) ...[small('−', () => ctl.adjust(-1)), const SizedBox(width: 6)],
            Text(
              mins,
              style: _tx(12, w: FontWeight.w700, c: _ink2),
            ),
            if (adjustable) ...[const SizedBox(width: 6), small('+', () => ctl.adjust(1))],
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ Slack

/// Monochrome avatar: a ring of dither pattern (one per sender colour) around a disc
/// with initials. Unread = solid ink disc; read = paper disc, grey initials.
class _Avatar extends StatelessWidget {
  const _Avatar(this.m, {this.size = 34, this.blk = false});
  final SlackMsg m;
  final double size;

  /// Drawn on a `.blk` block (paper ring outline, inverted disc).
  final bool blk;

  static const _pats = [_Pat.d2, _Pat.hatch, _Pat.check, _Pat.d1];

  @override
  Widget build(BuildContext context) {
    final solid = m.unread != blk;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _AvatarPainter(_pats[stableHash(m.senderColor) % _pats.length], blk: blk, solid: solid),
        child: Center(
          child: Text(
            m.initials,
            maxLines: 1,
            style: _tx(size * .3, w: FontWeight.w700, h: 1, ls: -.2, c: solid ? _paper : (m.unread ? _ink : _ink2)),
          ),
        ),
      ),
    );
  }
}

class _AvatarPainter extends CustomPainter {
  _AvatarPainter(this.pat, {required this.blk, required this.solid});
  final _Pat pat;
  final bool blk, solid;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final c = r.center, rad = size.shortestSide / 2;
    final ring = blk ? _paper : _ink;
    canvas.save();
    canvas.clipPath(Path()..addOval(r));
    canvas.drawRect(r, Paint()..color = blk ? _ink : _paper);
    _fillRaw(canvas, r, pat, ring);
    canvas.restore();
    final inner = rad * .74;
    canvas.drawCircle(c, inner, Paint()..color = solid ? _ink : _paper);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = ring;
    canvas.drawCircle(c, rad - 1, line);
    canvas.drawCircle(c, inner, line..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(_AvatarPainter o) => o.pat != pat || o.blk != blk || o.solid != solid;
}

/// "From Maya, Jonas and Leo" (first names, unique, newest first).
String _slackFrom(List<SlackMsg> unread) {
  final names = <String>[];
  for (final m in unread) {
    final n = m.sender.split(' ').first;
    if (!names.contains(n)) names.add(n);
  }
  if (names.length > 3) return 'From ${names.take(3).join(', ')} and ${names.length - 3} more';
  if (names.length == 1) return 'From ${names.first}';
  return 'From ${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
}

class _Slack extends ConsumerWidget {
  const _Slack();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = topicData<SlackData>(ref, 'slack')!;
    return Ticker(
      builder: (context, now) => Column(
        children: [
          _head(
            'Slack',
            // Fixed height so the page doesn't shift when the button goes away.
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 30),
                if (s.team != null) _sub(s.team!, size: 12.5),
                if (s.unread > 0) ...[
                  const SizedBox(width: 12),
                  _btn('Mark all read', () => slackReadAll(context, ref), height: 30),
                ],
              ],
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 92, child: _featured(context, ref, s, now)),
                const SizedBox(width: _gap),
                Expanded(flex: 128, child: _list(context, ref, s, now)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Something waiting: a black block with the count, then the newest unread message
  /// under a paper rule. All caught up: the same layout as a calm outlined module.
  Widget _featured(BuildContext context, WidgetRef ref, SlackData s, DateTime now) {
    final top = s.unreadMessages.firstOrNull;
    final blk = top != null;
    final fg = _on(blk);
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _mh(blk ? 'Newest unread' : 'Unread', icon: 'slack', blk: blk),
        const SizedBox(height: 10),
        _n('${s.unread}', 96, unit: 'unread', c: fg),
        if (blk) ...[const SizedBox(height: 8), _sub(_slackFrom(s.unreadMessages), blk: true, lines: 2, size: 13)],
        const Spacer(),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.only(top: 9),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: fg, width: 2)),
          ),
          child: !blk
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('All caught up', style: _tx(15, w: FontWeight.w700)),
                    _sub(s.messages.isEmpty ? 'No recent messages' : 'Nothing new since you last looked'),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _Avatar(top, size: 38, blk: true),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                top.sender,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _tx(15, w: FontWeight.w700, c: _paper, h: 1.2),
                              ),
                              _sub('${slackWhere(top)}, ${slackTime(top.ts, now)}', blk: true),
                            ],
                          ),
                        ),
                        SlackReadTick(top, color: _paper, fill: _paper, onFill: _ink, radius: 0),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      top.text,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: _tx(17, c: _paper, h: 1.3),
                    ),
                  ],
                ),
        ),
      ],
    );
    return blk
        ? _blk(onTap: () => slackOpen(context, ref, top), body)
        : _mod(pad: const EdgeInsets.fromLTRB(15, 11, 15, 11), body);
  }

  Widget _list(BuildContext context, WidgetRef ref, SlackData s, DateTime now) {
    final ms = s.messages;
    return _mod(
      pad: const EdgeInsets.fromLTRB(12, 9, 10, 4),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _mh(
            'Recent, tap to open on laptop',
            trailing: ms.isEmpty ? null : _sub('${ms.length} message${ms.length == 1 ? '' : 's'}'),
          ),
          const SizedBox(height: 3),
          Expanded(
            child: ms.isEmpty
                ? Center(
                    child: _sub(
                      'Nothing here yet. New messages show up as they arrive.',
                      lines: 2,
                      align: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: ms.length,
                    separatorBuilder: (_, _) => _rule,
                    itemBuilder: (context, i) => _row(context, ref, ms[i], now),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, SlackMsg m, DateTime now) {
    final c = m.unread ? _ink : _ink2;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => slackOpen(context, ref, m),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 7, 2, 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Avatar(m),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                                style: _tx(13.5, w: m.unread ? FontWeight.w700 : FontWeight.w400, c: c),
                              ),
                              TextSpan(text: '  ${slackWhere(m)}', style: _subS()),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        slackTime(m.ts, now),
                        style: _tx(12, w: m.unread ? FontWeight.w700 : FontWeight.w400, c: c),
                      ),
                    ],
                  ),
                  Text(
                    m.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _tx(13, c: c, h: 1.3),
                  ),
                ],
              ),
            ),
            // Unread: a tick box that marks it read; read: an empty ring.
            if (m.unread)
              Transform.translate(
                offset: const Offset(6, -6),
                child: SlackReadTick(m, color: _ink, fill: _ink, onFill: _paper, radius: 0),
              )
            else
              // Same 40 px column as the tick so the times line up.
              Transform.translate(
                offset: const Offset(6, -6),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _ink3, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
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
    final topRepo = maxOf(g.topRepos.map((r) => r.count));
    final src = ref.watch(codeSourceProvider);
    return Column(
      children: [
        _head(codeSources[src], _seg(codeSources, src, ref.read(codeSourceProvider.notifier).set)),
        _mod(
          pad: const EdgeInsets.fromLTRB(12, 9, 12, 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _mh(
                'Last year',
                trailing: _sub(
                  '${_thousands(g.total)} contributions, ${g.commits} commits, ${g.private} private, '
                  '${g.issues} issue${g.issues == 1 ? '' : 's'}',
                  align: TextAlign.right,
                ),
              ),
              const SizedBox(height: 3),
              _InkHeat(g.weeks),
            ],
          ),
        ),
        const SizedBox(height: _gap),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 80,
                child: _blk(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _mh('Streak', blk: true),
                      const SizedBox(height: 4),
                      _n('${g.streakCurrent}', 116, unit: g.streakCurrent == 1 ? 'day' : 'days', c: _paper),
                      const Spacer(),
                      _sub(
                        'Longest ${g.streakLongest} days.'
                        '${g.bestDay == null ? '' : ' Best day ${g.bestDay!.count} on ${month3(g.bestDay!.date)} ${g.bestDay!.date.day}.'}',
                        blk: true,
                        lines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: _gap),
              Expanded(
                flex: 100,
                child: _mod(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _mh(
                        'This week',
                        trailing: Text(
                          '${g.weekTotal}, ${g.weekDelta >= 0 ? 'up' : 'down'} ${g.weekDelta.abs()}',
                          style: _tx(12, w: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: _Cols(
                          gap: 4,
                          items: [
                            for (var i = 0; i < 7; i++)
                              _Col(
                                label: 'SMTWTFS'[i],
                                bars: [
                                  ((i < g.lastWeek.length ? g.lastWeek[i] : 0) / mx, _Pat.paper, 10.0, 1.5),
                                  (
                                    ((i < g.thisWeek.length ? g.thisWeek[i] : null) ?? 0) / mx,
                                    i == today ? _Pat.solid : _Pat.d2,
                                    14.0,
                                    2.0,
                                  ),
                                ],
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
                child: _mod(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _mh(topReposLabel(ref)),
                      const SizedBox(height: 5),
                      for (final (i, r) in g.topRepos.take(4).indexed) ...[
                        if (i > 0) const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                r.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _tx(13, w: FontWeight.w700),
                              ),
                            ),
                            Text('${r.count}', style: _tx(13, w: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 3),
                        _Bar(
                          r.count / topRepo,
                          pat: const [_Pat.solid, _Pat.check, _Pat.d2, _Pat.hatch][i],
                          height: 10,
                        ),
                      ],
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

/// Contribution calendar: empty days are faint specks, others pattern-filled squares
/// (sparse dots, hatch, checker, solid) by level.
class _InkHeat extends StatelessWidget {
  const _InkHeat(this.weeks);
  final List<List<ContribDay>> weeks;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final cw = (c.maxWidth - 26) / 53;
      return SizedBox(
        width: c.maxWidth,
        height: 13 + 7 * cw,
        child: CustomPaint(painter: _HeatPainter(weeks)),
      );
    },
  );
}

class _HeatPainter extends CustomPainter {
  _HeatPainter(this.weeks);
  final List<List<ContribDay>> weeks;

  @override
  void paint(Canvas canvas, Size size) {
    const lw = 26.0, top = 13.0;
    final ws = weeks.length > 53 ? weeks.sublist(weeks.length - 53) : weeks;
    final cw = (size.width - lw) / 53, cs = cw - 2.4;
    final ls = _tx(9.5, w: FontWeight.w700, h: 1);
    void text(String s, double x, double baseline) {
      final tp = TextPainter(
        text: TextSpan(text: s, style: ls),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x, baseline - tp.computeDistanceToActualBaseline(TextBaseline.alphabetic)));
    }

    for (var x = 1; x < ws.length - 1; x++) {
      if (ws[x].isEmpty || ws[x - 1].isEmpty) continue;
      if (ws[x].first.date.month != ws[x - 1].first.date.month) text(month3(ws[x].first.date), lw + x * cw, 9);
    }
    for (final (i, d) in const ['Mon', 'Wed', 'Fri'].indexed) {
      text(d, 0, top + (1 + i * 2) * cw + cs * .78);
    }
    final speck = Paint()..color = _ink.withValues(alpha: .45);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = _ink;
    for (var x = 0; x < ws.length; x++) {
      for (final day in ws[x]) {
        final y = day.date.weekday % 7;
        final r = Rect.fromLTWH(lw + x * cw, top + y * cw, cs, cs);
        if (day.level <= 0) {
          canvas.drawRect(Rect.fromCenter(center: r.center, width: 2, height: 2), speck);
          continue;
        }
        final rr = RRect.fromRectAndRadius(r, const Radius.circular(2));
        canvas.save();
        canvas.clipRRect(rr);
        canvas.drawRect(r, Paint()..color = _paper);
        _fill(canvas, r, const [_Pat.sparse, _Pat.rules, _Pat.fine, _Pat.solid][(day.level - 1).clamp(0, 3)]);
        canvas.restore();
        canvas.drawRRect(rr.deflate(.6), stroke);
      }
    }
  }

  @override
  bool shouldRepaint(_HeatPainter o) => o.weeks != weeks;
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
                  Expanded(child: i < row.length ? _key(context, ref, row[i], s.volumePct) : const SizedBox()),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _key(BuildContext context, WidgetRef ref, Tile t, int? vol) {
    final on = t.active;
    final fg = on ? _paper : _ink;
    final small = t.id.startsWith('volume') && vol != null ? '$vol%' : t.detail;
    return _InkKey(
      on: on,
      onTap: () => act(context, ref, 'shortcut.run', {'id': t.id}),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DpIcon(tileIcon(t), size: 38, color: fg, stroke: 1.8),
          const SizedBox(height: 10),
          Text(
            tileLabel(t),
            textAlign: TextAlign.center,
            style: _tx(14, w: FontWeight.w700, c: fg),
          ),
          if (small != null) ...[
            const SizedBox(height: 4),
            Text(
              small,
              style: _tx(12, w: FontWeight.w700, c: fg),
            ),
          ],
        ],
      ),
    );
  }
}

/// `.key`: outlined tile that inverts while pressed (and when on).
class _InkKey extends StatefulWidget {
  const _InkKey({required this.on, required this.onTap, required this.child});
  final bool on;
  final VoidCallback onTap;
  final Widget child;
  @override
  State<_InkKey> createState() => _InkKeyState();
}

class _InkKeyState extends State<_InkKey> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final inv = widget.on != _down;
    Widget child = widget.child;
    if (_down) {
      child = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          -1, 0, 0, 0, 255, //
          0, -1, 0, 0, 255, //
          0, 0, -1, 0, 255, //
          0, 0, 0, 1, 0,
        ]),
        child: child,
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: inv ? _ink : _paper,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _ink, width: 2),
        ),
        child: child,
      ),
    );
  }
}
