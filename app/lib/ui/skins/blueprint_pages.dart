// Concept 7 — Blueprint pages. Sizes follow deskpanel-concept-7-blueprint.html (CSS px = logical px).
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/conn/controller.dart';
import '../../core/pages.dart';
import '../../core/settings.dart';
import '../fmt.dart';
import '../icons.dart';
import '../pages/kit.dart';
import '../widgets/anim.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import 'blueprint.dart';

const _bp = BlueprintSkin.bp;
const _ln = BlueprintSkin.ln;
const _ln2 = BlueprintSkin.ln2;
const _ln3 = BlueprintSkin.ln3;
const _cy = BlueprintSkin.cy;
const _red = BlueprintSkin.red;
const _colGap = 18.0;
const _rowGap = 12.0;
const _clear = Color(0x00000000);

Widget blueprintPage(PageId id) => switch (id) {
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

// ------------------------------------------------------------------ type + small parts

TextStyle _s(double size, {FontWeight w = FontWeight.w500, Color c = _ln, double? h, double? ls}) => TextStyle(
  fontFamily: BlueprintSkin.sans,
  fontSize: size,
  fontWeight: w,
  color: c,
  height: h,
  letterSpacing: ls,
  fontFeatures: const [FontFeature.tabularFigures()],
);

TextStyle _m(double size, {FontWeight w = FontWeight.w500, Color c = _ln, double? h, double? ls}) =>
    BlueprintSkin.m(size, w: w, c: c, h: h, ls: ls);

/// `.note`: small mono annotation.
Widget _note(String s, {TextAlign? align, int lines = 1, Color c = _ln2}) => Text(
  s,
  style: _m(10.5, h: 1.5, c: c),
  textAlign: align,
  maxLines: lines,
  overflow: TextOverflow.ellipsis,
);

TextStyle _bigStyle(double size, [Color c = _ln]) => _s(size, w: FontWeight.w800, c: c, ls: -.02 * size, h: .86);

/// `.big` number with a small unit (`<small>`).
Widget _big(String v, String unit, double size, {Color c = _ln}) => Row(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.baseline,
  textBaseline: TextBaseline.alphabetic,
  children: [
    Text(v, style: _bigStyle(size, c)),
    if (unit.isNotEmpty) ...[
      const SizedBox(width: 3),
      Text(
        unit,
        style: _s(size * .36, w: FontWeight.w600, c: _ln2, h: .86),
      ),
    ],
  ],
);

/// Animated `.big` number.
Widget _bigNum(double? v, String unit, double size, {Color c = _ln, int decimals = 0}) => v == null
    ? _big('—', '', size, c: _ln2)
    : Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          AnimNum(v, style: _bigStyle(size, c), decimals: decimals),
          if (unit.isNotEmpty) ...[
            const SizedBox(width: 3),
            Text(
              unit,
              style: _s(size * .36, w: FontWeight.w600, c: _ln2, h: .86),
            ),
          ],
        ],
      );

/// `.dwg`: a titled drawing.
Widget _dwg(String title, List<Widget> kids, {String? sub, Color color = _ln}) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    BpTitle(title, sub: sub, color: color),
    ...kids,
  ],
);

String _lower(String s) => s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

String _inText(CalEvent e, DateTime now) {
  if (!e.start.isAfter(now)) return 'now';
  final d = e.start.difference(now);
  return d.inMinutes < 1 ? 'starting' : 'in ${dur(d)}';
}

/// Drafting table (`.tbl`): header rule 1.5 px, light row rules.
Widget _table(
  List<List<Widget>> rows, {
  List<String>? head,
  Set<int> right = const {},
  Map<int, TableColumnWidth>? widths,
  double padV = 5,
}) {
  final n = head?.length ?? (rows.isEmpty ? 0 : rows.first.length);
  if (n == 0) return const SizedBox();
  Widget cell(Widget w, int i, {bool th = false}) => Padding(
    padding: EdgeInsets.fromLTRB(0, th ? 0 : padV, right.contains(i) ? 0 : 8, th ? 4 : padV),
    child: Align(alignment: right.contains(i) ? Alignment.centerRight : Alignment.centerLeft, child: w),
  );
  return Table(
    columnWidths:
        widths ?? {for (var i = 0; i < n; i++) i: i == 0 ? const FlexColumnWidth() : const IntrinsicColumnWidth()},
    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
    children: [
      if (head != null)
        TableRow(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _ln, width: 1.5)),
          ),
          children: [
            for (final (i, h) in head.indexed)
              cell(
                Text(
                  h,
                  maxLines: 1,
                  style: _m(10, w: FontWeight.w600, c: _ln2, ls: .4),
                ),
                i,
                th: true,
              ),
          ],
        ),
      for (final r in rows)
        TableRow(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _ln3)),
          ),
          children: [for (final (i, w) in r.indexed) cell(w, i)],
        ),
    ],
  );
}

Widget _td(String s, {bool mono = false, bool bold = false, Color c = _ln}) => Text(
  s,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  style: mono ? _m(12.5, c: c) : _s(12.5, w: bold ? FontWeight.w700 : FontWeight.w500, c: c),
);

// ------------------------------------------------------------------ canvas helpers

void _text(Canvas c, String s, double x, double baseline, TextStyle st, {TextAlign align = TextAlign.left, Color? bg}) {
  final tp = TextPainter(
    text: TextSpan(text: s, style: st),
    textDirection: TextDirection.ltr,
  )..layout();
  final bl = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  final dx = switch (align) {
    TextAlign.center => x - tp.width / 2,
    TextAlign.right || TextAlign.end => x - tp.width,
    _ => x,
  };
  if (bg != null) {
    _fill(c, bg, Rect.fromLTWH(dx - 4, baseline - bl, tp.width + 8, tp.height));
  }
  tp.paint(c, Offset(dx, baseline - bl));
}

void _fill(Canvas c, Color col, Rect r) => c.drawRect(r, Paint()..color = col);

double _textW(String s, TextStyle st) => (TextPainter(
  text: TextSpan(text: s, style: st),
  textDirection: TextDirection.ltr,
)..layout()).width;

Paint _stroke(Color c, [double w = 1]) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w;

/// Diagonal hatching clipped to [clip]. `back` = "\\\" lines, else "///".
void _hatch(Canvas c, Path clip, Color col, {double gap = 5, bool back = true, double w = 1}) {
  final r = clip.getBounds();
  if (r.width <= 0 || r.height <= 0) return;
  c.save();
  c.clipPath(clip);
  final p = Paint()
    ..color = col
    ..strokeWidth = w;
  final step = gap * math.sqrt2, h = r.height;
  for (var x = r.left - h; x < r.right + h; x += step) {
    if (back) {
      c.drawLine(Offset(x, r.top), Offset(x + h, r.bottom), p);
    } else {
      c.drawLine(Offset(x + h, r.top), Offset(x, r.bottom), p);
    }
  }
  c.restore();
}

Path _dash(Path src, List<double> pat) {
  final out = Path();
  for (final m in src.computeMetrics()) {
    var d = 0.0;
    var i = 0;
    while (d < m.length) {
      final len = pat[i % pat.length];
      if (i.isEven) out.addPath(m.extractPath(d, math.min(d + len, m.length)), Offset.zero);
      d += len;
      i++;
    }
  }
  return out;
}

void _line(Canvas c, Offset a, Offset b, Paint p, [List<double>? dash]) {
  if (dash == null) {
    c.drawLine(a, b, p);
  } else {
    c.drawPath(
      _dash(
        Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy),
        dash,
      ),
      p,
    );
  }
}

/// Smooth line through the non-null values (breaks at gaps).
Path _smooth(List<double?> vals, double Function(int) x, double Function(double) y) {
  final p = Path();
  var pen = false;
  double px = 0, py = 0;
  for (var i = 0; i < vals.length; i++) {
    final v = vals[i];
    if (v == null) {
      pen = false;
      continue;
    }
    final nx = x(i), ny = y(v);
    if (!pen) {
      p.moveTo(nx, ny);
      pen = true;
    } else {
      final xm = (px + nx) / 2;
      p.cubicTo(xm, py, xm, ny, nx, ny);
    }
    px = nx;
    py = ny;
  }
  return p;
}

/// Chart axes with ticks (`axes()` in the concept).
void _axes(Canvas c, Size s, double l, double b, List<(String, double)> yt, List<(String, double)> xt) {
  final w = s.width, h = s.height;
  final p = _stroke(_ln, 1.2);
  c.drawLine(Offset(l, 0), Offset(l, h - b), p);
  c.drawLine(Offset(l, h - b), Offset(w, h - b), p);
  final t = _stroke(_ln);
  for (final (v, y) in yt) {
    c.drawLine(Offset(l - 4, y), Offset(l, y), t);
    _text(c, v, l - 7, y + 3, _m(9, c: _ln2), align: TextAlign.right);
  }
  for (final (v, x) in xt) {
    c.drawLine(Offset(x, h - b), Offset(x, h - b + 4), t);
    _text(c, v, x, h - b + 14, _m(9, c: _ln2), align: TextAlign.center);
  }
}

/// A revision cloud along the rectangle inset by [m].
Path _cloudPath(Size s, {double r = 7, double m = 4}) {
  final w = s.width, h = s.height;
  final pts = [Offset(m, m), Offset(w - m, m), Offset(w - m, h - m), Offset(m, h - m), Offset(m, m)];
  final d = Path()..moveTo(m, m);
  for (var k = 0; k < 4; k++) {
    final a = pts[k], b = pts[k + 1];
    final len = (b - a).distance;
    final n = math.max(1, (len / (2 * r)).round());
    final rr = len / n / 2 + .5;
    for (var i = 1; i <= n; i++) {
      d.arcToPoint(Offset.lerp(a, b, i / n)!, radius: Radius.circular(rr));
    }
  }
  return d;
}

// ------------------------------------------------------------------ widgets

/// Dimension bar: a hatched part with a dimension line measuring the filled length.
class _Dim extends StatelessWidget {
  const _Dim(
    this.value,
    this.label, {
    this.red = false,
    this.part = true,
    this.height = 36,
    this.dlTop = 4,
    this.labelTop = -7,
    this.ticks = 0,
    this.tone,
  });
  final double value;
  final String label;
  final bool red, part;
  final double height, dlTop, labelTop;

  /// Hatch colour overriding [red] (e.g. the amber warning tone).
  final Color? tone;

  /// Divide the part into this many equal units (a count, not a percentage); 0 = none.
  final int ticks;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: value.isNaN ? 0 : value.clamp(0.0, 1.0)),
    duration: const Duration(milliseconds: 600),
    curve: Curves.easeOut,
    builder: (context, v, _) => SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _DimPainter(v, label, red, part, dlTop, labelTop, ticks, tone)),
    ),
  );
}

class _DimPainter extends CustomPainter {
  _DimPainter(this.p, this.label, this.red, this.part, this.dlTop, this.labelTop, this.ticks, this.tone);
  final double p, dlTop, labelTop;
  final String label;
  final bool red, part;
  final int ticks;
  final Color? tone;

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height, x1 = w * p;
    if (part) {
      final box = Rect.fromLTWH(.6, h - 12, w - 1.2, 11.4);
      if (x1 > 0) _hatch(c, Path()..addRect(Rect.fromLTWH(0, h - 12, x1, 12)), tone ?? (red ? _red : _ln2));
      // Unit divisions, like the graduations on a scale.
      for (var i = 1; i < ticks; i++) {
        final x = w * i / ticks;
        c.drawLine(Offset(x, h - 12), Offset(x, h), _stroke(_ln2, .8));
      }
      c.drawRect(box, _stroke(_ln, 1.2));
      if (x1 > 0) c.drawLine(Offset(x1, h - 12), Offset(x1, h), _stroke(_ln, 1.2));
    }
    // Dimension line with extension lines and arrowheads.
    final ext = _stroke(_cy);
    c.drawLine(Offset(.5, dlTop), Offset(.5, dlTop + 16), ext);
    c.drawLine(Offset(math.max(x1 - .5, .5), dlTop), Offset(math.max(x1 - .5, .5), dlTop + 16), ext);
    c.drawLine(Offset(0, dlTop + 5.5), Offset(x1, dlTop + 5.5), ext);
    final y0 = dlTop + 2;
    final f = Paint()..color = _cy;
    if (x1 > 14) {
      c.drawPath(
        Path()
          ..moveTo(1, y0)
          ..lineTo(8, y0 + 3.5)
          ..lineTo(1, y0 + 7)
          ..close(),
        f,
      );
      c.drawPath(
        Path()
          ..moveTo(x1 - 1, y0)
          ..lineTo(x1 - 8, y0 + 3.5)
          ..lineTo(x1 - 1, y0 + 7)
          ..close(),
        f,
      );
    }
    // Value label, centred over the dimension line.
    final st = _m(11, w: FontWeight.w600, c: _cy);
    final tw = _textW(label, st);
    final cx = (x1 / 2).clamp(tw / 2 + 4, math.max(tw / 2 + 4, w - tw / 2 - 4)).toDouble();
    _text(c, label, cx, labelTop + 11.5, st, align: TextAlign.center, bg: _bp);
  }

  @override
  bool shouldRepaint(_DimPainter o) =>
      o.p != p || o.label != label || o.red != red || o.ticks != ticks || o.tone != tone;
}

/// Seekable dimension bar for the music page.
class _SeekDim extends StatefulWidget {
  const _SeekDim({required this.value, required this.label, required this.onSeek, required this.enabled});
  final double value;
  final String label;
  final bool enabled;
  final ValueChanged<double> onSeek;
  @override
  State<_SeekDim> createState() => _SeekDimState();
}

class _SeekDimState extends State<_SeekDim> {
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
        child: Padding(padding: const EdgeInsets.only(top: 8), child: _Dim(_drag ?? widget.value, widget.label)),
      );
    },
  );
}

/// Red revision cloud around [child] (`.cloudw`).
class _Cloud extends StatelessWidget {
  const _Cloud({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: const _CloudPainter(_red),
    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: child),
  );
}

class _CloudPainter extends CustomPainter {
  const _CloudPainter(this.c);
  final Color c;
  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(_cloudPath(size), _stroke(c, 1.4));
  @override
  bool shouldRepaint(_CloudPainter o) => o.c != c;
}

/// Revision triangle with a number (`.tri`).
class _Tri extends StatelessWidget {
  const _Tri(this.n);
  final String n;
  @override
  Widget build(BuildContext context) => Container(
    width: 18,
    height: 16,
    margin: const EdgeInsets.only(right: 4),
    alignment: Alignment.bottomCenter,
    child: CustomPaint(
      painter: const _TriPainter(),
      child: SizedBox(
        width: 18,
        height: 16,
        child: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            n,
            textAlign: TextAlign.center,
            style: _m(9, w: FontWeight.w700, c: _red, h: 1.2),
          ),
        ),
      ),
    ),
  );
}

class _TriPainter extends CustomPainter {
  const _TriPainter();
  @override
  void paint(Canvas c, Size s) => c.drawPath(
    Path()
      ..moveTo(9, 1)
      ..lineTo(17, 15)
      ..lineTo(1, 15)
      ..close(),
    _stroke(_red, 1.4),
  );
  @override
  bool shouldRepaint(_TriPainter o) => false;
}

/// Drafting outline button with construction corner marks (`.btn`).
class _Btn extends StatelessWidget {
  const _Btn({
    this.label,
    this.child,
    this.onTap,
    this.pressed = false,
    this.height = 34,
    this.padH = 16,
    this.size = 12.5,
  });
  final String? label;
  final Widget? child;
  final VoidCallback? onTap;
  final bool pressed;
  final double height, padH, size;

  @override
  Widget build(BuildContext context) {
    final fg = pressed ? _bp : _ln;
    final body = Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: padH),
      decoration: BoxDecoration(
        color: pressed ? _ln : _clear,
        border: Border.all(color: _ln, width: 1.5),
      ),
      child: DefaultTextStyle(
        style: _s(size, w: FontWeight.w700, c: fg),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Flexible(child: child ?? Text(label ?? '', maxLines: 1))],
        ),
      ),
    );
    return Press(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? .6 : 1,
        child: CustomPaint(foregroundPainter: const _Corners(), child: body),
      ),
    );
  }
}

class _Corners extends CustomPainter {
  const _Corners();
  @override
  void paint(Canvas c, Size s) {
    final p = _stroke(_cy, 1.5);
    c.drawPath(
      Path()
        ..moveTo(-4.25, 1)
        ..lineTo(-4.25, -4.25)
        ..lineTo(1, -4.25),
      p,
    );
    c.drawPath(
      Path()
        ..moveTo(s.width + 4.25, s.height - 1)
        ..lineTo(s.width + 4.25, s.height + 4.25)
        ..lineTo(s.width - 1, s.height + 4.25),
      p,
    );
  }

  @override
  bool shouldRepaint(_Corners o) => false;
}

/// Round outline button (`.bub`); [main] is filled.
Widget _bub(String icon, VoidCallback? onTap, {double size = 46, bool main = false, double? iconSize}) => Press(
  onTap: onTap,
  child: Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: main ? _ln : _clear,
      border: Border.all(color: _ln, width: 1.5),
    ),
    alignment: Alignment.center,
    child: DpIcon(icon, size: iconSize ?? (main ? 22 : size * 17 / 46), color: main ? _bp : _ln),
  ),
);

/// Line-art frame with drafting centre marks (`.frame`).
class _Frame extends StatelessWidget {
  const _Frame({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: const _CentreMarks(),
    child: Container(
      decoration: BoxDecoration(border: Border.all(color: _ln, width: 1.5)),
      child: child,
    ),
  );
}

class _CentreMarks extends CustomPainter {
  const _CentreMarks();
  @override
  void paint(Canvas c, Size s) {
    final p = _stroke(_cy.withValues(alpha: .5));
    const pat = [8.0, 3.0, 2.0, 3.0];
    _line(c, Offset(s.width / 2, -8), Offset(s.width / 2, s.height + 8), p, pat);
    _line(c, Offset(-8, s.height / 2), Offset(s.width + 8, s.height / 2), p, pat);
  }

  @override
  bool shouldRepaint(_CentreMarks o) => false;
}

/// Line drawing of the cover scene: sun and hills in outline, with construction lines.
class _LineArt extends CustomPainter {
  const _LineArt(this.seed, this.vw);
  final int seed;
  final double vw;

  @override
  void paint(Canvas c, Size size) {
    final k = vw / 100;
    final sc = math.min(size.width / vw, size.height / 100);
    c.save();
    c.translate((size.width - vw * sc) / 2, (size.height - 100 * sc) / 2);
    c.scale(sc);
    final sx = (30 + (seed * 37) % 40) * k, sy = 34.0 + (seed * 13) % 10;
    c.drawCircle(Offset(sx, sy), 15, _stroke(_ln, 1.2));
    c.drawCircle(Offset(sx, sy), 1.2, Paint()..color = _cy);
    final con = _stroke(_cy, .5);
    _line(c, Offset(sx - 22, sy), Offset(sx + 22, sy), con, const [4, 2, 1, 2]);
    _line(c, Offset(sx, sy - 22), Offset(sx, sy + 22), con, const [4, 2, 1, 2]);
    _text(c, 'R15', sx + 12, sy - 13, _m(4.5, c: _cy));
    // Hills: stretched horizontally, strokes kept at 1.2 screen px.
    final ns = 1.2 / sc;
    final h1 = Path()
      ..moveTo(0, 64)
      ..cubicTo(22 * k, 55, 42 * k, 70, 66 * k, 60)
      ..cubicTo(90 * k, 50, 100 * k, 56, 100 * k, 56);
    final h2 = Path()
      ..moveTo(0, 78)
      ..cubicTo(28 * k, 70, 58 * k, 86, 100 * k, 72);
    c.drawPath(h1, _stroke(_ln, ns));
    c.drawPath(h2, _stroke(_ln, ns));
    c.drawLine(Offset(0, 92), Offset(100 * k, 92), _stroke(_ln2, .8 / sc));
    c.restore();
  }

  @override
  bool shouldRepaint(_LineArt o) => o.seed != seed || o.vw != vw;
}

int _seed(String s) => stableHash(s) % 7 + 1;

// ------------------------------------------------------------------ Home

class _Home extends ConsumerWidget {
  const _Home();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void go(PageId p) => PageNav.go(context, p);
    return Ticker(
      builder: (context, now) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 105,
                  child: Press(scale: 1, onTap: () => go(PageId.calendar), child: _plan(ref, now)),
                ),
                const SizedBox(width: _colGap),
                Expanded(
                  flex: 100,
                  child: Press(scale: 1, onTap: () => go(PageId.system), child: _loads(ref, now, go)),
                ),
              ],
            ),
          ),
          const SizedBox(height: _rowGap),
          _footer(context, ref),
        ],
      ),
    );
  }

  Widget _plan(WidgetRef ref, DateTime now) {
    final h24 = ref.watch(settingsProvider.select((s) => s.clock24));
    final events = ref.watch(calendarEventsProvider);
    final n = nextEvent(events, now);
    return _dwg('Plan', sub: 'scale 1:1', [
      const SizedBox(height: 4),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: _big(clock(now, h24: h24), h24 ? '' : ampm(now), 112),
      ),
      const SizedBox(height: 10),
      _Dim(1, longDate(now), part: false, height: 22, dlTop: 0, labelTop: -9),
      const Spacer(),
      if (n == null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nothing else today', style: _s(12.5, w: FontWeight.w700)),
              _note('Free until tomorrow'),
            ],
          ),
        )
      else
        _Cloud(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _Tri('1'),
                  Expanded(
                    child: Text(
                      n.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _s(12.5, w: FontWeight.w700, c: _red, h: 1.35),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _inText(n, now),
                    style: _m(12.5, w: FontWeight.w700, c: _red),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 22),
                child: _note([clockFull(n.start, h24: h24), if (n.location != null) n.location!].join(', ')),
              ),
            ],
          ),
        ),
    ]);
  }

  Widget _loads(WidgetRef ref, DateTime now, void Function(PageId) go) {
    final s = topicData<SystemData>(ref, 'system');
    final c = topicData<ClaudeData>(ref, 'claude');
    final five = c?.fiveHour == null ? null : limitPct(c!.fiveHour, now);
    final rows = <(String, double?, bool)>[
      ('Processor', s?.cpu.pct, false),
      ('Graphics', s == null || !s.gpu.available ? null : s.gpu.pct, false),
      ('Claude, 5-hour', five, (five ?? 0) >= 80),
    ];
    return _dwg('Loads', sub: 'measured live', [
      const SizedBox(height: 8),
      for (final (i, (l, v, red)) in rows.indexed) ...[
        if (i > 0) const SizedBox(height: 16),
        Padding(padding: const EdgeInsets.only(bottom: 2), child: _note(l)),
        _Dim((v ?? 0) / 100, v == null ? 'N/A' : '${v.round()}%', red: red),
      ],
      const SizedBox(height: 16),
      Press(scale: 1, onTap: () => go(PageId.slack), child: _slack(ref)),
    ]);
  }

  /// Slack, drawn as a count rather than a load: one graduation per recent message,
  /// the unread ones hatched.
  Widget _slack(WidgetRef ref) {
    final sd = topicData<SlackData>(ref, 'slack');
    final i = slackHome(ref);
    final total = sd?.messages.length ?? 0;
    final known = i.latest != null || i.headline == 'All caught up';
    final note = i.latest != null
        ? 'Slack, ${i.detail}'
        : (i.detail == '—' ? 'Slack' : 'Slack, ${_lower(i.detail)}');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(padding: const EdgeInsets.only(bottom: 2), child: _note(note)),
        _Dim(
          total == 0 ? 0 : i.unread / total,
          known ? i.headline : 'N/A',
          ticks: total <= 24 ? total : 0,
        ),
      ],
    );
  }

  Widget _footer(BuildContext context, WidgetRef ref) {
    final w = ref.watch(weatherProvider);
    final f = ref.watch(settingsProvider.select((s) => s.fahrenheit));
    final m = topicData<MediaData>(ref, 'media');
    return Container(
      padding: const EdgeInsets.only(top: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _ln3)),
      ),
      child: Row(
        children: [
          Press(
            onTap: () => PageNav.go(context, PageId.weather),
            child: Row(
              children: [
                DpIcon(w?.now.icon ?? 'cloud', size: 14, color: _ln),
                const SizedBox(width: 8),
                Text(w == null ? '—' : '${temp(w.now.tempC, f)}°', style: _s(12.5, w: FontWeight.w700)),
                const SizedBox(width: 8),
                Text(
                  w == null
                      ? 'Set a location'
                      : '${w.now.condition}${w.days.isEmpty ? '' : ', high ${temp(w.days.first.hiC, f)}°'}',
                  style: _s(12.5, c: _ln2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Press(
              onTap: () => PageNav.go(context, PageId.music),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  DpIcon('music', size: 14, color: _ln),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      m?.title ?? 'Nothing playing',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _s(12.5, w: FontWeight.w700),
                    ),
                  ),
                  if (m?.artist != null) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        m!.artist!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _s(12.5, c: _ln2),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 18),
          _bub(
            m?.playing == true ? 'pause' : 'play',
            m?.title == null ? null : () => act(context, ref, 'media.play_pause'),
            size: 32,
            iconSize: 13,
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
    final set = ref.read(systemTabProvider.notifier).set;
    final tabs = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Btn(label: 'Laptop', pressed: tab == 0, height: 26, padH: 10, size: 11.5, onTap: () => set(0)),
        const SizedBox(width: 10),
        _Btn(label: 'Internet', pressed: tab == 1, height: 26, padH: 10, size: 11.5, onTap: () => set(1)),
      ],
    );
    return tab == 0 ? _Pc(tabs) : _Net(tabs);
  }
}

class _Pc extends ConsumerWidget {
  const _Pc(this.tabs);
  final Widget tabs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = topicData<SystemData>(ref, 'system')!;
    final g = s.gpu;
    const gb = 1024 * 1024 * 1024;
    final ramPct = s.ramTotal == 0 ? 0.0 : s.ramUsed / s.ramTotal * 100;
    final vramPct = g.vramUsed != null && (g.vramTotal ?? 0) > 0 ? g.vramUsed! / g.vramTotal! * 100 : null;
    final rows = <(String, String, double?)>[
      (
        'Processor',
        s.cpu.cores != null ? '${s.cpu.cores} cores, ${s.cpu.threads ?? s.cpu.cores} threads' : '',
        s.cpu.pct,
      ),
      (
        'Graphics',
        !g.available ? 'not available' : (g.tempC != null ? '${g.tempC!.round()}°C' : ''),
        g.available ? g.pct : null,
      ),
      ('Memory', '${(s.ramUsed / gb).toStringAsFixed(1)} of ${(s.ramTotal / gb).round()} GB', ramPct),
      (
        g.vramLabel,
        vramPct == null ? 'N/A' : '${(g.vramUsed! / gb).toStringAsFixed(1)} of ${(g.vramTotal! / gb).round()} GB',
        vramPct,
      ),
    ];
    final (down, downU) = rate(s.downBps);
    final (up, upU) = rate(s.upBps);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 100,
          child: _dwg('Load elevation', sub: 'percent of capacity', [
            const SizedBox(height: 4),
            for (final (i, (l, sub, v)) in rows.indexed) ...[
              if (i > 0) const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(l, style: _s(12.5, w: FontWeight.w700, h: 1.35)),
                    const SizedBox(width: 8),
                    Expanded(child: _note(sub)),
                  ],
                ),
              ),
              _Dim((v ?? 0) / 100, v == null ? 'N/A' : '${v.round()}%'),
            ],
          ]),
        ),
        const SizedBox(width: _colGap),
        Expanded(
          flex: 115,
          child: Stack(
            children: [
              Positioned.fill(
                child: _dwg('Load over time', sub: 'last 60 s', [
                  Expanded(
                    child: CustomPaint(
                      painter: _CpuGpuChart(s.cpuHistory, g.available ? s.gpuHistory : const []),
                      size: Size.infinite,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _note('1. ${s.cpu.model}${g.model != null ? ' with ${g.model}' : ''}.', lines: 1),
                  _note('2. Disk ${s.diskPct.round()}% used. Network $down $downU down, $up $upU up.'),
                ]),
              ),
              Positioned(right: 0, top: 0, child: tabs),
            ],
          ),
        ),
      ],
    );
  }
}

class _CpuGpuChart extends CustomPainter {
  _CpuGpuChart(this.cpu, this.gpu);
  final List<double> cpu;
  final List<double?> gpu;

  @override
  void paint(Canvas c, Size s) {
    const l = 30.0, b = 18.0;
    final w = s.width, h = s.height, pw = w - l, ph = h - b;
    double y(double v) => ph * (1 - v.clamp(0, 100) / 100);
    // Leave room for the tab buttons and legend at the top.
    _axes(c, s, l, b, [('0', y(0)), ('50', y(50)), ('100', y(100))], [('-60 s', l), ('-30 s', l + pw / 2), ('now', w)]);
    _line(c, Offset(l, y(50)), Offset(w, y(50)), _stroke(_ln3), const [6, 3, 1, 3]);
    if (gpu.length > 1) {
      final p = _smooth(gpu, (i) => l + i * pw / (gpu.length - 1), y);
      c.drawPath(_dash(p, const [5, 3]), _stroke(_cy, 1.5));
    }
    if (cpu.length > 1) {
      c.drawPath(_smooth(cpu, (i) => l + i * pw / (cpu.length - 1), y), _stroke(_ln, 1.8));
    }
    _text(
      c,
      gpu.isEmpty ? 'processor ———' : 'processor ———  graphics - - -',
      w - 4,
      12,
      _m(9.5),
      align: TextAlign.right,
    );
  }

  @override
  bool shouldRepaint(_CpuGpuChart o) => o.cpu != cpu || o.gpu != gpu;
}

class _Net extends ConsumerWidget {
  const _Net(this.tabs);
  final Widget tabs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = topicData<NetworkData>(ref, 'network');
    final live = ref.watch(agentProvider).live;
    final sys = topicData<SystemData>(ref, 'system');
    if (n == null) {
      return Stack(
        children: [
          Center(child: _note('Waiting for network data…')),
          Positioned(right: 0, top: 0, child: tabs),
        ],
      );
    }
    final now = DateTime.now();
    final st = n.speedtest;
    final last = st.last;
    final prog = st.progress;
    final shownDown = st.running ? (prog?.downBps ?? 0) : (last?.downBps ?? 0);
    final shownUp = st.running ? (prog?.upBps ?? 0) : (last?.upBps ?? 0);
    final status = !live ? 'Unknown' : (n.online ? 'Online' : 'Offline');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 100,
              child: _dwg('Latency', [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    n.latencyMs == null ? _big('—', 'ms', 76, c: _red) : _bigNum(n.latencyMs, 'ms', 76),
                    const Spacer(),
                    _note(
                      'jitter ${n.jitterMs?.toStringAsFixed(1) ?? '—'} ms\nloss ${n.lossPct.round()}%',
                      align: TextAlign.right,
                      lines: 2,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _Dim((n.latencyMs ?? 0) / 50, '0 to 50 ms', red: (n.latencyMs ?? 0) > 50),
              ]),
            ),
            const SizedBox(width: _colGap),
            Expanded(
              flex: 115,
              child: Stack(
                children: [
                  _dwg('Connection', [
                    _table(
                      [
                        [_td('Status'), _td(status, bold: true, c: status == 'Online' ? _cy : _red)],
                        [
                          _td('Uptime'),
                          _td(n.onlineSince == null ? '—' : durLong(now.difference(n.onlineSince!)), mono: true),
                        ],
                        [
                          _td('Last drop'),
                          _td(n.lastDrop == null ? 'none' : ago(now.difference(n.lastDrop!)), mono: true),
                        ],
                        [
                          _td('Used today / month'),
                          _td('${bytes(n.usageToday)} / ${bytes(n.usageMonth, digits: 0)}', mono: true),
                        ],
                      ],
                      right: const {1},
                    ),
                  ]),
                  Positioned(right: 0, top: 0, child: tabs),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: _rowGap),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 100,
                child: _dwg('Latency over time', sub: 'last 2 min', [
                  Expanded(
                    child: CustomPaint(painter: _LatChart(n.latencyHistory), size: Size.infinite),
                  ),
                ]),
              ),
              const SizedBox(width: _colGap),
              Expanded(
                flex: 115,
                child: _dwg('Speed test', sub: 'Mbps', [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        _big(last == null && !st.running ? '—' : mbps(shownDown), 'down', 52),
                        const SizedBox(width: 22),
                        _big(last == null && !st.running ? '—' : mbps(shownUp), 'up', 52),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _note(
                    '${st.running
                        ? 'Testing now'
                        : last == null
                        ? 'Never tested'
                        : 'Tested ${ago(now.difference(last.at))}, ping ${last.pingMs.round()} ms'}. '
                    'Now ${sys == null ? '—' : mbps(sys.downBps)} / ${sys == null ? '—' : mbps(sys.upBps)} Mbps.',
                    lines: 2,
                  ),
                  if (st.running) ...[const SizedBox(height: 10), _Dim((prog?.pct ?? 0) / 100, 'measuring')],
                  const Spacer(),
                  _Btn(
                    label: st.running ? 'Testing…' : 'Run test',
                    onTap: st.running
                        ? null
                        : () => act(context, ref, 'speedtest.run', const {}, null, null, const Duration(seconds: 90)),
                  ),
                  const SizedBox(height: 5),
                ]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LatChart extends CustomPainter {
  _LatChart(this.vals);
  final List<double?> vals;

  @override
  void paint(Canvas c, Size s) {
    const l = 26.0, b = 16.0;
    final w = s.width, h = s.height, pw = w - l, ph = h - b;
    double y(double v) => ph * (1 - v.clamp(0, 50) / 50);
    _axes(c, s, l, b, [('0', ph), ('25', ph / 2), ('50', 0)], [('-2 m', l), ('now', w)]);
    if (vals.length > 1) {
      c.drawPath(_smooth(vals, (i) => l + i * pw / (vals.length - 1), y), _stroke(_ln, 1.5));
    }
  }

  @override
  bool shouldRepaint(_LatChart o) => o.vals != vals;
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
        Widget limit(String title, LimitWindow? w, double pct, String note) => _dwg(title, [
          w == null ? _big('—', '', 72, c: _ln2) : _bigNum(pct, '%', 72, c: pct >= 80 ? _red : _ln),
          const SizedBox(height: 12),
          _Dim(pct / 100, 'used', red: pct >= 80),
          const SizedBox(height: 6),
          _note(_lower(note)),
        ]);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: limit('5-hour limit', c.fiveHour, five, resetsIn(c.fiveHour, now))),
                      const SizedBox(width: _colGap),
                      Expanded(child: limit('Weekly limit', c.sevenDay, week, resetsAt(c.sevenDay, now, h24: h24))),
                    ],
                  ),
                  const SizedBox(height: _rowGap),
                  Expanded(
                    child: _dwg('Tokens, last 7 days', sub: 'millions', [
                      Expanded(
                        child: CustomPaint(painter: _DaysChart(c.days, now), size: Size.infinite),
                      ),
                      const SizedBox(height: 6),
                      _note(
                        c.modelsToday.isEmpty
                            ? 'No messages yet today.'
                            : 'Today by model: ${c.modelsToday.map((m) => '${modelName(m.family)} ${(m.tokens / 1e6).toStringAsFixed(1)}M').join(', ')}.',
                      ),
                    ]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: _colGap),
            Expanded(
              child: _dwg('Today', [
                _table(
                  [
                    [_td('Tokens'), _td(compact(c.tokens), mono: true)],
                    [_td('Output'), _td(compact(c.outputTokens), mono: true)],
                    [_td('Messages'), _td('${c.messages}', mono: true)],
                    [_td('Last hour'), _td(compact(c.lastHourTokens), mono: true)],
                  ],
                  right: const {1},
                ),
              ]),
            ),
          ],
        );
      },
    );
  }
}

double _niceMax(double v) {
  if (v <= 0) return 1;
  final x = v * 1.08;
  final mag = math.pow(10, (math.log(x) / math.ln10).floor()).toDouble();
  for (final k in const [1.0, 2.0, 2.5, 4.0, 5.0, 7.0, 10.0]) {
    if (k * mag >= x) return k * mag;
  }
  return 10 * mag;
}

String _num(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

class _DaysChart extends CustomPainter {
  _DaysChart(this.days, this.now);
  final List<ClaudeDay> days;
  final DateTime now;

  @override
  void paint(Canvas c, Size s) {
    const l = 26.0, b = 16.0;
    final w = s.width, h = s.height, pw = w - l, ph = h - b;
    final mx = _niceMax(maxOf(days.map((d) => d.tokens / 1e6), floor: 0.1));
    _axes(c, s, l, b, [('0', ph), (_num(mx / 2), ph / 2), (_num(mx), 0)], []);
    if (days.isEmpty) return;
    final bw = pw / days.length;
    for (final (i, d) in days.indexed) {
      final today = i == days.length - 1;
      final v = d.tokens / 1e6;
      final x = l + i * bw + bw * .22, bh = v / mx * ph, y = ph - bh;
      final r = Rect.fromLTWH(x, y, bw * .56, bh);
      _hatch(c, Path()..addRect(r), today ? _cy : _ln2, gap: today ? 4 : 5, back: !today);
      c.drawRect(r, _stroke(today ? _cy : _ln, 1.2));
      _text(c, v.toStringAsFixed(1), x + bw * .28, y - 5, _m(9.5, c: today ? _cy : _ln), align: TextAlign.center);
      _text(c, dayLabel(d.date, now), x + bw * .28, h - 3, _m(9, c: _ln2), align: TextAlign.center);
    }
  }

  @override
  bool shouldRepaint(_DaysChart o) => o.days != days;
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 105,
              child: _dwg('Schedule, today', sub: longDate(now), [
                Expanded(
                  child: CustomPaint(
                    painter: _Gantt(split.today.where((e) => !e.allDay).toList(), n, now, h24),
                    size: Size.infinite,
                  ),
                ),
              ]),
            ),
            const SizedBox(height: _rowGap),
            Expanded(
              flex: 100,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 145,
                    child: _dwg('Today', [
                      if (split.today.isEmpty) _note('Nothing on the calendar today.'),
                      if (split.today.isNotEmpty)
                        Expanded(
                          child: SingleChildScrollView(
                            child: _table(
                              head: const ['Start', 'Event', 'Where', 'Starts'],
                              right: const {3},
                              widths: const {
                                0: IntrinsicColumnWidth(),
                                1: FlexColumnWidth(1.3),
                                2: FlexColumnWidth(1),
                                3: IntrinsicColumnWidth(),
                              },
                              [
                                for (final e in split.today)
                                  () {
                                    final nx = e == n, past = e.end.isBefore(now);
                                    final col = nx ? _red : (past ? _ln3 : _ln);
                                    return [
                                      _td(e.allDay ? 'All day' : clockFull(e.start, h24: h24), mono: true, c: col),
                                      _td(e.title, bold: true, c: col),
                                      _td(e.location ?? e.calendar ?? '', c: col),
                                      _td(
                                        nx
                                            ? _inText(e, now)
                                            : past
                                            ? 'done'
                                            : (!e.start.isAfter(now) ? 'now' : 'in ${dur(e.start.difference(now))}'),
                                        mono: true,
                                        c: col,
                                      ),
                                    ];
                                  }(),
                              ],
                            ),
                          ),
                        ),
                    ]),
                  ),
                  const SizedBox(width: _colGap),
                  Expanded(
                    flex: 100,
                    child: _dwg('Later this week', [
                      if (split.later.isEmpty) _note('No other events in the next 7 days.'),
                      _table(
                        right: const {2},
                        widths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth(), 2: IntrinsicColumnWidth()},
                        [
                          for (final e in split.later.take(4))
                            [
                              _td(weekday3(e.start), mono: true, c: _cy),
                              _td(e.title, bold: true),
                              _td(e.allDay ? 'all day' : clockFull(e.start, h24: h24), mono: true),
                            ],
                        ],
                      ),
                    ]),
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

class _Gantt extends CustomPainter {
  _Gantt(this.events, this.next, this.now, this.h24);
  final List<CalEvent> events;
  final CalEvent? next;
  final DateTime now;
  final bool h24;

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    var h0 = 8, h1 = 18;
    for (final e in events) {
      h0 = math.min(h0, e.start.hour);
      h1 = math.max(h1, math.min(24, e.end.hour + (e.end.minute > 0 ? 1 : 0)));
    }
    if ((h1 - h0).isOdd) h1 = math.min(24, h1 + 1);
    if ((h1 - h0).isOdd) h0 = math.max(0, h0 - 1);
    final day0 = DateTime(now.year, now.month, now.day);
    double x(DateTime t) => (t.difference(day0).inMinutes / 60 - h0) / (h1 - h0) * w;
    for (var hr = h0; hr <= h1; hr++) {
      final xx = (hr - h0) / (h1 - h0) * w;
      c.drawLine(Offset(xx, 0), Offset(xx, h - 16), _stroke(_ln3, (hr - h0).isOdd ? .6 : 1));
      if ((hr - h0).isEven) {
        final lab = h24 ? '$hr' : '${hr % 12 == 0 ? 12 : hr % 12}${hr < 12 || hr == 24 ? 'a' : 'p'}';
        _text(c, lab, xx, h - 3, _m(9.5, c: _ln2), align: TextAlign.center);
      }
    }
    final rows = math.max(3, events.length);
    final bh = math.min(18.0, (h - 40) / rows);
    for (final (i, e) in events.indexed) {
      final x0 = x(e.start).clamp(0.0, w), x1 = math.max(x(e.end).clamp(0.0, w), x0 + 8);
      final y = 10 + i * ((h - 30) / rows);
      final nx = e == next;
      final r = Rect.fromLTWH(x0, y, x1 - x0, bh);
      _hatch(c, Path()..addRect(r), _ln2);
      c.drawRect(r, _stroke(nx ? _red : _ln, 1.3));
      final st = _s(10.5, w: FontWeight.w700, c: nx ? _red : _ln);
      final tw = _textW(e.title, st);
      final left = x1 + 6 + tw > w;
      _text(c, e.title, left ? x0 - 6 : x1 + 6, y + bh / 2 + 3.5, st, align: left ? TextAlign.right : TextAlign.left);
    }
    final xn = x(now);
    if (xn >= 0 && xn <= w) {
      _line(c, Offset(xn, 0), Offset(xn, h - 16), _stroke(_red, 1.3), const [5, 3]);
      _text(c, 'now ${clock(now, h24: h24)}', xn + 4, 9, _m(9.5, c: _red));
    }
  }

  @override
  bool shouldRepaint(_Gantt o) => true;
}

// ------------------------------------------------------------------ Weather

class _Weather extends ConsumerWidget {
  const _Weather();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(weatherProvider);
    final s = ref.watch(settingsProvider);
    if (w == null) {
      return Center(child: _note('Set your location in Settings → Weather'));
    }
    final f = s.fahrenheit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 90,
                child: _dwg(w.place, sub: f ? '°F' : '°C', [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${temp(w.now.tempC, f)}°', style: _bigStyle(110)),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: DpIcon(w.now.icon, size: 46, color: _ln, stroke: 1.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(w.now.condition, style: _s(16, w: FontWeight.w700, h: 1.35)),
                  const SizedBox(height: 6),
                  _note(
                    'feels like ${temp(w.now.feelsC, f)}°\nhumidity ${w.now.humidity}%\nwind ${wind(w.now.windKmh, f)}\n'
                    'updated ${clockFull(w.now.updated, h24: s.clock24)}',
                    lines: 4,
                  ),
                ]),
              ),
              const SizedBox(width: _colGap),
              Expanded(
                flex: 140,
                child: _dwg('Temperature section, next ${w.hours.length} h', [
                  Expanded(
                    child: CustomPaint(painter: _TempChart(w.hours, f, s.clock24), size: Size.infinite),
                  ),
                ]),
              ),
            ],
          ),
        ),
        const SizedBox(height: _rowGap),
        _dwg('This week', [
          Row(
            children: [
              for (final (i, d) in w.days.indexed)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      border: i > 0 ? const Border(left: BorderSide(color: _ln3)) : null,
                    ),
                    child: Column(
                      children: [
                        _note(i == 0 ? 'Today' : weekday3(d.date)),
                        const SizedBox(height: 4),
                        DpIcon(d.icon, size: 20, color: _ln),
                        const SizedBox(height: 4),
                        Text('${temp(d.hiC, f)}° / ${temp(d.loC, f)}°', style: _m(12.5, w: FontWeight.w700)),
                        SizedBox(height: 16, child: _note(d.precipPct > 0 ? '${d.precipPct}% rain' : '', c: _cy)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ]),
      ],
    );
  }
}

class _TempChart extends CustomPainter {
  _TempChart(this.hours, this.f, this.h24);
  final List<WeatherHour> hours;
  final bool f, h24;

  String _hr(DateTime t, int i) =>
      i == 0 ? 'Now' : (h24 ? '${two(t.hour)}:00' : '${t.hour % 12 == 0 ? 12 : t.hour % 12} ${ampm(t)}');

  @override
  void paint(Canvas c, Size s) {
    if (hours.length < 2) return;
    final vals = [for (final h in hours) temp(h.tempC, f).toDouble()];
    final mn = vals.reduce(math.min), mxv = vals.reduce(math.max);
    final lo = (mn / 10).floor() * 10.0;
    final hi = math.max(lo + 10, mxv + 6);
    const l = 26.0, b = 16.0;
    final w = s.width, h = s.height, pw = w - l - 10, ph = h - b - 14;
    double x(int i) => l + 5 + i * pw / (vals.length - 1);
    double y(double v) => 14 + ph * (1 - (v - lo) / (hi - lo));
    _axes(
      c,
      s,
      l,
      b,
      [for (var v = lo; v <= hi; v += 10) (v.round().toString(), y(v))],
      [for (var i = 0; i < hours.length; i += 2) (_hr(hours[i].time, i), x(i))],
    );
    c.drawPath(_smooth(vals, x, y), _stroke(_ln, 1.6));
    final top = vals.indexOf(mxv);
    for (final (i, v) in vals.indexed) {
      final o = Offset(x(i), y(v));
      c.drawCircle(o, 2.4, Paint()..color = _bp);
      c.drawCircle(o, 2.4, _stroke(_ln, 1.2));
      if (i.isEven || i == top) {
        _text(c, '${v.round()}°', o.dx, o.dy - 7, _m(9.5, c: i == top ? _cy : _ln), align: TextAlign.center);
      }
    }
    // Leader to the high.
    final xm = x(top), ym = y(mxv);
    final label = 'high ${mxv.round()}° at ${_hr(hours[top].time, top == 0 ? 1 : top)}';
    final st = _m(9.5, c: _cy);
    final flip = xm + 33 + _textW(label, st) > w;
    final tx = flip ? xm - 30 : xm + 30;
    c.drawLine(Offset(xm, ym), Offset(tx, ym - 18), _stroke(_cy, .8));
    _text(c, label, flip ? tx - 3 : tx + 3, ym - 18, st, align: flip ? TextAlign.right : TextAlign.left);
  }

  @override
  bool shouldRepaint(_TempChart o) => o.hours != hours || o.f != f;
}

// ------------------------------------------------------------------ Music

class _Music extends ConsumerWidget {
  const _Music();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = topicData<MediaData>(ref, 'media')!;
    final skew = ref.read(agentProvider.notifier).clockSkewMs;
    final title = m.title;
    return Row(
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final side = math.min(c.maxHeight * .92, 320.0);
            return Padding(
              padding: const EdgeInsets.all(8),
              child: SizedBox(
                width: side,
                height: side,
                child: _Frame(
                  child: CustomPaint(painter: _LineArt(_seed(title ?? 'DeskPanel'), 100), size: Size.infinite),
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 22),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BpTitle('Now playing'),
              _note([m.source ?? 'Laptop', if (m.album != null) 'album ${m.album}'].join(', ')),
              const SizedBox(height: 8),
              Text(
                title ?? 'Nothing playing',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _s(38, w: FontWeight.w800, ls: -.38, h: 1),
              ),
              const SizedBox(height: 4),
              Text(
                m.artist ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _s(16, w: FontWeight.w600, h: 1.35),
              ),
              const SizedBox(height: 26),
              Ticker(
                period: const Duration(seconds: 1),
                builder: (context, now) {
                  final pos = m.positionNow(now, skewMs: skew);
                  final total = m.durationMs ?? 0;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SeekDim(
                        value: total == 0 ? 0 : pos / total,
                        label: mmss(pos),
                        enabled: m.canSeek && total > 0,
                        onSeek: (f) => act(context, ref, 'media.seek', {'position_ms': (f * total).round()}),
                      ),
                      const SizedBox(height: 4),
                      Row(children: [_note('0:00'), const Spacer(), _note(total == 0 ? '' : mmss(total))]),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _bub('prev', () => act(context, ref, 'media.prev')),
                  const SizedBox(width: 14),
                  _bub(m.playing ? 'pause' : 'play', () => act(context, ref, 'media.play_pause'), size: 62, main: true),
                  const SizedBox(width: 14),
                  _bub('next', () => act(context, ref, 'media.next')),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ Hotspot

/// The Hotspot Monitor Overview (the roof phone sharing mobile data) as one sheet: the
/// phone's state (any alert in a revision cloud), the signal and speed drawings, the
/// event register, and a schedule along the bottom for battery, heat, data and uptime.
class _Hotspot extends ConsumerWidget {
  const _Hotspot();

  static const _t = BlueprintSkin.t;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = topicData<HotspotData>(ref, 'hotspot')!;
    final f = ref.watch(settingsProvider.select((s) => s.fahrenheit));
    return Ticker(
      builder: (context, now) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 96, child: _phone(d, now)),
                const SizedBox(width: _colGap),
                Expanded(flex: 106, child: _signal(d)),
                const SizedBox(width: _colGap),
                Expanded(flex: 118, child: _events(d, now)),
              ],
            ),
          ),
          const SizedBox(height: _rowGap),
          _schedule(d, f),
        ],
      ),
    );
  }

  Widget _phone(HotspotData d, DateTime now) {
    final alert = hsAlert(d, now);
    final session = hsSessionNote(d, now);
    return _dwg('Hotspot', sub: d.name ?? 'phone', [
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(hsStateLabel(d), maxLines: 1, style: _bigStyle(40, hsStateColor(d, _t))),
      ),
      const SizedBox(height: 6),
      _note(hsSeen(d, now)),
      if (alert != null) ...[
        const SizedBox(height: 6),
        _Cloud(
          child: Text(
            alert,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: _s(12, w: FontWeight.w700, c: _red, h: 1.3),
          ),
        ),
      ],
      const SizedBox(height: 6),
      Expanded(
        child: LayoutBuilder(
          builder: (context, box) {
            final rows = [
              [_label('network'), _td(hsNetwork(d), bold: true)],
              [_label('operator'), _td(d.operator ?? '—', bold: true)],
              [_label('tether'), _td(hsSharing(d), bold: true, c: d.tetherOn == true ? _cy : _ln2)],
            ];
            // Rows are ~26 px; the footer note (two lines) only when there's room for it.
            // A sign-in about to end outranks the tether row; the model doesn't.
            final n = math.min(rows.length, ((box.maxHeight - (session != null ? 36 : 0)) / 26).floor());
            final foot = session ?? d.model;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _table(
                  padV: 4,
                  widths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
                  rows.take(n).toList(),
                ),
                const Spacer(),
                if (foot != null && box.maxHeight - n * 26 >= 36)
                  _note(_nb(foot), c: session != null ? _t.warn : _ln2, lines: 2),
              ],
            );
          },
        ),
      ),
    ]);
  }

  Widget _signal(HotspotData d) {
    final (down, downU) = hsBpsParts(d.rxBps);
    final (up, upU) = hsBpsParts(d.txBps);
    final g = d.grade;
    final gc = hsGradeColor(g, _t);
    return _dwg('Signal', sub: 'score of 100', [
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: _bigNum(d.score, '/100', 46),
            ),
          ),
          const SizedBox(width: 10),
          Text(hsGradeLabel(g), style: _s(16, w: FontWeight.w800, c: gc)),
        ],
      ),
      const SizedBox(height: 6),
      _Dim(
        (d.score ?? 0) / 100,
        d.score == null ? 'N/A' : '${d.score!.round()} / 100',
        tone: g == HotspotGrade.fair ? _t.warn : (g == HotspotGrade.poor ? _red : null),
      ),
      const SizedBox(height: 4),
      _note(_nb(hsSignalLine(d)), lines: 2),
      const SizedBox(height: 4),
      const Spacer(),
      const BpTitle('Speed now'),
      Row(
        children: [
          for (final (i, (l, v, u)) in [('down', down, downU), ('up', up, upU)].indexed) ...[
            if (i > 0) const SizedBox(width: 14),
            Flexible(
              child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: _big(v, '$u $l', 34)),
            ),
          ],
        ],
      ),
      const SizedBox(height: 4),
      _note(_nb(hsPingLine(d)), lines: 2),
    ]);
  }

  Widget _events(HotspotData d, DateTime now) => _dwg('Events, register', sub: 'newest first', [
    if (d.events.isEmpty)
      const Expanded(child: _BlankSheet('No events from the phone.'))
    else
      Expanded(
        child: LayoutBuilder(
          builder: (context, box) {
            // As many rows as fit: header ~20 px, rows of one or two lines (17 px each) + 9 px.
            final times = [for (final e in d.events) slackTime(e.ts, now)];
            double colW(int n) => times.take(n).map((t) => _textW(t, _m(12.5))).fold(36.0, math.max) + 10;
            int fit(double timeW) {
              var room = box.maxHeight - 20;
              var n = 0;
              for (final e in d.events) {
                final st = _s(12.5, w: e.severity == 'info' ? FontWeight.w500 : FontWeight.w700);
                final h = (_textW(e.message, st) > box.maxWidth - timeW - 2 ? 2 : 1) * 17 + 9.0;
                if (h > room) break;
                room -= h;
                n++;
              }
              return n;
            }

            // The time column sized to the rows shown (a wide "Yesterday" further down
            // shouldn't squeeze the messages that fit).
            var n = fit(colW(times.length));
            for (var k = 0; k < 3; k++) {
              final m = fit(colW(n + 1));
              if (m <= n) break;
              n = m;
            }
            final timeW = colW(n);
            final shown = [for (var i = 0; i < n; i++) i];
            Color sev(HotspotEvent e) => e.severity == 'info' ? _ln : hsEventColor(e, _t);
            return _table(
              head: const ['When', 'Event'],
              padV: 4,
              widths: {0: FixedColumnWidth(timeW), 1: const FlexColumnWidth()},
              [
                for (final i in shown)
                  [
                    _td(times[i], mono: true, c: d.events[i].severity == 'info' ? _cy : sev(d.events[i])),
                    Text(
                      d.events[i].message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _s(
                        12.5,
                        w: d.events[i].severity == 'info' ? FontWeight.w500 : FontWeight.w700,
                        c: sev(d.events[i]),
                        h: 1.35,
                      ),
                    ),
                  ],
              ],
            );
          },
        ),
      ),
  ]);

  /// The bottom schedule: one column each for battery, heat, data and uptime.
  Widget _schedule(HotspotData d, bool f) {
    final frac = d.quotaFrac;
    final dataTone = frac == null ? null : (frac >= 1 ? _red : (frac >= .8 ? _t.warn : null));
    final batC = d.lowBattery ? _red : _ln;
    final heatC = switch (d.heat) {
      HotspotHeat.hot => _red,
      HotspotHeat.warm => _t.warn,
      HotspotHeat.ok => _ln,
    };
    Widget val(String v, String sub, {Color c = _ln}) => Text.rich(
      TextSpan(
        children: [
          TextSpan(text: v),
          if (sub.isNotEmpty) TextSpan(text: '  $sub', style: _m(11, c: _ln2)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _s(20, w: FontWeight.w800, c: c, h: 1.2),
    );
    Widget cell(Widget value, Widget below) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [value, const SizedBox(height: 2), SizedBox(height: 52, child: below)],
    );
    final (used, usedU) = hsBytesParts(d.cycleUsed);
    return _table(
      head: const ['Battery', 'Temperature', 'Data this cycle', 'Uptime, phone / agent'],
      widths: const {0: FlexColumnWidth(), 1: FlexColumnWidth(), 2: FlexColumnWidth(), 3: FlexColumnWidth()},
      padV: 4,
      [
        [
          cell(
            val(d.batteryPct == null ? '—' : '${d.batteryPct!.round()}%', hsCurrent(d.currentMa), c: batC),
            _note(_nb(hsPowerLine(d)), lines: 2),
          ),
          cell(
            val(
              hsTemp(d.batteryC, fahrenheit: f),
              d.radioResting ? 'resting' : 'battery',
              c: d.radioResting ? _red : heatC,
            ),
            _note(_nb(hsHeatLine(d, fahrenheit: f)), lines: 2),
          ),
          cell(
            val(used, d.quota == null ? '$usedU, no quota' : '$usedU of ${hsBytes(d.quota)}', c: dataTone ?? _ln),
            frac == null
                ? _note(_nb(hsTodayLine(d)), lines: 2)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 11,
                              child: CustomPaint(painter: _PartBar(frac.clamp(0.0, 1.0), dataTone ?? _ln2)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('${(frac * 100).round()}%', style: _m(11, w: FontWeight.w600, c: dataTone ?? _cy)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      _note(_nb(hsTodayLine(d)), lines: 2),
                    ],
                  ),
          ),
          cell(
            val(hsUptime(d.uptimeS), 'agent ${hsUptime(d.agentUptimeS)}'),
            _note(_nb(hsBootLine(d)), lines: 2),
          ),
        ],
      ],
    );
  }
}

/// Notes wrap only at their " · " separators ("41.5 °C" never splits).
String _nb(String s) => s.split(' · ').map((p) => p.replaceAll(' ', '\u00A0')).join(' · ');

/// Row label in a small schedule: a mono annotation.
Widget _label(String s) => Text(s, maxLines: 1, style: _m(10.5, c: _ln2, h: 1.35));

/// A small hatched part in its outline, filled to [p] (the dimension bar without its dimension).
class _PartBar extends CustomPainter {
  const _PartBar(this.p, this.c);
  final double p;
  final Color c;

  @override
  void paint(Canvas canvas, Size s) {
    final x1 = s.width * p;
    if (x1 > 0) _hatch(canvas, Path()..addRect(Rect.fromLTWH(0, 0, x1, s.height)), c, gap: 4);
    canvas.drawRect(Rect.fromLTWH(.6, .6, s.width - 1.2, s.height - 1.2), _stroke(_ln, 1.2));
    if (x1 > 0) canvas.drawLine(Offset(x1, 0), Offset(x1, s.height), _stroke(_ln, 1.2));
  }

  @override
  bool shouldRepaint(_PartBar o) => o.p != p || o.c != c;
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
        final adjusting = st.mode == TimerMode.countdown && !st.running;
        String minsOf(TimerMode m) => switch (m) {
          TimerMode.stopwatch => 'count up',
          TimerMode.countdown => '${st.countdownMin}:00',
          _ => '${m.defaultMin}:00',
        };
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 140,
              child: _dwg(
                '${st.mode.label} timer',
                sub: st.mode == TimerMode.stopwatch ? 'seconds' : '${st.total.inMinutes} min',
                [
                  Expanded(
                    child: CustomPaint(painter: _Dial(st.progress(now), digits), size: Size.infinite),
                  ),
                ],
              ),
            ),
            const SizedBox(width: _colGap),
            Expanded(
              flex: 100,
              child: _dwg('Mode', [
                Padding(
                  padding: const EdgeInsets.only(left: 6, top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, m) in TimerMode.values.indexed) ...[
                        if (i > 0) const SizedBox(height: 8),
                        _Btn(
                          height: 30,
                          pressed: m == st.mode,
                          onTap: () => ctl.setMode(m),
                          child: Row(
                            children: [
                              Expanded(child: Text(m.label)),
                              if (m == TimerMode.countdown && adjusting && m == st.mode) ...[
                                _adj('−', () => ctl.adjust(-1)),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                minsOf(m),
                                style: _m(12.5, w: FontWeight.w600, c: m == st.mode ? _bp : _ln),
                              ),
                              if (m == TimerMode.countdown && adjusting && m == st.mode) ...[
                                const SizedBox(width: 6),
                                _adj('+', () => ctl.adjust(1)),
                              ],
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _Btn(
                              height: 44,
                              pressed: true,
                              onTap: ctl.toggle,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  DpIcon(st.running ? 'pause' : 'play', size: 15, color: _bp),
                                  const SizedBox(width: 7),
                                  Text(label),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _bub('reset', ctl.reset, size: 44),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                _note(st.mode.isPomodoro ? '${st.sessions} of 4 focus sessions done today.' : 'Runs on the phone.'),
              ]),
            ),
          ],
        );
      },
    );
  }

  Widget _adj(String s, VoidCallback onTap) => Press(
    onTap: onTap,
    child: Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _bp, width: 1.2),
      ),
      alignment: Alignment.center,
      child: Text(
        s,
        style: _s(13, w: FontWeight.w700, c: _bp, h: 1),
      ),
    ),
  );
}

class _Dial extends CustomPainter {
  _Dial(this.frac, this.digits);
  final double frac;
  final String digits;

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height, cx = w / 2, cy = h / 2 + 2;
    final r = math.min(w, h) / 2 - 18;
    if (r <= 20) return;
    Offset pp(double rad, double a) =>
        Offset(cx + rad * math.sin(a * math.pi / 180), cy - rad * math.cos(a * math.pi / 180));
    c.drawCircle(Offset(cx, cy), r, _stroke(_ln, 1.3));
    c.drawCircle(Offset(cx, cy), r - 16, _stroke(_ln3));
    for (var a = 0; a < 360; a += 6) {
      final major = a % 30 == 0;
      c.drawLine(pp(r, a.toDouble()), pp(r - (major ? 10 : 5), a.toDouble()), _stroke(_ln, major ? 1.3 : .8));
      if (major) {
        final t = pp(r + 10, a.toDouble());
        _text(c, '${a ~/ 6}', t.dx, t.dy + 3, _m(8.5, c: _ln2), align: TextAlign.center);
      }
    }
    if (frac > .001) {
      final rr = r - 8;
      c.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: rr),
        -math.pi / 2,
        frac.clamp(0, 1) * 2 * math.pi,
        false,
        _stroke(_cy, 3),
      );
      _text(c, '${(frac * 360).round()}°', cx + 6, cy - r + 26, _m(9, c: _cy));
    }
    final con = _stroke(_cy, .6);
    _line(c, Offset(cx - r - 14, cy), Offset(cx + r + 14, cy), con, const [8, 3, 2, 3]);
    _line(c, Offset(cx, cy - r - 14), Offset(cx, cy + r + 14), con, const [8, 3, 2, 3]);
    var fs = (r * .5).roundToDouble();
    var st = _s(fs, w: FontWeight.w800);
    final tw = _textW(digits, st);
    if (tw > r * 1.5) {
      fs = fs * r * 1.5 / tw;
      st = _s(fs, w: FontWeight.w800);
    }
    final bw = math.max(r * 1.24, _textW(digits, st) + 12);
    c.drawRect(Rect.fromCenter(center: Offset(cx, cy), width: bw, height: r * .48), Paint()..color = _bp);
    _text(c, digits, cx, cy + fs * .34, st, align: TextAlign.center);
  }

  @override
  bool shouldRepaint(_Dial o) => o.frac != frac || o.digits != digits;
}

// ------------------------------------------------------------------ Slack

/// The inbox as a drawing register: a summary block on the left and the messages as a
/// correspondence register on the right, unread items flagged with revision triangles.
class _Slack extends ConsumerWidget {
  const _Slack();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = topicData<SlackData>(ref, 'slack')!;
    final unread = s.unreadMessages;
    final total = s.messages.length;
    int count(SlackKind k) => unread.where((m) => m.kind == k).length;
    // Revision numbers for the unread items, top to bottom.
    final rev = {for (final (i, m) in unread.indexed) m.id: i + 1};
    return Ticker(
      builder: (context, now) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 100,
            child: LayoutBuilder(
              builder: (context, box) {
                final roomy = box.maxHeight >= 290;
                return _dwg('Inbox', sub: s.team == null ? 'Slack' : 'Slack, ${s.team}', [
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: _bigNum(s.unread.toDouble(), 'unread', roomy ? 84 : 64, c: s.unread > 0 ? _ln : _ln2),
                  ),
                  const SizedBox(height: 8),
                  if (total > 0)
                    _Dim(
                      unread.isEmpty ? 1 : unread.length / total,
                      unread.isEmpty ? 'all $total read' : '${unread.length} of $total',
                      red: unread.isNotEmpty,
                    ),
                  if (roomy) ...[
                    const SizedBox(height: 10),
                    _table(
                      right: const {1},
                      padV: 4,
                      [
                        [_td('Direct messages'), _td('${count(SlackKind.dm)}', mono: true)],
                        [_td('Mentions'), _td('${count(SlackKind.mention)}', mono: true)],
                        [_td('Group messages'), _td('${count(SlackKind.group)}', mono: true)],
                      ],
                    ),
                  ],
                  const Spacer(),
                  if (s.unread > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(5, 0, 5, 5),
                      child: _Btn(
                        label: 'Mark all read',
                        height: 30,
                        padH: 14,
                        onTap: () => slackReadAll(context, ref),
                      ),
                    )
                  else
                    _note('All caught up. Nothing to review.', lines: 2),
                ]);
              },
            ),
          ),
          const SizedBox(width: _colGap),
          Expanded(
            flex: 190,
            child: _dwg('Messages, register', sub: total == 0 ? null : 'newest first', [
              if (total == 0)
                const Expanded(child: _BlankSheet('Your Slack inbox is empty.'))
              else ...[
                Container(
                  padding: const EdgeInsets.only(bottom: 4),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: _ln, width: 1.5)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40,
                        child: Text(
                          'Item',
                          style: _m(10, w: FontWeight.w600, c: _ln2, ls: .4),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'From, where, message',
                          style: _m(10, w: FontWeight.w600, c: _ln2, ls: .4),
                        ),
                      ),
                      Text(
                        'Received',
                        style: _m(10, w: FontWeight.w600, c: _ln2, ls: .4),
                      ),
                      const SizedBox(width: 36),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: total,
                    itemBuilder: (context, i) {
                      final m = s.messages[i];
                      return _SlackRow(m, now, rev[m.id], onTap: () => slackOpen(context, ref, m));
                    },
                  ),
                ),
              ],
            ]),
          ),
        ],
      ),
    );
  }
}

/// One register line: sender balloon, sender and where, time, then up to two lines of text.
class _SlackRow extends StatelessWidget {
  const _SlackRow(this.m, this.now, this.rev, {required this.onTap});
  final SlackMsg m;
  final DateTime now;
  final int? rev;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final on = m.unread;
    return Press(
      scale: .99,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _ln3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 40, child: _Balloon(m.initials, hex(m.senderColor), on: on)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (rev != null) _Tri('$rev'),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: m.sender),
                              TextSpan(
                                text: '  ${slackWhere(m)}',
                                style: _m(10.5, c: on ? _cy : _ln3),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _s(12.5, w: FontWeight.w700, c: on ? _ln : _ln2, h: 1.35),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        slackTime(m.ts, now),
                        style: _m(11, w: FontWeight.w600, c: on ? _cy : _ln3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    m.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _s(12.5, c: on ? _ln : _ln2, h: 1.35),
                  ),
                ],
              ),
            ),
            Transform.translate(offset: const Offset(4, 0), child: SlackReadTick(m, color: _cy, fill: _cy, radius: 2)),
          ],
        ),
      ),
    );
  }
}

/// Item balloon: a circled callout holding the sender's initials on their colour.
class _Balloon extends StatelessWidget {
  const _Balloon(this.initials, this.color, {required this.on});
  final String initials;
  final Color color;
  final bool on;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    child: Opacity(
      opacity: on ? 1 : .5,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: .85),
          border: Border.all(color: _ln, width: 1.5),
        ),
        child: Text(
          initials,
          maxLines: 1,
          style: _m(10, w: FontWeight.w700, c: _ln, h: 1),
        ),
      ),
    ),
  );
}

/// Empty frame with centre marks: "this sheet intentionally left blank".
class _BlankSheet extends StatelessWidget {
  const _BlankSheet(this.note);
  final String note;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
    child: CustomPaint(
      painter: const _CentreMarks(),
      child: Container(
        decoration: BoxDecoration(border: Border.all(color: _ln, width: 1.5)),
        child: Center(
          child: Container(
            color: _bp,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'THIS SHEET INTENTIONALLY LEFT BLANK',
                    style: _m(11, w: FontWeight.w600, c: _ln2, ls: 1.2),
                  ),
                  const SizedBox(height: 4),
                  Text(note, style: _m(10.5, c: _ln3)),
                ],
              ),
            ),
          ),
        ),
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
    final src = ref.watch(codeSourceProvider);
    final setSrc = ref.read(codeSourceProvider.notifier).set;
    final now = DateTime.now();
    final best = g.bestDay;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            _dwg(
              'Contributions, last 12 months',
              sub: '${_thousands(g.total)} total, ${g.commits} commits, ${g.private} private',
              [
                LayoutBuilder(
                  builder: (context, c) {
                    final cw = math.min((c.maxWidth - 24) / 53, 13.2);
                    return SizedBox(
                      height: 13 + 7 * cw,
                      width: 24 + 53 * cw,
                      child: CustomPaint(painter: _Heat(g.weeks)),
                    );
                  },
                ),
              ],
            ),
            Positioned(
              right: 0,
              top: 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (i, l) in codeSources.indexed) ...[
                    if (i > 0) const SizedBox(width: 10),
                    _Btn(label: l, pressed: src == i, height: 26, padH: 10, size: 11.5, onTap: () => setSrc(i)),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: _rowGap),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 80,
                child: _dwg('Streak', [
                  _bigNum(g.streakCurrent.toDouble(), g.streakCurrent == 1 ? 'day' : 'days', 84),
                  const Spacer(),
                  _note(
                    'longest ${g.streakLongest} days\nbest day ${best == null ? '—' : '${best.count} on ${month3(best.date)} ${best.date.day}'}',
                    lines: 2,
                  ),
                ]),
              ),
              const SizedBox(width: _colGap),
              Expanded(
                flex: 110,
                child: _dwg(
                  'This week',
                  sub: '${g.weekTotal}, ${g.weekDelta >= 0 ? 'up' : 'down'} ${g.weekDelta.abs()} on last week',
                  [
                    Expanded(
                      child: CustomPaint(
                        painter: _WeekChart(g.thisWeek, g.lastWeek, now.weekday % 7),
                        size: Size.infinite,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: _colGap),
              Expanded(
                flex: 100,
                child: _dwg(topReposLabel(ref), [
                  _table(
                    right: const {1},
                    [
                      for (final r in g.topRepos.take(5)) [_td(r.name, bold: true), _td('${r.count}', mono: true)],
                    ],
                  ),
                ]),
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
  _Heat(this.all);
  final List<List<ContribDay>> all;

  @override
  void paint(Canvas c, Size s) {
    final weeks = all.length > 53 ? all.sublist(all.length - 53) : all;
    const lw = 24.0, top = 13.0;
    final cw = (s.width - lw) / 53, cs = cw - 2.2;
    for (var x = 1; x < weeks.length - 1; x++) {
      if (weeks[x].isEmpty || weeks[x - 1].isEmpty) continue;
      if (weeks[x].first.date.month != weeks[x - 1].first.date.month) {
        _text(c, month3(weeks[x].first.date), lw + x * cw, 9, _m(9, c: _ln2));
      }
    }
    for (final (i, d) in const ['Mon', 'Wed', 'Fri'].indexed) {
      _text(c, d, 0, top + (1 + i * 2) * cw + cs * .78, _m(8.5, c: _ln2));
    }
    final rule = _stroke(_ln3, .6);
    for (var x = 0; x < weeks.length; x++) {
      for (final day in weeks[x]) {
        final y = day.date.weekday % 7;
        final r = Rect.fromLTWH(lw + x * cw, top + y * cw, cs, cs);
        final o = const [0.0, .25, .5, .75, 1.0][day.level.clamp(0, 4)];
        if (o > 0) c.drawRect(r, Paint()..color = _ln.withValues(alpha: o));
        c.drawRect(r, rule);
      }
    }
  }

  @override
  bool shouldRepaint(_Heat o) => o.all != all;
}

class _WeekChart extends CustomPainter {
  _WeekChart(this.week, this.last, this.today);
  final List<int?> week;
  final List<int> last;
  final int today;

  @override
  void paint(Canvas c, Size s) {
    const b = 16.0;
    final w = s.width, h = s.height, bw = w / 7, ph = h - b - 14;
    final mx = maxOf([...week, ...last]);
    c.drawLine(Offset(0, h - b), Offset(w, h - b), _stroke(_ln, 1.2));
    for (var i = 0; i < 7; i++) {
      final x = i * bw + bw * .2;
      final val = i < week.length ? (week[i] ?? 0) : 0;
      final lv = i < last.length ? last[i] : 0;
      final bh = val / mx * ph, lb = lv / mx * ph;
      if (lb > 0) {
        c.drawPath(_dash(Path()..addRect(Rect.fromLTWH(x, h - b - lb, bw * .6, lb)), const [3, 2]), _stroke(_ln3));
      }
      if (val > 0) {
        final r = Rect.fromLTWH(x + bw * .1, h - b - bh, bw * .4, bh);
        _hatch(c, Path()..addRect(r), i == today ? _cy : _ln2, gap: i == today ? 4 : 5, back: i != today);
        c.drawRect(r, _stroke(i == today ? _cy : _ln, 1.2));
      }
      _text(c, 'SMTWTFS'[i], x + bw * .3, h - 3, _m(9.5, c: i == today ? _cy : _ln2), align: TextAlign.center);
    }
  }

  @override
  bool shouldRepaint(_WeekChart o) => o.week != week || o.last != last || o.today != today;
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
          if (ri > 0) const SizedBox(height: 6),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(child: i < row.length ? _det(context, ref, row[i], s.volumePct) : const SizedBox()),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _sub(Tile t, int? vol) {
    if (t.id.startsWith('volume') && vol != null) return '$vol%';
    if (t.detail != null) return t.detail!;
    return switch (t.id) {
      'mic.toggle' => t.active ? 'muted' : 'live',
      'sound.toggle' => t.active ? 'muted' : 'on',
      'volume.down' || 'volume.up' => vol == null ? 'volume' : '$vol%',
      'screenshot' => 'full screen',
      'terminal' => 'new window',
      'downloads' => 'folder',
      'lock' => 'instant',
      _ => t.active ? 'on' : 'run',
    };
  }

  Widget _det(BuildContext context, WidgetRef ref, Tile t, int? vol) {
    final on = t.active;
    final c = on ? _red : _ln;
    return Press(
      onTap: () => act(context, ref, 'shortcut.run', {'id': t.id}),
      child: LayoutBuilder(
        builder: (context, box) {
          final d = math.min(86.0, math.min(box.maxWidth - 8, box.maxHeight - 30));
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: d,
                height: d,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: c, width: 1.5),
                ),
                child: ClipOval(
                  child: Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Center(
                            child: DpIcon(tileIcon(t), size: d * 26 / 86, color: c),
                          ),
                        ),
                      ),
                      Container(height: 1.5, color: c),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: d * .12),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _sub(t, vol),
                                maxLines: 1,
                                style: _m(11, w: FontWeight.w600, c: on ? _red : _ln2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tileLabel(t),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _s(13, w: FontWeight.w700, c: c),
              ),
            ],
          );
        },
      ),
    );
  }
}
