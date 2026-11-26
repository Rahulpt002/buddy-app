// Concept 12 — Sketch pages. Sizes follow deskpanel-concept-12-sketch.html (CSS px = logical px).
// Everything is "hand drawn" with a seeded RNG (same generator as the concept) so shapes
// wobble but stay put between rebuilds.
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart' as sch;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/conn/controller.dart';
import '../../core/pages.dart';
import '../../core/settings.dart';
import '../fmt.dart';
import '../icons.dart';
import '../pages/kit.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';

const _ink = Color(0xFF1E1E1E);
const _mut = Color(0xFF6B6B6B);
const _gap = 14.0;
const _tab = [ui.FontFeature.tabularFigures()];

Widget sketchPage(PageId id) => switch (id) {
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

// ------------------------------------------------------------------ palette

enum _C { blue, green, red, orange, violet, yellow, gray, white, ink }

/// Stroke colours (`SC`); colours without one fall back to their fill.
Color _sc(_C c) => switch (c) {
  _C.blue => const Color(0xFF1971C2),
  _C.green => const Color(0xFF2F9E44),
  _C.red => const Color(0xFFE03131),
  _C.orange => const Color(0xFFE8590C),
  _C.violet => const Color(0xFF6741D9),
  _C.gray => const Color(0xFF868E96),
  _C.ink => _ink,
  _ => _fc(c),
};

/// Fill colours (`FC`).
Color _fc(_C c) => switch (c) {
  _C.blue => const Color(0xFFA5D8FF),
  _C.green => const Color(0xFFB2F2BB),
  _C.yellow => const Color(0xFFFFEC99),
  _C.red => const Color(0xFFFFC9C9),
  _C.violet => const Color(0xFFD0BFFF),
  _C.orange => const Color(0xFFFFD8A8),
  _C.gray => const Color(0xFFE9ECEF),
  _ => const Color(0xFFFFFFFF),
};

// ------------------------------------------------------------------ type

TextStyle _s(
  double size, {
  double w = 450,
  Color c = _ink,
  double infm = 60,
  double bnce = 0,
  double? h = 1.3,
  double ls = 0,
}) => TextStyle(
  fontFamily: 'Shantell Sans',
  fontSize: size,
  fontWeight: w >= 650 ? FontWeight.w700 : (w >= 550 ? FontWeight.w600 : FontWeight.w400),
  fontVariations: [FontVariation('wght', w), FontVariation('INFM', infm), FontVariation('BNCE', bnce)],
  color: c,
  height: h,
  letterSpacing: ls,
  fontFeatures: _tab,
);

/// `.hd` box heading.
TextStyle get _hdS => _s(13, w: 500, c: _mut);

/// `.note`.
TextStyle _noteS([double size = 13]) => _s(size, c: _mut);

/// `.hand` — bouncier handwriting.
TextStyle _handS([double size = 13, Color c = _mut]) => _s(size, c: c, infm: 100, bnce: 60);

/// `.big` numbers.
TextStyle _bigS(double size, [Color c = _ink]) => _s(size, w: 700, c: c, infm: 100, bnce: 30, h: .95, ls: -.01 * size);

Widget _hd(String s) => Text(s, maxLines: 1, overflow: TextOverflow.ellipsis, style: _hdS);
Widget _note(String s, {int lines = 1, double size = 13, TextAlign? align}) =>
    Text(s, maxLines: lines, overflow: TextOverflow.ellipsis, textAlign: align, style: _noteS(size));

/// `.big` value with a `.42em` unit, baseline-aligned, shrinking to fit.
Widget _big(String v, double size, {String? unit, Color c = _ink, bool fit = true}) {
  final row = Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      Text(v, maxLines: 1, style: _bigS(size, c)),
      if (unit != null) ...[const SizedBox(width: 2), Text(unit, maxLines: 1, style: _bigS(size * .42, c))],
    ],
  );
  return fit ? FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: row) : row;
}

// ------------------------------------------------------------------ rough drawing

int _hash(String s) {
  var a = 7;
  for (final c in s.codeUnits) {
    a = (a * 31 + c) & 0xFFFFFFFF;
  }
  return a;
}

/// Park–Miller RNG, identical to the concept's `rng(seed)`.
class _Rng {
  _Rng(int seed) : _s = seed % 2147483646 + 1;
  int _s;
  double call() {
    _s = (_s * 16807) % 2147483647;
    return _s / 2147483647;
  }
}

/// Double-stroked wobbly line (`rline`).
void _rline(Path p, double x1, double y1, double x2, double y2, _Rng r, [double j = 1.6]) {
  final len = math.max(1.0, math.sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1)));
  for (var pass = 0; pass < 2; pass++) {
    final bow = (r() - .5) * math.min(8, len * .04);
    final mx = (x1 + x2) / 2 - (y2 - y1) / len * bow, my = (y1 + y2) / 2 + (x2 - x1) / len * bow;
    double jj() => (r() - .5) * j * 2;
    final ax = x1 + jj(), ay = y1 + jj();
    final bx = x2 + jj(), by = y2 + jj();
    p
      ..moveTo(ax, ay)
      ..quadraticBezierTo(mx, my, bx, by);
  }
}

void _rrect(Path p, double x, double y, double w, double h, _Rng r) {
  _rline(p, x, y, x + w, y, r);
  _rline(p, x + w, y, x + w, y + h, r);
  _rline(p, x + w, y + h, x, y + h, r);
  _rline(p, x, y + h, x, y, r);
}

void _rellipse(Path p, double cx, double cy, double rx, double ry, _Rng r) {
  for (var pass = 0; pass < 2; pass++) {
    const n = 30;
    final off = r() * 6.28, ext = 1.06 + r() * .08;
    for (var i = 0; i <= n * ext; i++) {
      final t = off + i / n * 6.283, k = 1 + (r() - .5) * .04;
      final x = cx + rx * k * math.cos(t), y = cy + ry * k * math.sin(t);
      i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
    }
  }
}

/// 45° hachure lines inside a rect (`hach`).
void _hach(Path p, double x, double y, double w, double h, _Rng r, [double gap = 6]) {
  if (w <= 0 || h <= 0) return;
  for (var k = -h; k < w; k += gap) {
    var x1 = x + k, y1 = y + h, x2 = x + k + h, y2 = y;
    if (x1 < x) {
      y1 -= x - x1;
      x1 = x;
    }
    if (x2 > x + w) {
      y2 += x2 - (x + w);
      x2 = x + w;
    }
    if (x2 - x1 < 1.5) continue;
    double jj() => (r() - .5) * 1.4;
    final a = x1 + jj(), b = y1 + jj(), c = x2 + jj(), d = y2 + jj();
    p
      ..moveTo(a, b)
      ..lineTo(c, d);
  }
}

/// Curved hand-drawn arrow (`rarrow`).
void _rarrow(Path p, double x1, double y1, double x2, double y2, _Rng r, [double bend = .25]) {
  final mx = (x1 + x2) / 2 - (y2 - y1) * bend, my = (y1 + y2) / 2 + (x2 - x1) * bend;
  final a = math.atan2(y2 - my, x2 - mx);
  const l = 11.0;
  p
    ..moveTo(x1, y1)
    ..quadraticBezierTo(mx, my, x2, y2);
  _rline(p, x2 - l * math.cos(a - .45), y2 - l * math.sin(a - .45), x2, y2, r, .6);
  _rline(p, x2 - l * math.cos(a + .45), y2 - l * math.sin(a + .45), x2, y2, r, .6);
}

Paint _stroke(Color c, double w) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..color = c;

void _text(Canvas c, String s, double x, double baseline, TextStyle st, {int anchor = 0}) {
  final tp = TextPainter(
    text: TextSpan(text: s, style: st),
    textDirection: TextDirection.ltr,
  )..layout();
  final b = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  final dx = anchor == 1 ? -tp.width / 2 : (anchor == 2 ? -tp.width : 0.0);
  tp.paint(c, Offset(x + dx, baseline - b));
}

enum _Mode { none, solid, hach }

/// Background of any box (`rb`): optional solid / hachure fill, wobbly double outline.
class _RoughBox extends CustomPainter {
  _RoughBox(this.seed, {this.fill, this.mode = _Mode.none, this.line = _C.ink});
  final String seed;
  final _C? fill;
  final _Mode mode;
  final _C line;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final r = _Rng(_hash(seed) + w.round());
    const pad = 3.0;
    if (fill != null && mode == _Mode.solid) {
      final pts = [const Offset(pad, pad), Offset(w - pad, pad), Offset(w - pad, h - pad), Offset(pad, h - pad)];
      final p = Path();
      for (final (i, o) in pts.indexed) {
        final x = o.dx + (r() - .5) * 2, y = o.dy + (r() - .5) * 2;
        i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
      }
      canvas.drawPath(p..close(), Paint()..color = _fc(fill!));
    }
    if (fill != null && mode == _Mode.hach) {
      final p = Path();
      _hach(p, pad + 2, pad + 2, w - 2 * pad - 4, h - 2 * pad - 4, r, 7);
      canvas.drawPath(p, _stroke(_sc(fill!).withValues(alpha: .55), 1.1));
    }
    final o = Path();
    _rrect(o, pad, pad, w - 2 * pad, h - 2 * pad, r);
    canvas.drawPath(o, _stroke(_sc(line), 1.6));
  }

  @override
  bool shouldRepaint(_RoughBox o) => o.seed != seed || o.fill != fill || o.mode != mode || o.line != line;
}

/// `.bx`: a hand-drawn box. [tilt] in degrees (`tilt-l` −1.2, `tilt-r` 1).
Widget _bx(
  Widget child, {
  required String seed,
  _C? f,
  _Mode m = _Mode.none,
  _C s = _C.ink,
  double tilt = 0,
  VoidCallback? onTap,
  EdgeInsets pad = const EdgeInsets.fromLTRB(14, 12, 14, 12),
}) {
  Widget c = CustomPaint(
    painter: _RoughBox(seed, fill: f, mode: m, line: s),
    child: Padding(padding: pad, child: child),
  );
  if (onTap != null) c = Press(onTap: onTap, scale: .985, child: c);
  if (tilt != 0) c = Transform.rotate(angle: tilt * math.pi / 180, child: c);
  return c;
}

/// Public so the skin's shared `card()` draws the same rough box.
class SketchBox extends StatelessWidget {
  const SketchBox({super.key, required this.child, this.seed = 'card', this.padding, this.onTap});
  final Widget child;
  final String seed;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) =>
      _bx(child, seed: seed, onTap: onTap, pad: padding ?? const EdgeInsets.fromLTRB(14, 12, 14, 12));
}

const _tl = -1.2, _tr = 1.0;

/// `.btn`: a rough box button, optionally filled.
Widget _btn(
  String label, {
  String? icon,
  _C? f,
  VoidCallback? onTap,
  double height = 38,
  double hpad = 16,
  double fs = 14,
  double? width,
  _C? fg,
}) {
  final enabled = onTap != null;
  return Press(
    onTap: onTap,
    child: Opacity(
      opacity: enabled ? 1 : .5,
      child: CustomPaint(
        painter: _RoughBox('b$label$icon', fill: f, mode: f == null ? _Mode.none : _Mode.solid),
        child: Container(
          height: height,
          width: width,
          padding: EdgeInsets.symmetric(horizontal: width == null ? hpad : 0),
          child: Row(
            mainAxisSize: width == null ? MainAxisSize.min : MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) DpIcon(icon, size: 17, color: fg == null ? _ink : _sc(fg)),
              if (icon != null && label.isNotEmpty) const SizedBox(width: 7),
              if (label.isNotEmpty) Text(label, style: _s(fs, w: 650, c: fg == null ? _ink : _sc(fg), h: 1)),
            ],
          ),
        ),
      ),
    ),
  );
}

/// `.tabs`: rough buttons; the selected one is filled violet.
Widget _tabs(List<String> items, int value, ValueChanged<int> onChanged) => Wrap(
  spacing: 8,
  runSpacing: 8,
  children: [
    for (final (i, s) in items.indexed)
      _btn(s, f: i == value ? _C.violet : null, onTap: () => onChanged(i), height: 32, hpad: 12, fs: 13),
  ],
);

// ------------------------------------------------------------------ charts

/// `hb`: hachure progress bar, 22 px.
class _Hb extends StatelessWidget {
  const _Hb(this.value, this.col, {this.k = 'hb'});
  final double value;
  final _C col;
  final String k;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 22,
    width: double.infinity,
    child: CustomPaint(painter: _HbPainter(value.clamp(0.0, 1.0), col, k)),
  );
}

class _HbPainter extends CustomPainter {
  _HbPainter(this.p, this.col, this.k);
  final double p;
  final _C col;
  final String k;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final r = _Rng(_hash(k) + (p * 100).round());
    final a = Path();
    _hach(a, 3, 3, math.max(0, (w - 6) * p), h - 6, r, 5);
    canvas.drawPath(a, _stroke(_sc(col), 1.5));
    final e = Path();
    _rline(e, 3 + (w - 6) * p, 2, 3 + (w - 6) * p, h - 2, r, .5);
    canvas.drawPath(e, _stroke(_sc(col), 1.6));
    final o = Path();
    _rrect(o, 2, 2, w - 4, h - 4, r);
    canvas.drawPath(o, _stroke(_ink, 1.5));
  }

  @override
  bool shouldRepaint(_HbPainter o) => o.p != p || o.col != col;
}

/// `pie`: hachured wedge inside a rough circle.
class _Pie extends CustomPainter {
  _Pie(this.p, this.col, this.k);
  final double p;
  final _C col;
  final String k;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, s = math.min(w, h);
    final cx = w / 2, cy = h / 2, rad = s / 2 - 5;
    final pv = p.clamp(0.0, 1.0);
    final r = _Rng(_hash('$k${s.round()}') + (pv * 200).round());
    final a = pv * 2 * math.pi, ex = cx + rad * math.sin(a), ey = cy - rad * math.cos(a);
    final circle = Rect.fromCircle(center: Offset(cx, cy), radius: rad);
    if (pv >= .002) {
      canvas.save();
      if (pv < .999) {
        canvas.clipPath(
          Path()
            ..moveTo(cx, cy)
            ..lineTo(cx, cy - rad)
            ..arcTo(circle, -math.pi / 2, a, false)
            ..close(),
        );
      } else {
        canvas.clipPath(Path()..addOval(circle));
      }
      canvas.drawCircle(Offset(cx, cy), rad, Paint()..color = _fc(col).withValues(alpha: .5));
      final hp = Path();
      _hach(hp, cx - rad, cy - rad, rad * 2, rad * 2, r, 6);
      canvas.drawPath(hp, _stroke(_sc(col), 1.4));
      canvas.restore();
    }
    if (pv > .002 && pv < .999) {
      final e = Path();
      _rline(e, cx, cy, cx, cy - rad, r, .6);
      _rline(e, cx, cy, ex, ey, r, .6);
      canvas.drawPath(e, _stroke(_sc(col), 1.6));
    }
    final o = Path();
    _rellipse(o, cx, cy, rad, rad, r);
    canvas.drawPath(o, _stroke(_ink, 1.6));
  }

  @override
  bool shouldRepaint(_Pie o) => o.p != p || o.col != col;
}

/// Weather doodle: the concept's 4-blob cloud, plus a sun / rain variant per icon.
class _WxDoodle extends CustomPainter {
  _WxDoodle(this.icon);
  final String icon;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final r = _Rng(_hash('cloud${w.round()}'));
    final blue = _sc(_C.blue), orange = _sc(_C.orange);
    final sunny = icon == 'sun' || icon == 'partly';
    if (sunny) {
      final full = icon == 'sun';
      final c = full ? Offset(w * .5, h * .5) : Offset(w * .36, h * .36);
      final rad = math.min(w / 1.4, h) * (full ? .26 : .2);
      final sp = Path();
      _rellipse(sp, c.dx, c.dy, rad, rad, r);
      canvas.drawPath(sp, Paint()..color = _fc(_C.orange).withValues(alpha: .6));
      canvas.drawPath(sp, _stroke(orange, 1.7));
      final rays = Path();
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4;
        _rline(
          rays,
          c.dx + math.cos(a) * rad * 1.3,
          c.dy + math.sin(a) * rad * 1.3,
          c.dx + math.cos(a) * rad * 1.65,
          c.dy + math.sin(a) * rad * 1.65,
          r,
          .5,
        );
      }
      canvas.drawPath(rays, _stroke(orange, 1.5));
      if (full) return;
    }
    final s = math.min(w / 1.4, h);
    final dy = icon == 'rain' ? -h * .12 : (icon == 'partly' ? h * .1 : 0.0);
    final dx = icon == 'partly' ? w * .08 : 0.0;
    final scale = icon == 'partly' ? .8 : 1.0;
    final parts = Path();
    for (final (x, y, rr) in const [(.3, .62, .22), (.52, .45, .28), (.75, .6, .2), (.52, .7, .22)]) {
      _rellipse(parts, x * w + dx, y * h + dy, rr * s * 1.1 * scale, rr * s * scale, r);
    }
    canvas.drawPath(parts, Paint()..color = _fc(_C.blue).withValues(alpha: .35));
    canvas.drawPath(parts, _stroke(blue, 1.7));
    if (icon == 'rain') {
      final drops = Path();
      for (var i = 0; i < 4; i++) {
        final x = w * (.3 + i * .15);
        _rline(drops, x, h * .82, x - w * .04, h * .96, r, .5);
      }
      canvas.drawPath(drops, _stroke(blue, 1.6));
    }
  }

  @override
  bool shouldRepaint(_WxDoodle o) => o.icon != icon;
}

/// A series for [_Lines].
class _Series {
  const _Series(this.values, this.lo, this.hi, this.col, [this.width = 2]);
  final List<double?> values;
  final double lo, hi, width;
  final Color col;
}

/// `linesChart`: jittery double-pass polylines over a rough baseline, with the CPU peak
/// annotation or the temperature dots/labels.
class _Lines extends CustomPainter {
  _Lines(this.k, this.series, {this.peak = false, this.labels, this.valueLabels});
  final String k;
  final List<_Series> series;
  final bool peak;
  final List<String>? labels, valueLabels;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final r = _Rng(_hash(k) + w.round());
    const pad = 8.0;
    final base = Path();
    _rline(base, pad, h - 14, w - pad, h - 14, r);
    canvas.drawPath(base, _stroke(_ink, 1.5));
    List<Offset?> last = const [];
    for (final s in series) {
      final n = s.values.length;
      if (n < 2) continue;
      final pts = <Offset?>[
        for (final (i, v) in s.values.indexed)
          v == null
              ? null
              : Offset(
                  pad + i / (n - 1) * (w - 2 * pad),
                  pad + (h - 2 * pad - 14) * (1 - (v.clamp(s.lo, s.hi) - s.lo) / (s.hi - s.lo)),
                ),
      ];
      final p = Path();
      for (var pass = 0; pass < 2; pass++) {
        var pen = false;
        for (final o in pts) {
          if (o == null) {
            pen = false;
            continue;
          }
          final x = o.dx + (r() - .5) * 1.4, y = o.dy + (r() - .5) * 1.4;
          pen ? p.lineTo(x, y) : p.moveTo(x, y);
          pen = true;
        }
      }
      canvas.drawPath(p, _stroke(s.col.withValues(alpha: .9), s.width));
      last = pts;
    }
    if (peak && series.isNotEmpty) {
      final vals = series.last.values;
      var i = -1;
      var mx = -1e9;
      for (final (j, v) in vals.indexed) {
        if (v != null && v > mx) {
          mx = v;
          i = j;
        }
      }
      if (i >= 0 && last[i] != null) {
        final o = last[i]!;
        final tx = math.min(w - 90, o.dx + 40), ty = math.max(14.0, o.dy - 26);
        final a = Path();
        _rarrow(a, tx, ty + 4, o.dx + 3, o.dy - 4, r, .2);
        canvas.drawPath(a, _stroke(_ink, 1.4));
        _text(canvas, 'peak ${mx.round()}%', tx + 4, ty, _s(13));
      }
    }
    if (labels != null && last.isNotEmpty) {
      final dot = Paint()..color = _fc(_C.orange);
      final ring = _stroke(_sc(_C.orange), 1.5);
      for (var i = 0; i < last.length; i += 2) {
        final o = last[i];
        if (o == null) continue;
        canvas.drawCircle(o, 3, dot);
        canvas.drawCircle(o, 3, ring);
        if (valueLabels != null && i < valueLabels!.length) {
          _text(canvas, valueLabels![i], o.dx, o.dy - 8, _s(12), anchor: 1);
        }
        if (i < labels!.length) _text(canvas, labels![i], o.dx, h - 1, _s(11, c: _mut), anchor: 1);
      }
    }
  }

  @override
  bool shouldRepaint(_Lines o) => true;
}

/// Hachured bar chart with rough outlines (`bars7`, GitHub `week`).
class _Bars extends CustomPainter {
  _Bars(
    this.k,
    this.values,
    this.max,
    this.labels,
    this.cols, {
    this.valueLabels,
    this.labelCols,
    this.top = 34,
    this.widthK = .6,
  });
  final String k;
  final List<double> values;
  final double max, top, widthK;
  final List<String> labels;
  final List<_C> cols;
  final List<String>? valueLabels;
  final List<Color>? labelCols;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final r = _Rng(_hash('$k${w.round()}'));
    final n = values.length;
    if (n == 0) return;
    final bw = w / n;
    for (var i = 0; i < n; i++) {
      final v = values[i];
      final bh = (v / max).clamp(0.0, 1.0) * (h - top);
      final x = i * bw + bw * (1 - widthK) / 2, y = h - 18 - bh;
      if (v > 0) {
        final hp = Path();
        _hach(hp, x, y, bw * widthK, bh, r, 5);
        canvas.drawPath(hp, _stroke(_sc(cols[i]), 1.3));
        final o = Path();
        _rrect(o, x, y, bw * widthK, bh, r);
        canvas.drawPath(o, _stroke(_ink, 1.4));
        if (valueLabels != null) _text(canvas, valueLabels![i], x + bw * widthK / 2, y - 5, _s(12), anchor: 1);
      }
      _text(canvas, labels[i], x + bw * widthK / 2, h - 2, _s(12, c: labelCols?[i] ?? _mut), anchor: 1);
    }
  }

  @override
  bool shouldRepaint(_Bars o) => true;
}

/// Rough seek line with a violet progress stroke and a knob.
class _SeekPainter extends CustomPainter {
  _SeekPainter(this.p);
  final double p;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, y = size.height / 2, x = 8 + (w - 16) * p.clamp(0.0, 1.0);
    final a = Path();
    _rline(a, 8, y, w - 8, y, _Rng(77));
    canvas.drawPath(a, _stroke(const Color(0xFFADB5BD), 2));
    final b = Path();
    _rline(b, 8, y, x, y, _Rng(5));
    canvas.drawPath(b, _stroke(_sc(_C.violet), 3));
    final k = Path();
    _rellipse(k, x, y, 8, 8, _Rng(9));
    canvas.drawPath(k, Paint()..color = _fc(_C.violet));
    canvas.drawPath(k, _stroke(_ink, 1.5));
  }

  @override
  bool shouldRepaint(_SeekPainter o) => o.p != p;
}

// ------------------------------------------------------------------ helpers

String _inText(CalEvent e, DateTime now) {
  if (!e.start.isAfter(now)) return 'now';
  final d = e.start.difference(now);
  return d.inMinutes < 1 ? 'now' : 'in ${dur(d)}';
}

String _m(int tokens) => tokens >= 1e6 ? '${(tokens / 1e6).round()}M' : compact(tokens);

// ------------------------------------------------------------------ Home

class _Home extends ConsumerWidget {
  const _Home();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void go(PageId p) => PageNav.go(context, p);
    return Ticker(
      builder: (context, now) => LayoutBuilder(
        builder: (context, c) {
          final fr = (c.maxWidth - 2 * _gap) / 3.1;
          final c1 = fr * 1.1, rowH = (c.maxHeight - _gap) / 2;
          return Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: c1, child: _clock(ref, now)),
                  const SizedBox(width: _gap),
                  SizedBox(
                    width: fr,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _next(ref, now, () => go(PageId.calendar))),
                        const SizedBox(height: _gap),
                        Expanded(child: _slack(ref, now, () => go(PageId.slack))),
                      ],
                    ),
                  ),
                  const SizedBox(width: _gap),
                  SizedBox(
                    width: fr,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _claude(ref, now, () => go(PageId.claude))),
                        const SizedBox(height: _gap),
                        Expanded(child: _weather(context, ref, () => go(PageId.weather))),
                      ],
                    ),
                  ),
                ],
              ),
              if (nextEvent(ref.watch(calendarEventsProvider), now) != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _Arrow(Offset(c1 - 10, c.maxHeight * .58), Offset(c1 + _gap + 6, rowH / 2)),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _clock(WidgetRef ref, DateTime now) {
    final h24 = ref.watch(settingsProvider.select((s) => s.clock24));
    final events = ref.watch(calendarEventsProvider);
    final today = splitEvents(events, now).today.length;
    return _bx(
      seed: 'clock',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _hd(longDate(now)),
          const SizedBox(height: 6),
          _big(clock(now, h24: h24), 96, unit: h24 ? null : ampm(now)),
          const Spacer(),
          Text(
            today == 0 ? 'no events today.' : '$today event${today == 1 ? '' : 's'} today.',
            maxLines: 2,
            style: _handS(15),
          ),
        ],
      ),
    );
  }

  Widget _next(WidgetRef ref, DateTime now, VoidCallback onTap) {
    final h24 = ref.watch(settingsProvider.select((s) => s.clock24));
    final n = nextEvent(ref.watch(calendarEventsProvider), now);
    return _bx(
      seed: 'next',
      f: _C.yellow,
      m: _Mode.solid,
      tilt: _tl,
      onTap: onTap,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _hd('next up'),
          const SizedBox(height: 4),
          Text(n?.title ?? 'nothing else today', maxLines: 1, overflow: TextOverflow.ellipsis, style: _s(20, w: 700)),
          const SizedBox(height: 6),
          if (n != null) _big(_inText(n, now), 34, c: _sc(_C.red)) else _big('free!', 34, c: _sc(_C.green)),
          if (n != null) _note([clockFull(n.start, h24: h24), ?n.location].join(', ')),
        ],
      ),
    );
  }

  Widget _claude(WidgetRef ref, DateTime now, VoidCallback onTap) {
    final c = topicData<ClaudeData>(ref, 'claude');
    final five = limitPct(c?.fiveHour, now), week = limitPct(c?.sevenDay, now);
    final violet = _sc(_C.violet);
    return _bx(
      seed: 'cl',
      tilt: _tr,
      onTap: onTap,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _hd('Claude, 5-hour'),
                    c?.fiveHour == null ? _big('—', 44, c: violet) : _big('${five.round()}', 44, unit: '%', c: violet),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(width: 70, height: 70, child: CustomPaint(painter: _Pie(five / 100, _C.violet, 'five'))),
            ],
          ),
          _note(
            '${resetsIn(c?.fiveHour, now).replaceFirst('Resets', 'resets')}. weekly ${c?.sevenDay == null ? '—' : '${week.round()}%'}',
            lines: 2,
          ),
        ],
      ),
    );
  }

  /// Slack: the unread count as a big number, the newest unread message under it.
  Widget _slack(WidgetRef ref, DateTime now, VoidCallback onTap) {
    final s = topicData<SlackData>(ref, 'slack');
    final info = slackHome(ref);
    final m = info.latest;
    final caughtUp = m == null && info.headline == 'All caught up';
    final detail = info.detail == '—' ? null : info.detail[0].toLowerCase() + info.detail.substring(1);
    return _bx(
      seed: 'sl',
      onTap: onTap,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _hd(s?.team == null ? 'slack' : 'slack, ${s!.team!.toLowerCase()}'),
          const SizedBox(height: 4),
          if (m != null) ...[
            _big('${info.unread}', 40, unit: 'unread', c: _sc(_C.orange)),
            const SizedBox(height: 10),
            Row(
              children: [
                _face(m, 38),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Flexible(
                            child: Text(m.sender, maxLines: 1, overflow: TextOverflow.ellipsis, style: _s(14, w: 700)),
                          ),
                          const SizedBox(width: 8),
                          Text(slackTime(m.ts, now).toLowerCase(), style: _noteS(12)),
                        ],
                      ),
                      Text(m.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: _handS(15, _ink)),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                if (caughtUp) ...[
                  const SizedBox(width: 34, height: 30, child: CustomPaint(painter: _Tick())),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: caughtUp
                      ? Text('all caught up!', maxLines: 1, overflow: TextOverflow.ellipsis, style: _handS(24, _ink))
                      : _big('—', 40, c: _sc(_C.gray)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (detail != null) _note(detail),
          ],
        ],
      ),
    );
  }

  Widget _weather(BuildContext context, WidgetRef ref, VoidCallback onTap) {
    final w = ref.watch(weatherProvider);
    final f = ref.watch(settingsProvider.select((s) => s.fahrenheit));
    final m = topicData<MediaData>(ref, 'media');
    return _bx(
      seed: 'wx',
      f: _C.blue,
      m: _Mode.hach,
      onTap: onTap,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(width: 84, height: 62, child: CustomPaint(painter: _WxDoodle(w?.now.icon ?? 'cloud'))),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _big(w == null ? '—' : '${temp(w.now.tempC, f)}°', 38, c: _sc(_C.blue)),
                    _note(
                      w == null
                          ? 'set a location'
                          : '${w.now.condition.toLowerCase()}${w.days.isEmpty ? '' : ', high ${temp(w.days.first.hiC, f)}°'}',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m?.title ?? 'nothing playing',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _s(13.5, w: 700),
                    ),
                    _note(m?.artist ?? ''),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (m?.title != null)
                _btn(
                  '',
                  icon: m!.playing ? 'pause' : 'play',
                  width: 40,
                  onTap: () => act(context, ref, 'media.play_pause'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The red arrow from the clock to "next up".
class _Arrow extends CustomPainter {
  _Arrow(this.a, this.b);
  final Offset a, b;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Path();
    _rarrow(p, a.dx, a.dy, b.dx, b.dy, _Rng(3), -.25);
    canvas.drawPath(p, _stroke(_sc(_C.red), 1.8));
  }

  @override
  bool shouldRepaint(_Arrow o) => o.a != a || o.b != b;
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
          child: _tabs(const ['Laptop', 'Internet'], tab, ref.read(systemTabProvider.notifier).set),
        ),
        const SizedBox(height: _gap),
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
    final f = ref.watch(settingsProvider.select((x) => x.fahrenheit));
    final cpuT = s.cpu.tempC;
    Widget metric(String label, String k, double? v, String sub, _C col, {String? aside}) => Expanded(
      child: _bx(
        seed: 'm$k',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _hd(label),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 2, 0, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: v == null ? _big('N/A', 44, c: _sc(col)) : _big('${v.round()}', 44, unit: '%', c: _sc(col)),
                  ),
                  // A small handwritten aside by the figure (the CPU's temperature).
                  if (aside != null) ...[
                    const SizedBox(width: 10),
                    Padding(padding: const EdgeInsets.only(bottom: 5), child: Text(aside, style: _handS(14))),
                  ],
                ],
              ),
            ),
            _Hb((v ?? 0) / 100, col, k: k),
            const SizedBox(height: 6),
            _note(sub),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              metric(
                'processor',
                'cpu',
                s.cpu.pct,
                s.cpu.cores != null ? '${s.cpu.cores} cores, ${s.cpu.threads ?? s.cpu.cores} threads' : s.cpu.model,
                _C.blue,
                aside: cpuT == null ? null : '${temp(cpuT, f)}°${f ? 'F' : 'C'}',
              ),
              const SizedBox(width: _gap),
              metric(
                'graphics',
                'gpu',
                g.available ? g.pct : null,
                g.tempC != null ? '${g.tempC!.round()}°C' : (g.available ? (g.model ?? 'gpu') : 'not available'),
                _C.green,
              ),
              const SizedBox(width: _gap),
              metric(
                'memory',
                'ram',
                s.ramUsed / s.ramTotal * 100,
                '${(s.ramUsed / gb).toStringAsFixed(1)} of ${(s.ramTotal / gb).round()} GB',
                _C.violet,
              ),
              const SizedBox(width: _gap),
              metric(
                g.vramLabel == 'VRAM' ? 'video memory' : g.vramLabel.toLowerCase(),
                'vram',
                vramPct,
                vramPct == null
                    ? 'not available'
                    : '${(g.vramUsed! / gb).toStringAsFixed(1)} of ${(g.vramTotal! / gb).round()} GB',
                _C.orange,
              ),
            ],
          ),
        ),
        const SizedBox(height: _gap),
        Expanded(
          child: _bx(
            seed: 'chart',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'last minute: '),
                          TextSpan(
                            text: 'cpu',
                            style: _hdS.copyWith(color: _sc(_C.blue)),
                          ),
                          if (g.available) ...[
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'gpu',
                              style: _hdS.copyWith(color: _sc(_C.green)),
                            ),
                          ],
                        ],
                      ),
                      style: _hdS,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _note(
                        '$down $downU down, $up $upU up. ${s.cpu.model}${g.model != null ? ', ${g.model}' : ''}',
                        align: TextAlign.right,
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _Lines('sys', [
                      if (g.available) _Series(s.gpuHistory, 0, 100, _sc(_C.green)),
                      _Series(s.cpuHistory, 0, 100, _sc(_C.blue)),
                    ], peak: true),
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

class _Internet extends ConsumerWidget {
  const _Internet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = topicData<NetworkData>(ref, 'network');
    final sys = topicData<SystemData>(ref, 'system');
    final live = ref.watch(agentProvider).live;
    if (n == null) return _bx(seed: 'wait', Center(child: _note('waiting for network data…', size: 14)));
    final st = n.speedtest, last = st.last, prog = st.progress;
    final dl = st.running ? prog?.downBps : last?.downBps;
    final ul = st.running ? prog?.upBps : last?.upBps;
    final ok = live && n.online;
    return Ticker(
      builder: (context, now) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 100,
                  child: _bx(
                    seed: 'lat',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _hd('latency'),
                        n.latencyMs == null
                            ? _big('timeout', 40, c: _sc(_C.red))
                            : _big('${n.latencyMs!.round()}', 54, unit: 'ms', c: _sc(_C.blue)),
                        _note('jitter ${n.jitterMs?.toStringAsFixed(1) ?? '—'} ms, ${n.lossPct.round()}% loss'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: _gap),
                Expanded(
                  flex: 100,
                  child: _bx(
                    seed: 'conn',
                    f: ok ? _C.green : _C.red,
                    m: _Mode.solid,
                    tilt: _tr,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _hd('connection'),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: _big(
                            !live ? 'hmm, unknown' : (n.online ? 'online' : 'offline'),
                            30,
                            c: _sc(ok ? _C.green : _C.red),
                          ),
                        ),
                        _note(
                          '${n.onlineSince != null ? 'up ${durLong(now.difference(n.onlineSince!))}.' : ''}'
                          '${n.lastDrop != null ? ' last drop ${ago(now.difference(n.lastDrop!))}.' : ''}\n'
                          '${bytes(n.usageToday)} today, ${bytes(n.usageMonth, digits: 0)} this month',
                          lines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: _gap),
                Expanded(
                  flex: 125,
                  child: _bx(
                    seed: 'speed',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _hd('speed test (Mbps)'),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                _big(dl == null ? '—' : mbps(dl), 40, unit: 'down', fit: false),
                                const SizedBox(width: 14),
                                _big(ul == null ? '—' : mbps(ul), 40, unit: 'up', fit: false),
                              ],
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _note(
                                st.running
                                    ? 'testing now…'
                                    : (last == null
                                          ? 'never tested'
                                          : 'Tested ${ago(now.difference(last.at))}, ping ${last.pingMs.round()} ms'),
                                lines: 2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _btn(
                              st.running ? 'Testing…' : 'Run test',
                              f: _C.yellow,
                              onTap: st.running
                                  ? null
                                  : () => act(
                                      context,
                                      ref,
                                      'speedtest.run',
                                      const {},
                                      null,
                                      null,
                                      const Duration(seconds: 90),
                                    ),
                            ),
                          ],
                        ),
                        if (st.running) ...[const SizedBox(height: 6), _Hb((prog?.pct ?? 0) / 100, _C.orange, k: 'st')],
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
                  flex: 3,
                  child: _bx(
                    seed: 'latc',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _hd('latency, last 2 minutes, 0 to 50 ms'),
                        Expanded(
                          child: CustomPaint(
                            size: Size.infinite,
                            painter: _Lines('lat', [_Series(n.latencyHistory, 0, 50, _sc(_C.blue), 1.6)]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (sys != null) ...[const SizedBox(width: _gap), Expanded(flex: 2, child: _traffic(sys))],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A sticky note of what the laptop is moving right now, with its last minute scribbled.
  Widget _traffic(SystemData s) {
    final (down, downU) = rate(s.downBps);
    final (up, upU) = rate(s.upBps);
    final peak = [...s.downHistory, ...s.upHistory, s.downBps, s.upBps].fold(64 * 1024.0, math.max) * 1.1;
    return _bx(
      seed: 'now',
      f: _C.yellow,
      m: _Mode.solid,
      tilt: -.8,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _hd('your laptop right now'),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                _big(down, 34, unit: '$downU down', c: _sc(_C.blue), fit: false),
                const SizedBox(width: 14),
                _big(up, 34, unit: '$upU up', c: _sc(_C.violet), fit: false),
              ],
            ),
          ),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _Lines('now', [
                _Series(s.upHistory, 0, peak, _sc(_C.violet), 1.6),
                _Series(s.downHistory, 0, peak, _sc(_C.blue)),
              ]),
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
    final violet = _sc(_C.violet), orange = _sc(_C.orange);
    return Ticker(
      builder: (context, now) {
        final five = limitPct(c.fiveHour, now), week = limitPct(c.sevenDay, now);
        final peak = maxOf(c.days.map((d) => d.tokens));
        final b = _hdS.copyWith(
          color: _ink,
          fontWeight: FontWeight.w700,
          fontVariations: const [FontVariation('wght', 700), FontVariation('INFM', 60), FontVariation('BNCE', 0)],
        );
        TextSpan line(String v, String rest) => TextSpan(
          children: [
            TextSpan(text: v, style: _s(15, w: 700)),
            TextSpan(text: ' $rest'),
          ],
        );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 110,
              child: _bx(
                seed: 'c5',
                Align(
                  alignment: Alignment.topLeft,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: CustomPaint(painter: _Pie(five / 100, _C.violet, 'five')),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _hd('5-hour limit'),
                              c.fiveHour == null
                                  ? _big('—', 64, c: violet)
                                  : _big('${five.round()}', 64, unit: '%', c: violet),
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(text: c.fiveHour == null ? 'no data yet' : 'resets in '),
                                    if (c.fiveHour != null)
                                      TextSpan(
                                        text: resetsIn(c.fiveHour, now).replaceFirst('Resets in ', ''),
                                        style: b,
                                      ),
                                  ],
                                ),
                                maxLines: 2,
                                style: _noteS(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: _gap),
            Expanded(
              flex: 200 + 14 * 100 ~/ 276,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _bx(
                            seed: 'cw',
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _hd('weekly limit'),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: c.sevenDay == null
                                      ? _big('—', 42, c: orange)
                                      : _big('${week.round()}', 42, unit: '%', c: orange),
                                ),
                                _Hb(week / 100, _C.orange, k: 'week'),
                                const SizedBox(height: 6),
                                _note(resetsAt(c.sevenDay, now, h24: h24).replaceFirst('Resets', 'resets')),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: _gap),
                        Expanded(
                          child: _bx(
                            seed: 'ct',
                            f: _C.yellow,
                            m: _Mode.solid,
                            tilt: _tr,
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _hd('today'),
                                const SizedBox(height: 2),
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      line(compact(c.tokens), 'tokens\n'),
                                      line(compact(c.outputTokens), 'output\n'),
                                      line('${c.messages}', 'messages\n'),
                                      line(compact(c.lastHourTokens), 'in the last hour'),
                                    ],
                                  ),
                                  style: _s(15, h: 1.55),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: _gap),
                  Expanded(
                    child: _bx(
                      seed: 'c7',
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _hd('tokens, last 7 days'),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _note(
                                  c.modelsToday.map((m) => '${modelName(m.family)} ${compact(m.tokens)}').join(', '),
                                  align: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                          Expanded(
                            child: CustomPaint(
                              size: Size.infinite,
                              painter: _Bars(
                                'b7',
                                [for (final d in c.days) d.tokens.toDouble()],
                                peak,
                                [for (final d in c.days) dayLabel(d.date, now).toLowerCase()],
                                [for (var i = 0; i < c.days.length; i++) i == c.days.length - 1 ? _C.violet : _C.blue],
                                valueLabels: [for (final d in c.days) _m(d.tokens)],
                                labelCols: [
                                  for (var i = 0; i < c.days.length; i++) i == c.days.length - 1 ? violet : _mut,
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
        final today = split.today;
        // A window of up to three of today's events that includes the next one.
        final ni = n == null ? today.length - 1 : today.indexOf(n);
        final start = (ni - 1).clamp(0, math.max(0, today.length - 3)).toInt();
        final shown = today.skip(start).take(3).toList();
        final timed = today.where((e) => !e.allDay).toList();
        final free = timed.isEmpty
            ? 'nothing on the calendar.'
            : 'free after ${clockFull(timed.map((e) => e.end).reduce((a, b) => a.isAfter(b) ? a : b), h24: h24)}.';
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 300 + 28,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < 3; i++) ...[
                          if (i > 0) const SizedBox(width: _gap),
                          Expanded(
                            child: i < shown.length
                                ? _event(shown[i], start + i, now, shown[i] == n, h24)
                                : (shown.isEmpty && i == 0
                                      ? _bx(
                                          seed: 'none',
                                          Center(child: Text('nothing today!', style: _handS(18, _ink))),
                                        )
                                      : const SizedBox()),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: _gap),
                  Text(
                    'today, ${longDate(now)}. $free',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _handS(14),
                  ),
                ],
              ),
            ),
            const SizedBox(width: _gap),
            Expanded(
              flex: 110,
              child: _bx(
                seed: 'later',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _hd('later this week'),
                    if (split.later.isEmpty) ...[const SizedBox(height: 8), _note('nothing planned', lines: 2)],
                    for (final e in split.later.take(4))
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(text: weekday(e.start), style: _s(14, w: 700)),
                                  TextSpan(text: ', ${e.allDay ? 'all day' : clockFull(e.start, h24: h24)}'),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _s(14),
                            ),
                            _note('${e.title}${e.location != null ? ' at ${e.location}' : ''}', lines: 2),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _event(CalEvent e, int i, DateTime now, bool next, bool h24) {
    final work = (e.calendar ?? '').toLowerCase().contains('work');
    final done = !next && e.end.isBefore(now);
    return _bx(
      seed: 'ev$i',
      f: next ? _C.yellow : (work ? _C.blue : _C.violet),
      m: next ? _Mode.solid : _Mode.hach,
      tilt: const [_tl, _tr, 0.0][i % 3],
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _hd(e.allDay ? 'all day' : '${clockFull(e.start, h24: h24)} to ${clockFull(e.end, h24: h24)}'),
          const SizedBox(height: 4),
          Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: _s(20, w: 700, h: 1.15)),
          _note([e.location, e.calendar?.toLowerCase()].whereType<String>().join(', ')),
          const Spacer(),
          next ? _big(_inText(e, now), 34, c: _sc(_C.red)) : _big(done ? 'done' : 'later', 22),
        ],
      ),
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
    if (w == null) {
      return _bx(
        seed: 'nowx',
        Center(child: Text('set your location in settings', style: _handS(16, _ink))),
      );
    }
    final f = s.fahrenheit;
    final temps = [for (final h in w.hours) temp(h.tempC, f).toDouble()];
    final lo = temps.isEmpty ? 0.0 : temps.reduce(math.min), hi = temps.isEmpty ? 1.0 : temps.reduce(math.max);
    final span = math.max(1.0, hi - lo);
    String hourLabel(int i, DateTime t) => i == 0
        ? 'now'
        : (s.clock24 ? '${two(t.hour)}:00' : '${t.hour % 12 == 0 ? 12 : t.hour % 12} ${ampm(t).toLowerCase()}');
    final blue = _sc(_C.blue);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 100,
          child: _bx(
            seed: 'wxn',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      SizedBox(width: 150, height: 120, child: CustomPaint(painter: _WxDoodle(w.now.icon))),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _big('${temp(w.now.tempC, f)}°', 80, c: blue),
                            Text(
                              w.now.condition.toLowerCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _s(18),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _note(
                  'feels like ${temp(w.now.feelsC, f)}°, ${w.now.humidity}% humidity, wind ${wind(w.now.windKmh, f)}. '
                  'updated ${clockFull(w.now.updated, h24: s.clock24)}',
                  lines: 2,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: _gap),
        Expanded(
          flex: 130,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _bx(
                  seed: 'wxh',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _hd('next 12 hours'),
                      Expanded(
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: _Lines(
                            'temp',
                            [_Series(temps, lo - span * .6, hi + span * .25, _sc(_C.orange), 2.2)],
                            labels: [for (final (i, h) in w.hours.indexed) hourLabel(i, h.time)],
                            valueLabels: [for (final t in temps) '${t.round()}°'],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: _gap),
              Expanded(
                child: _bx(
                  seed: 'wxd',
                  f: _C.blue,
                  m: _Mode.hach,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _hd('this week'),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Row(
                          children: [
                            for (final (i, d) in w.days.take(6).indexed)
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _note(i == 0 ? 'today' : weekday3(d.date).toLowerCase()),
                                    const SizedBox(height: 3),
                                    DpIcon(d.icon, size: 22, color: _ink),
                                    const SizedBox(height: 3),
                                    Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(text: '${temp(d.hiC, f)}°', style: _s(14, w: 700)),
                                          TextSpan(text: ' ${temp(d.loC, f)}°', style: _noteS()),
                                        ],
                                      ),
                                      maxLines: 1,
                                    ),
                                    SizedBox(
                                      height: 15,
                                      child: Text(
                                        d.precipPct > 0 ? '${d.precipPct}%' : '',
                                        style: _s(12, c: blue, h: 1.2),
                                      ),
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
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ Music

/// A white "polaroid" with art and a handwritten caption.
Widget _polaroid(Widget art, String caption, {required String seed, double tilt = _tl, EdgeInsets? pad}) =>
    Transform.rotate(
      angle: tilt * math.pi / 180,
      child: CustomPaint(
        painter: _RoughBox(seed, fill: _C.white, mode: _Mode.solid),
        child: Stack(
          children: [
            Padding(
              padding: pad ?? const EdgeInsets.fromLTRB(12, 12, 12, 34),
              child: SizedBox.expand(child: art),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 8,
              child: Text(caption, maxLines: 1, overflow: TextOverflow.ellipsis, style: _handS(13)),
            ),
          ],
        ),
      ),
    );

class _Music extends ConsumerWidget {
  const _Music();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = topicData<MediaData>(ref, 'media')!;
    final art = topicData<MediaArt>(ref, 'media.art');
    final skew = ref.read(agentProvider.notifier).clockSkewMs;
    // While music plays, hand-drawn notes slip out from behind the polaroid's corner and
    // drift up into the open space above the song, and a scribbled sound wave wiggles by
    // the buttons.
    return _Boil(
      playing: m.playing,
      builder: (context, k) => Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(key: k.stageKey, child: CustomPaint(painter: _NotesPainter(k))),
            ),
          ),
          _body(context, ref, m, art, skew, k),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, MediaData m, MediaArt? art, int skew, _SkClock k) {
    return Row(
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final side = math.min(c.maxHeight, _artMax);
            return SizedBox(
              width: side,
              height: side,
              child: _polaroid(
                AlbumArt(title: m.title ?? 'Nothing playing', b64: art?.artId == m.artId ? art?.b64 : null),
                (m.album ?? m.source ?? '').toLowerCase(),
                seed: 'polaroid',
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
              KeyedSubtree(key: k.headKey, child: _hd('now playing on ${(m.source ?? 'your laptop').toLowerCase()}')),
              const SizedBox(height: 6),
              Text(m.title ?? 'nothing playing', maxLines: 2, overflow: TextOverflow.ellipsis, style: _bigS(40)),
              const SizedBox(height: 4),
              if (m.artist != null) Text(m.artist!, maxLines: 1, overflow: TextOverflow.ellipsis, style: _s(18)),
              const SizedBox(height: 24),
              Ticker(
                period: const Duration(seconds: 1),
                builder: (context, now) {
                  final pos = m.positionNow(now, skewMs: skew);
                  final total = m.durationMs ?? 0;
                  return Column(
                    children: [
                      _SkSeek(
                        value: total == 0 ? 0 : pos / total,
                        enabled: m.canSeek && total > 0,
                        onSeek: (f) => act(context, ref, 'media.seek', {'position_ms': (f * total).round()}),
                      ),
                      Row(
                        children: [_note(mmss(pos)), const Spacer(), _note(total == 0 ? '' : '-${mmss(total - pos)}')],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _btn('', icon: 'prev', width: 52, height: 46, onTap: () => act(context, ref, 'media.prev')),
                  const SizedBox(width: 10),
                  _btn(
                    m.playing ? 'Pause' : 'Play',
                    icon: m.playing ? 'pause' : 'play',
                    f: _C.violet,
                    height: 46,
                    hpad: 22,
                    onTap: () => act(context, ref, 'media.play_pause'),
                  ),
                  const SizedBox(width: 10),
                  _btn('', icon: 'next', width: 52, height: 46, onTap: () => act(context, ref, 'media.next')),
                  const SizedBox(width: 22),
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: RepaintBoundary(child: CustomPaint(painter: _ScribblePainter(k))),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

const _artMax = 320.0;

// ------------------------------------------------------------------ music doodles

/// One floating note: [born] in [_SkClock.t] seconds; everything else comes from [id].
typedef _Float = ({int id, double born});

const _noteLife = 4.4;

/// Stable pseudo-random 0..1 for an integer.
double _rnd(int i) {
  var x = (i * 0x27d4eb2d + 0x165667b1) & 0x7fffffff;
  x = ((x ^ (x >> 15)) * 0x2c1b3c6d) & 0x7fffffff;
  x = ((x ^ (x >> 12)) * 0x297a2d39) & 0x7fffffff;
  return (x ^ (x >> 15)) / 0x7fffffff;
}

/// Smooth value noise, 0..1.
double _vnoise(double x) {
  final i = x.floor();
  final f = x - i;
  final u = f * f * (3 - 2 * f);
  return _rnd(i) + (_rnd(i + 1) - _rnd(i)) * u;
}

/// The music doodles' clock, stepped like hand-drawn animation: about ten drawings a
/// second (a ticker for one frame, then a short timer), each re-jittering every stroke —
/// the "boiling line" look, and a tenth of the repaints of a smooth animation. [t] is
/// seconds, [frame] picks the jitter, [e] eases 0 ↔ 1 with play / pause. Stops once paused
/// and the last note has floated away; the ticker keeps it paused while off screen.
class _SkClock extends ChangeNotifier {
  _SkClock(TickerProvider vsync, bool playing) : _on = playing, e = playing ? 1 : 0 {
    _tk = vsync.createTicker(_tick);
    _sw.start();
    // Opened mid-song: a few notes are already on their way up.
    if (playing) {
      for (var i = 1; i <= 4; i++) {
        notes.add((id: _id++, born: -i * 1.05));
      }
      _tk.start();
    }
  }

  late final sch.Ticker _tk;
  final _sw = Stopwatch();
  Timer? _next;
  bool _on;
  double t = 0, e, _at = 0, _wait = 0;
  int frame = 0, _id = 0;
  final notes = <_Float>[];

  /// Layout anchors for [_NotesPainter]: its own box and the "now playing" line, so the
  /// notes keep to the space above the song however many lines the title takes.
  final stageKey = GlobalKey(), headKey = GlobalKey();

  set playing(bool v) {
    if (v == _on) return;
    _on = v;
    _wait = 0;
    if (!_tk.isActive && _next == null) _tk.start();
  }

  void _tick(Duration _) {
    _tk.stop();
    final now = _sw.elapsedMicroseconds / 1e6;
    final dt = (now - _at).clamp(0.0, .25);
    _at = now;
    t += dt;
    frame++;
    final goal = _on ? 1.0 : 0.0;
    e += (goal - e) * (1 - math.exp(-dt * 4));
    if ((goal - e).abs() < .02) e = goal;
    notes.removeWhere((n) => t - n.born > _noteLife);
    if (_on && (_wait -= dt) <= 0) {
      notes.add((id: _id, born: t));
      _wait = .75 + .7 * _rnd(_id++ * 7 + 3);
    }
    notifyListeners();
    if (_on || e > 0 || notes.isNotEmpty) {
      _next = Timer(const Duration(milliseconds: 90), () {
        _next = null;
        _tk.start();
      });
    }
  }

  @override
  void dispose() {
    _next?.cancel();
    _tk.dispose();
    super.dispose();
  }
}

/// Owns a [_SkClock] for its subtree.
class _Boil extends StatefulWidget {
  const _Boil({required this.playing, required this.builder});
  final bool playing;
  final Widget Function(BuildContext context, _SkClock k) builder;
  @override
  State<_Boil> createState() => _BoilState();
}

class _BoilState extends State<_Boil> with SingleTickerProviderStateMixin {
  late final _k = _SkClock(this, widget.playing);

  @override
  void didUpdateWidget(_Boil old) {
    super.didUpdateWidget(old);
    _k.playing = widget.playing;
  }

  @override
  void dispose() {
    _k.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _k);
}

/// A hand-drawn ♪ (or ♫ when [pair]) with its head at the origin, about 26 px tall: a
/// filled, wobbly-outlined head, a stem and a flag (or a thick scribbled beam).
void _drawNote(Canvas c, _Rng r, {required bool pair, required Color fill, required double alpha}) {
  final ink = _stroke(_ink.withValues(alpha: alpha), 1.5);
  final heads = pair ? const [Offset.zero, Offset(14, -3)] : const [Offset.zero];
  for (final h in heads) {
    c.save();
    c.translate(h.dx, h.dy);
    c.rotate(-.38);
    // The fill sits a little off the outline, like a marker colouring in.
    c.drawOval(
      Rect.fromCenter(center: Offset((r() - .5) * 1.6, (r() - .5) * 1.6), width: 12, height: 8.6),
      Paint()..color = fill.withValues(alpha: alpha),
    );
    final o = Path();
    _rellipse(o, 0, 0, 6, 4.2, r);
    c.drawPath(o, ink);
    c.restore();
  }
  final s = Path();
  for (final h in heads) {
    _rline(s, h.dx + 5.4, h.dy - 1.5, h.dx + 5.4 + (r() - .5) * 1.4, h.dy - 23, r, .6);
  }
  if (pair) {
    for (var k = 0; k < 3; k++) {
      _rline(s, 5.4, -23 + k * 1.6, 19.4, -26 + k * 1.6, r, .45);
    }
  } else {
    s
      ..moveTo(5.4, -23)
      ..quadraticBezierTo(14 + (r() - .5) * 2.4, -19, 12 + (r() - .5) * 2.4, -10);
  }
  c.drawPath(s, ink);
}

/// The notes, in the page's own space (drawn under the polaroid): each slips out from
/// behind the polaroid's top-right corner, then drifts up and away to the right through
/// the open space above the song, swaying, and fades.
class _NotesPainter extends CustomPainter {
  _NotesPainter(this.k) : super(repaint: k);
  final _SkClock k;

  static const _fills = [_C.violet, _C.yellow, _C.blue, _C.orange];

  /// Top of the "now playing" line in this painter's space (null before layout).
  double? _headTop() {
    final stage = k.stageKey.currentContext?.findRenderObject();
    final head = k.headKey.currentContext?.findRenderObject();
    if (stage is! RenderBox || head is! RenderBox || !stage.hasSize || !head.attached) return null;
    return head.localToGlobal(Offset.zero, ancestor: stage).dy;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (k.notes.isEmpty) return;
    final side = math.min(size.height, _artMax);
    final top = (size.height - side) / 2;
    // Note heads stay between just under the top bar and just over the song's first line.
    const ceil = 18.0;
    final floor = math.max(ceil + 8, (_headTop() ?? 64) - 9);
    for (final n in k.notes) {
      final age = k.t - n.born;
      final p = (age / _noteLife).clamp(0.0, 1.0);
      double rr(int salt) => _rnd(n.id * 31 + salt);
      final scale = 1.05 + .3 * rr(1);
      final out = Curves.easeOutCubic.transform((p * 4).clamp(0.0, 1.0)); // out from behind
      final y0 = math.min(floor, top + 36 + 12 * rr(2));
      final y = y0 - (y0 - ceil - 10 * rr(3)) * Curves.easeOut.transform(p) + 3.5 * math.sin(age * 2.4 + rr(4) * 6);
      final x = side - 12 + 30 * out + (70 + 230 * rr(5)) * Curves.easeInOut.transform(p);
      final alpha = math.min((p / .08).clamp(0.0, 1.0), ((1 - p) / .32).clamp(0.0, 1.0));
      if (alpha <= .01) continue;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate((rr(6) - .5) * .5 + .14 * math.sin(age * 2.1 + rr(7) * 6));
      canvas.scale(scale);
      _drawNote(
        canvas,
        _Rng(n.id * 977 + k.frame * 131),
        pair: rr(8) < .4,
        fill: _fc(_fills[(rr(9) * _fills.length).floor() % _fills.length]),
        alpha: alpha,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_NotesPainter o) => o.k != k;
}

/// A scribbled sound wave next to the buttons: a jagged double stroke whose loudness
/// wanders like real music; it flattens and fades out on pause.
class _ScribblePainter extends CustomPainter {
  _ScribblePainter(this.k) : super(repaint: k);
  final _SkClock k;

  @override
  void paint(Canvas canvas, Size size) {
    if (k.e <= 0 || size.width < 40) return;
    final w = math.min(size.width, 260.0), mid = size.height / 2;
    final r = _Rng(4049 + k.frame * 17);
    final p = Path();
    for (var pass = 0; pass < 2; pass++) {
      for (var x = 2.0; x <= w - 2; x += 3) {
        final taper = math.min(1.0, math.min(x / 30, (w - x) / 30));
        final loud = .25 + .75 * _vnoise(x / 40 + k.t * 1.6) * (.55 + .45 * _vnoise(k.t * 2.2 + 9));
        final y = mid +
            size.height * .4 * k.e * taper * loud * math.sin(x * .27 - k.t * 6 + pass * .5) +
            (r() - .5) * 1.5;
        x == 2 ? p.moveTo(x, y) : p.lineTo(x, y);
      }
    }
    canvas.drawPath(p, _stroke(_sc(_C.violet).withValues(alpha: k.e), 1.8));
  }

  @override
  bool shouldRepaint(_ScribblePainter o) => o.k != k;
}

class _SkSeek extends StatefulWidget {
  const _SkSeek({required this.value, required this.onSeek, required this.enabled});
  final double value;
  final bool enabled;
  final ValueChanged<double> onSeek;
  @override
  State<_SkSeek> createState() => _SkSeekState();
}

class _SkSeekState extends State<_SkSeek> {
  double? _drag;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      double f(Offset p) => ((p.dx - 8) / (c.maxWidth - 16)).clamp(0.0, 1.0);
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
        child: SizedBox(
          height: 34,
          width: double.infinity,
          child: CustomPaint(painter: _SeekPainter(_drag ?? widget.value)),
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
    return Ticker(
      builder: (context, now) {
        final grade = switch (d.grade) {
          HotspotGrade.excellent || HotspotGrade.good => _C.green,
          HotspotGrade.fair => _C.orange,
          HotspotGrade.poor => _C.red,
          null => _C.gray,
        };
        final (down, downU) = hsBpsParts(d.rxBps);
        final (up, upU) = hsBpsParts(d.txBps);
        final (used, usedU) = hsBytesParts(d.cycleUsed);
        final q = d.quotaFrac;
        final heat = switch (d.heat) {
          HotspotHeat.hot => _C.red,
          HotspotHeat.warm => _C.orange,
          _ => _C.blue,
        };
        final temp = hsTemp(d.batteryC, fahrenheit: f);
        final sp = temp.lastIndexOf(' ');
        final batt = d.lowBattery ? _C.red : _C.green;
        Widget row(List<(int, Widget)> cells) => Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, (flex, w)) in cells.indexed) ...[
              if (i > 0) const SizedBox(width: _gap),
              Expanded(flex: flex, child: w),
            ],
          ],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: row([
                (124, _status(d, now)),
                (
                  100,
                  _cell(
                    'hsig',
                    'signal score',
                    trail: Text(_lc(hsGradeLabel(d.grade)), style: _s(14, w: 700, c: _sc(grade))),
                    [
                      _big(d.score == null ? '—' : '${d.score!.round()}', 42, unit: '/100', c: _sc(grade)),
                      const SizedBox(height: 4),
                      _Hb((d.score ?? 0) / 100, grade, k: 'hsig'),
                      const SizedBox(height: 6),
                      _note(hsSignalLine(d), lines: 2),
                    ],
                  ),
                ),
                (
                  112,
                  _cell('hspd', 'speed now', [
                    _big(down, 34, unit: '$downU down', c: _sc(_C.blue)),
                    _big(up, 34, unit: '$upU up', c: _sc(_C.violet)),
                    const SizedBox(height: 6),
                    _note(_lc(hsPingLine(d)), lines: 2),
                  ]),
                ),
                (
                  100,
                  _cell('hbat', 'battery', trail: Text(hsCurrent(d.currentMa), style: _noteS(13)), [
                    _big(d.batteryPct == null ? '—' : '${d.batteryPct!.round()}', 42, unit: '%', c: _sc(batt)),
                    const SizedBox(height: 4),
                    _Hb((d.batteryPct ?? 0) / 100, batt, k: 'hbat'),
                    const SizedBox(height: 6),
                    _note(hsPowerLine(d), lines: 2),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: _gap),
            Expanded(
              child: row([
                (
                  92,
                  _cell(
                    'htmp',
                    'temperature',
                    trail: d.radioResting ? Text('radio resting', style: _handS(14, _sc(_C.red))) : null,
                    [
                      _big(
                        sp < 0 ? temp : temp.substring(0, sp),
                        42,
                        unit: sp < 0 ? null : temp.substring(sp + 1),
                        c: _sc(heat),
                      ),
                      const SizedBox(height: 6),
                      _note(hsHeatLine(d, fahrenheit: f), lines: 3),
                    ],
                  ),
                ),
                (
                  104,
                  _cell(
                    'hdat',
                    'data this cycle',
                    [
                      _big(
                        used,
                        42,
                        unit: d.quota == null ? '$usedU, no quota' : '$usedU of ${hsBytes(d.quota)}',
                        c: _sc(_C.violet),
                      ),
                      if (q != null) ...[
                        const SizedBox(height: 4),
                        _Hb(q, q >= 1 ? _C.red : (q >= .8 ? _C.orange : _C.violet), k: 'hdat'),
                      ],
                      const SizedBox(height: 6),
                      _note(_lc(hsTodayLine(d)), lines: 2),
                    ],
                  ),
                ),
                (
                  100,
                  _cell('hup', 'uptime', [
                    _big(hsUptime(d.uptimeS), 36),
                    const SizedBox(height: 2),
                    _note('phone', size: 12),
                    const SizedBox(height: 6),
                    _note('agent ${hsUptime(d.agentUptimeS)}\n${_lc(hsBootLine(d))}', lines: 2),
                  ]),
                ),
                (140, _events(d, now)),
              ]),
            ),
          ],
        );
      },
    );
  }

  /// A plain rough box: heading (+ a note on the right), then [kids].
  Widget _cell(String seed, String title, List<Widget> kids, {Widget? trail}) => _bx(
    seed: seed,
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _hd(title)),
            if (trail != null) ...[const SizedBox(width: 6), trail],
          ],
        ),
        const SizedBox(height: 2),
        ...kids,
      ],
    ),
  );

  /// The status sticky: green when all is well, yellow on low battery, red otherwise.
  Widget _status(HotspotData d, DateTime now) {
    final st = hsState(d);
    final col = switch (st) {
      HsState.ok => _C.green,
      HsState.lowBattery => _C.yellow,
      _ => _C.red,
    };
    final ink = st == HsState.lowBattery ? _sc(_C.orange) : _sc(col);
    final alert = hsAlert(d, now);
    return _bx(
      seed: 'hstat',
      f: col,
      m: _Mode.solid,
      tilt: _tl,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _hd((d.name ?? 'phone').toLowerCase()),
                    _big(_lc(hsStateLabel(d)), 32, c: ink),
                    _note(_lc(hsSeen(d, now))),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(width: 40, height: 50, child: CustomPaint(painter: _PhoneDoodle(d.online, ink))),
            ],
          ),
          const SizedBox(height: 6),
          if (alert != null)
            Expanded(
              child: Text(_lc(alert), maxLines: 4, overflow: TextOverflow.ellipsis, style: _handS(15, _ink)),
            )
          else ...[
            _note([hsNetwork(d), ?d.operator].join(', ')),
            _note(_lc(hsSharing(d))),
            if (d.model != null) _note(d.model!, size: 12),
          ],
        ],
      ),
    );
  }

  /// Newest events, whole rows only, with pencil rules between them.
  Widget _events(HotspotData d, DateTime now) {
    final note = hsSessionNote(d, now);
    return _bx(
      seed: 'hev',
      pad: const EdgeInsets.fromLTRB(14, 12, 12, 8),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _hd('latest events'),
          Expanded(
            child: d.events.isEmpty
                ? Center(child: Text('nothing happened yet.', style: _handS(16)))
                : LayoutBuilder(
                    builder: (context, box) {
                      final shown = <HotspotEvent>[];
                      var used = 0.0;
                      for (final e in d.events) {
                        final tp = TextPainter(
                          text: TextSpan(text: e.message, style: _s(13, h: 1.3)),
                          maxLines: 2,
                          textDirection: TextDirection.ltr,
                        )..layout(maxWidth: box.maxWidth - 16 - 40);
                        final h = tp.height + 8 + (shown.isEmpty ? 0 : 6);
                        tp.dispose();
                        if (used + h > box.maxHeight && shown.isNotEmpty) break;
                        used += h;
                        shown.add(e);
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (i, e) in shown.indexed) ...[
                            if (i > 0) SizedBox(height: 6, child: CustomPaint(painter: _Rule(57 + i * 7))),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 1),
                                    child: SizedBox(
                                      width: 16,
                                      child: Text(
                                        e.severity == 'info' ? '·' : '!',
                                        style: _s(
                                          14,
                                          w: 700,
                                          c: e.severity == 'critical'
                                              ? _sc(_C.red)
                                              : (e.severity == 'warning' ? _sc(_C.orange) : _mut),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      e.message,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: _s(13, h: 1.3, c: e.severity == 'info' ? _ink : _sc(_C.orange)),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 40,
                                    child: Text(
                                      slackTime(e.ts, now).toLowerCase(),
                                      textAlign: TextAlign.right,
                                      maxLines: 1,
                                      style: _noteS(12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
          ),
          if (note != null)
            Text(_lc(note), maxLines: 1, overflow: TextOverflow.ellipsis, style: _handS(14, _sc(_C.orange))),
        ],
      ),
    );
  }
}

/// Lower-cases the first letter ("Seen 4m ago" -> "seen 4m ago"), the sketch's voice.
String _lc(String s) => s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

/// A doodled phone with signal arcs (a cross when it is offline).
class _PhoneDoodle extends CustomPainter {
  const _PhoneDoodle(this.online, this.col);
  final bool online;
  final Color col;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final r = _Rng(9071);
    final body = Path();
    _rrect(body, w * .08, h * .3, w * .42, h * .66, r);
    _rline(body, w * .22, h * .87, w * .36, h * .87, r, .4);
    canvas.drawPath(body, _stroke(_ink, 1.5));
    final s = Path();
    if (online) {
      for (final k in [.16, .26, .36]) {
        for (var pass = 0; pass < 2; pass++) {
          final j = (r() - .5) * 1.6;
          s.addArc(
            Rect.fromCircle(center: Offset(w * .29, h * .32), radius: w * k + j),
            -math.pi * .82 + (r() - .5) * .1,
            math.pi * .64,
          );
        }
      }
    } else {
      _rline(s, w * .6, h * .05, w * .95, h * .38, r, .8);
      _rline(s, w * .95, h * .05, w * .6, h * .38, r, .8);
    }
    canvas.drawPath(s, _stroke(col, 2));
  }

  @override
  bool shouldRepaint(_PhoneDoodle o) => o.online != online || o.col != col;
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
        final s = st.sessions;
        return Row(
          children: [
            LayoutBuilder(
              builder: (context, c) {
                final side = math.min(c.maxHeight, 330.0);
                return SizedBox(
                  width: side,
                  height: side,
                  child: Stack(
                    children: [
                      Positioned.fill(child: CustomPaint(painter: _Pie(st.progress(now), _C.red, 'timer'))),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xD9FFFFFF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: side * .8),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(digits, style: _bigS(64)),
                                ),
                              ),
                              _note(st.mode.label.toLowerCase()),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(width: 26),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _tabs(
                    [for (final m in TimerMode.values) m.label],
                    st.mode.index,
                    (i) => ctl.setMode(TimerMode.values[i]),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _btn(
                        label,
                        icon: st.running ? 'pause' : 'play',
                        f: _C.green,
                        height: 48,
                        hpad: 26,
                        fs: 16,
                        onTap: ctl.toggle,
                      ),
                      const SizedBox(width: 10),
                      _btn('Reset', height: 48, onTap: ctl.reset),
                      if (st.mode == TimerMode.countdown && !st.running) ...[
                        const SizedBox(width: 18),
                        _btn('−', width: 38, onTap: () => ctl.adjust(-1)),
                        const SizedBox(width: 8),
                        Text('${st.countdownMin} min', style: _s(14, w: 650)),
                        const SizedBox(width: 8),
                        _btn('+', width: 38, onTap: () => ctl.adjust(1)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '$s of 4 focus sessions done today.${s >= 4 ? ' all done!' : (s >= 2 ? ' halfway there!' : '')}',
                    style: _handS(15),
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

/// Doodled avatar: a wobbly circle washed in the sender's colour, initials in ink.
class _Face extends CustomPainter {
  _Face(this.seed, this.color);
  final String seed;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final r = _Rng(_hash(seed) + w.round());
    final o = Path();
    _rellipse(o, w / 2, h / 2, w / 2 - 3, h / 2 - 3, r);
    canvas.drawPath(o, Paint()..color = color.withValues(alpha: .38));
    canvas.drawPath(o, _stroke(_ink, 1.5));
  }

  @override
  bool shouldRepaint(_Face o) => o.seed != seed || o.color != color;
}

/// A big green hand-drawn tick for "all caught up".
class _Tick extends CustomPainter {
  const _Tick();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final r = _Rng(4242);
    final p = Path();
    _rline(p, w * .12, h * .55, w * .4, h * .85, r, 1.2);
    _rline(p, w * .4, h * .85, w * .9, h * .12, r, 1.2);
    canvas.drawPath(p, _stroke(_sc(_C.green), 4));
  }

  @override
  bool shouldRepaint(_Tick o) => false;
}

/// A wobbly pencil rule between list rows.
class _Rule extends CustomPainter {
  const _Rule(this.seed);
  final int seed;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Path();
    _rline(p, 2, size.height / 2, size.width - 2, size.height / 2, _Rng(seed), .8);
    canvas.drawPath(p, _stroke(const Color(0xFFADB5BD), 1.1));
  }

  @override
  bool shouldRepaint(_Rule o) => o.seed != seed;
}

Widget _face(SlackMsg m, double size) => SizedBox(
  width: size,
  height: size,
  child: CustomPaint(
    painter: _Face('f${m.sender}', hex(m.senderColor, _sc(_C.blue))),
    child: Center(child: Text(m.initials, style: _s(size * .34, w: 700, h: 1))),
  ),
);

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
    final red = _sc(_C.red);
    return Ticker(
      builder: (context, now) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 50,
                  child: Row(
                    children: [
                      _big(s.unread == 0 ? '0' : '${s.unread}', 46, c: s.unread == 0 ? _sc(_C.green) : red, fit: false),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.unread == 0 ? 'unread, nice' : 'unread',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _s(17, w: 700, h: 1.15),
                            ),
                            _note('in ${(s.team ?? 'slack').toLowerCase()}'),
                          ],
                        ),
                      ),
                      if (s.unread > 0)
                        _btn(
                          'mark all read',
                          f: _C.green,
                          height: 34,
                          hpad: 12,
                          fs: 13,
                          onTap: () => slackReadAll(context, ref),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(child: top == null ? _caughtUp(s, now) : _sticky(context, ref, top, now)),
              ],
            ),
          ),
          const SizedBox(width: _gap),
          Expanded(
            flex: 112,
            child: _bx(
              seed: 'slist',
              pad: const EdgeInsets.fromLTRB(14, 12, 12, 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _hd(top == null ? 'inbox, tap one to open in slack' : 'the rest of the inbox'),
                  const SizedBox(height: 4),
                  Expanded(
                    child: rest.isEmpty
                        ? Center(
                            child: Text(
                              s.messages.isEmpty ? 'no messages yet.\nenjoy the quiet!' : 'that\'s everything.',
                              textAlign: TextAlign.center,
                              style: _handS(17),
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: rest.length,
                            itemBuilder: (context, i) => _row(context, ref, rest[i], now, i),
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

  /// The newest unread message as a yellow sticky note.
  Widget _sticky(BuildContext context, WidgetRef ref, SlackMsg m, DateTime now) => _bx(
    seed: 'sticky',
    f: _C.yellow,
    m: _Mode.solid,
    tilt: _tl,
    pad: const EdgeInsets.fromLTRB(18, 14, 18, 12),
    onTap: () => slackOpen(context, ref, m),
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _face(m, 44),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.sender, maxLines: 1, overflow: TextOverflow.ellipsis, style: _s(20, w: 700, h: 1.15)),
                  _note('${slackWhere(m).toLowerCase()}, ${slackTime(m.ts, now).toLowerCase()}'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Align(
            alignment: Alignment.topLeft,
            child: Text(
              m.text,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: _handS(23, _ink).copyWith(height: 1.3),
            ),
          ),
        ),
        Row(
          children: [
            _btn('mark read', height: 32, hpad: 12, fs: 13, onTap: () => slackMarkRead(context, ref, m)),
            const Spacer(),
            Flexible(
              flex: 3,
              child: Text('tap to open in slack →', maxLines: 1, overflow: TextOverflow.ellipsis, style: _handS(13)),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _caughtUp(SlackData s, DateTime now) {
    final last = s.messages.isEmpty ? null : s.messages.first;
    return _bx(
      seed: 'caught',
      f: _C.green,
      m: _Mode.hach,
      tilt: _tr,
      Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 72, height: 60, child: CustomPaint(painter: _Tick())),
            const SizedBox(height: 8),
            Text('all caught up!', style: _handS(26, _ink)),
            const SizedBox(height: 4),
            _note(
              last == null
                  ? 'nothing new, go make something'
                  : 'last one from ${last.sender}, ${slackTime(last.ts, now).toLowerCase()}',
              align: TextAlign.center,
              lines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, SlackMsg m, DateTime now, int i) => Press(
    onTap: () => slackOpen(context, ref, m),
    scale: .985,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (i > 0) SizedBox(height: 6, child: CustomPaint(painter: _Rule(31 + i * 7))),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Opacity(
            opacity: m.unread ? 1 : .5,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _face(m, 36),
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
                                    style: _s(14, w: m.unread ? 700 : 500),
                                  ),
                                  TextSpan(text: '  ${slackWhere(m).toLowerCase()}', style: _noteS(12)),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            slackTime(m.ts, now).toLowerCase(),
                            style: _s(12, c: m.unread ? _sc(_C.red) : _mut, w: m.unread ? 650 : 450),
                          ),
                        ],
                      ),
                      Text(m.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: _s(13, h: 1.3)),
                    ],
                  ),
                ),
                Transform.translate(
                  offset: const Offset(4, -2),
                  child: SlackReadTick(m, color: _ink, fill: _sc(_C.green), onFill: _ink, radius: 5, size: 25),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

// ------------------------------------------------------------------ GitHub

class _Github extends ConsumerWidget {
  const _Github();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = topicData<GithubData>(ref, codeTopic(ref))!;
    final today = DateTime.now().weekday % 7;
    final green = _sc(_C.green);
    final week = [for (var i = 0; i < 7; i++) ((i < g.thisWeek.length ? g.thisWeek[i] : null) ?? 0).toDouble()];
    final mx = maxOf([...g.thisWeek, ...g.lastWeek]) * 1.15;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: _tabs(codeSources, ref.watch(codeSourceProvider), ref.read(codeSourceProvider.notifier).set),
        ),
        const SizedBox(height: _gap),
        _bx(
          seed: 'heat',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _hd('contributions, last 12 months'),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _note(
                      '${_thousands(g.total)} total, ${g.commits} commits, ${g.private} private',
                      align: TextAlign.right,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LayoutBuilder(
                builder: (context, c) {
                  // Capped below the full-width cell size to leave room for the source switch.
                  final cw = math.min(c.maxWidth / 53, 11.0);
                  return Center(
                    child: SizedBox(
                      width: 53 * cw,
                      height: 14 + 7 * cw,
                      child: CustomPaint(painter: _Heat(g.weeks)),
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
                flex: 80,
                child: _bx(
                  seed: 'str',
                  f: _C.green,
                  m: _Mode.solid,
                  tilt: _tl,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _hd('streak'),
                      _big('${g.streakCurrent}', 72, unit: g.streakCurrent == 1 ? 'day' : 'days', c: green),
                      const Spacer(),
                      _note(
                        'longest ${g.streakLongest}.'
                        '${g.bestDay == null ? '' : ' best day ${g.bestDay!.count} on ${month3(g.bestDay!.date)} ${g.bestDay!.date.day}.'}',
                        lines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: _gap),
              Expanded(
                flex: 110,
                child: _bx(
                  seed: 'wk',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(text: 'this week: '),
                                TextSpan(text: '${g.weekTotal}', style: _s(13, w: 700)),
                              ],
                            ),
                            style: _hdS,
                          ),
                          const Spacer(),
                          Text(
                            '${g.weekDelta >= 0 ? '+' : ''}${g.weekDelta} vs last week${g.weekDelta > 0 ? '!' : ''}',
                            style: _handS(13, g.weekDelta >= 0 ? green : _mut),
                          ),
                        ],
                      ),
                      Expanded(
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: _Bars(
                            'wk',
                            week,
                            mx,
                            [for (final ch in 'smtwtfs'.split('')) ch],
                            [for (var i = 0; i < 7; i++) i == today ? _C.violet : _C.green],
                            top: 22,
                            widthK: .56,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: _gap),
              Expanded(
                flex: 100,
                child: _bx(
                  seed: 'rep',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _hd(topReposLabel(ref).toLowerCase()),
                      for (final r in g.topRepos.take(4))
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _s(14)),
                              ),
                              Text('${r.count}', style: _s(14, w: 700)),
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

/// Contribution calendar: slightly rotated green squares, grey specks for empty days.
class _Heat extends CustomPainter {
  _Heat(this.weeks);
  final List<List<ContribDay>> weeks;
  static const _lv = [Color(0xFFD3F9D8), Color(0xFF8CE99A), Color(0xFF40C057), Color(0xFF2B8A3E)];

  @override
  void paint(Canvas canvas, Size size) {
    final ws = weeks.length > 53 ? weeks.sublist(weeks.length - 53) : weeks;
    final cw = size.width / 53;
    const top = 14.0;
    final r = _Rng(31);
    final label = _s(11, c: _mut, h: 1);
    for (var x = 1; x < ws.length - 1; x++) {
      if (ws[x].isEmpty || ws[x - 1].isEmpty) continue;
      if (ws[x].first.date.month != ws[x - 1].first.date.month) {
        _text(canvas, month3(ws[x].first.date).toLowerCase(), x * cw, 10, label);
      }
    }
    final speck = Paint()..color = const Color(0xFFCED4DA);
    for (var x = 0; x < ws.length; x++) {
      for (final day in ws[x]) {
        final y = day.date.weekday % 7;
        final k = cw - 3;
        final px = x * cw + 1 + (r() - .5), py = top + y * cw + 1 + (r() - .5);
        if (day.level <= 0) {
          canvas.drawCircle(Offset(px + k / 2, py + k / 2), 1.2, speck);
          continue;
        }
        final rot = (r() - .5) * 8 * math.pi / 180;
        canvas.save();
        canvas.translate(px + k / 2, py + k / 2);
        canvas.rotate(rot);
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: k, height: k), const Radius.circular(2)),
          Paint()..color = _lv[(day.level - 1).clamp(0, 3)],
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_Heat o) => o.weeks != weeks;
}

// ------------------------------------------------------------------ Shortcuts

class _Shortcuts extends ConsumerWidget {
  const _Shortcuts();

  static _C _col(Tile t, int i) => switch (t.id) {
    'mic.toggle' => _C.red,
    'sound.toggle' => _C.orange,
    'volume.down' || 'volume.up' => _C.blue,
    'screenshot' => _C.violet,
    'terminal' => _C.gray,
    'downloads' => _C.yellow,
    'lock' => _C.green,
    _ => const [_C.blue, _C.green, _C.violet, _C.orange, _C.yellow, _C.gray][i % 6],
  };

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
          if (ri > 0) const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(width: 16),
                  Expanded(
                    child: i < row.length ? _key(context, ref, row[i], ri * 4 + i, s.volumePct) : const SizedBox(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _key(BuildContext context, WidgetRef ref, Tile t, int i, int? vol) {
    final on = t.active;
    final fg = on ? _sc(_C.red) : _ink;
    final small = t.id.startsWith('volume') && vol != null ? 'now $vol%' : t.detail?.toLowerCase();
    return _bx(
      seed: 'k${t.id}$on',
      f: on ? _C.red : _col(t, i),
      m: on ? _Mode.solid : _Mode.hach,
      s: on ? _C.red : _C.ink,
      tilt: i % 3 == 0 ? _tl : (i % 3 == 1 ? _tr : 0),
      onTap: () => act(context, ref, 'shortcut.run', {'id': t.id}),
      Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DpIcon(tileIcon(t), size: 36, color: fg, stroke: 1.8),
            const SizedBox(height: 8),
            Text(
              tileLabel(t),
              textAlign: TextAlign.center,
              style: _s(15, w: 650, c: fg),
            ),
            if (small != null) Text(small, style: _s(12, c: _mut)),
          ],
        ),
      ),
    );
  }
}
