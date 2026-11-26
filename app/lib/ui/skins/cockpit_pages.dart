// Concept 6 — Cockpit pages. Sizes follow deskpanel-concept-6-cockpit.html (CSS px = logical px).
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/conn/controller.dart';
import '../../core/conn/loop.dart';
import '../../core/pages.dart';
import '../../core/settings.dart';
import '../fmt.dart';
import '../icons.dart';
import '../pages/kit.dart';
import '../skin.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import 'cockpit.dart';

const _w = CockpitSkin.w;
const _gy = CockpitSkin.gy;
const _g = CockpitSkin.g;
const _c = CockpitSkin.c;
const _m = CockpitSkin.m;
const _a = CockpitSkin.a;
const _r = CockpitSkin.r;
const _frc = CockpitSkin.fr;
const _fr2 = CockpitSkin.fr2;
const _bg = CockpitSkin.bg;
const _gap = 8.0;

Widget cockpitPage(PageId id) => switch (id) {
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

TextStyle _sans(double size, {Color c = _w, bool b = false, double ls = 0, double h = 1.3}) => TextStyle(
    fontFamily: CockpitSkin.sans,
    fontSize: size,
    fontWeight: b ? FontWeight.w700 : FontWeight.w400,
    color: c,
    letterSpacing: ls,
    height: h,
    fontFeatures: const [FontFeature.tabularFigures()]);

TextStyle _mono(double size, {Color c = _w, bool b = false, double h = 1.3}) => TextStyle(
    fontFamily: CockpitSkin.mono,
    fontSize: size,
    fontWeight: b ? FontWeight.w700 : FontWeight.w400,
    color: c,
    height: h,
    letterSpacing: 0,
    fontFeatures: const [FontFeature.tabularFigures()]);

/// `.cap`: 10.5px bold uppercase grey.
TextStyle _capS([Color c = _gy]) => _sans(10.5, b: true, ls: .84, c: c);

Widget _cap(String s, {Color c = _gy, TextAlign? align}) =>
    Text(s.toUpperCase(), style: _capS(c), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: align);

/// Caption with inline mono values: parts are (text, colour or null = grey cap).
Widget _capRich(List<(String, Color?)> parts, {TextAlign align = TextAlign.start}) => Text.rich(
      TextSpan(children: [
        for (final (s, c) in parts)
          c == null
              ? TextSpan(text: s.toUpperCase(), style: _capS())
              : TextSpan(text: s.toUpperCase(), style: _mono(10.5, c: c, b: true)),
      ]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: align,
    );

String _ampm(DateTime t, bool h24) => h24 ? '' : ampm(t);

String _inText(CalEvent e, DateTime now) {
  if (!e.start.isAfter(now)) return 'Now';
  final d = e.start.difference(now);
  return d.inMinutes < 1 ? 'Starting now' : 'in ${dur(d)}';
}

String _hourLabel(DateTime t, bool h24) =>
    h24 ? '${two(t.hour)}:00' : '${t.hour % 12 == 0 ? 12 : t.hour % 12} ${ampm(t)}';

/// m:ss (h:mm:ss past an hour), like the concept's `ms()`.
String _ms(Duration d) {
  final s = d.inSeconds;
  return s >= 3600 ? '${s ~/ 3600}:${two(s ~/ 60 % 60)}:${two(s % 60)}' : '${s ~/ 60}:${two(s % 60)}';
}

// ------------------------------------------------------------------ frame

/// Title span helpers: grey caps, cyan `<b>`, or any colour.
InlineSpan _tg(String s) => TextSpan(text: s.toUpperCase());
InlineSpan _tb(String s, [Color c = _c]) => TextSpan(text: s.toUpperCase(), style: TextStyle(color: c));

/// `.fr`: 1px frame with its title plate sitting on the top border.
Widget _fr(Object title, Widget child,
    {Widget? right, double rightTop = -7, EdgeInsets pad = const EdgeInsets.fromLTRB(10, 14, 10, 8)}) {
  final spans = title is String ? [_tg(title)] : title as List<InlineSpan>;
  return Stack(clipBehavior: Clip.none, fit: StackFit.passthrough, children: [
    Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border.all(color: _frc), borderRadius: BorderRadius.circular(4)),
      ),
    ),
    Padding(padding: pad + const EdgeInsets.all(1), child: child),
    Positioned(
      top: -7,
      left: 8,
      child: Container(
        color: CockpitSkin.plate,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Text.rich(TextSpan(style: _sans(10, b: true, ls: 1, c: _gy), children: spans),
            maxLines: 1, softWrap: false),
      ),
    ),
    if (right != null) Positioned(top: rightTop, right: 8, child: right),
  ]);
}

/// Frame around artwork (`.artfr`).
Widget _artfr(Widget child) => Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(border: Border.all(color: _frc), borderRadius: BorderRadius.circular(4)),
      child: ClipRRect(borderRadius: BorderRadius.circular(2), child: child),
    );

// ------------------------------------------------------------------ memo (ECAM leaders)

class _Leader extends CustomPainter {
  const _Leader(this.c);
  final Color c;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = c.withValues(alpha: .5);
    final y = size.height - 4 - 1.5;
    for (double x = 0; x + 1.5 <= size.width; x += 3) {
      canvas.drawRect(Rect.fromLTWH(x, y, 1.5, 1.5), p);
    }
  }

  @override
  bool shouldRepaint(_Leader o) => o.c != c;
}

/// One `.memo` line: LABEL ......... value
Widget _lead(String l, String r, [Color c = _g]) => LayoutBuilder(
      builder: (context, box) => Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(l, style: _mono(12.5, c: c), maxLines: 1, softWrap: false),
        const SizedBox(width: 6),
        Expanded(child: SizedBox(height: 16, child: CustomPaint(painter: _Leader(c)))),
        const SizedBox(width: 6),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: box.maxWidth * .66),
          child: Text(r, style: _mono(12.5, c: c), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ]),
    );

Widget _memo(List<(String, String, Color)> rows) => Column(mainAxisSize: MainAxisSize.min, children: [
      for (final (i, (l, r, c)) in rows.indexed) ...[
        if (i > 0) const SizedBox(height: 7),
        _lead(l, r, c),
      ],
    ]);

// ------------------------------------------------------------------ buttons

/// `.btn`: outlined square-cornered key; fills while pressed or when [on].
class _Btn extends StatefulWidget {
  const _Btn({
    this.label,
    this.icon,
    this.onTap,
    this.color = _c,
    this.on = false,
    this.height = 36,
    this.hpad = 16,
    this.size = 11.5,
    this.trailing,
    this.mask = false,
  });
  final String? label, icon;
  final VoidCallback? onTap;
  final Color color;
  final bool on;
  final double height, hpad, size;

  /// Right-aligned content (timer mode minutes); label goes left.
  final Widget Function(Color fg)? trailing;

  /// Paint the frame-plate colour behind (for tabs that sit on a frame border).
  final bool mask;

  @override
  State<_Btn> createState() => _BtnState();
}

class _BtnState extends State<_Btn> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final filled = w.on || _down;
    final fg = filled ? _bg : w.color;
    final kids = <Widget>[
      if (w.icon != null) DpIcon(w.icon!, size: 18, color: fg),
      if (w.icon != null && w.label != null) const SizedBox(width: 8),
      if (w.label != null)
        Flexible(
          fit: w.trailing == null ? FlexFit.loose : FlexFit.tight,
          child: Text(w.label!.toUpperCase(),
              maxLines: 1, overflow: TextOverflow.clip, softWrap: false, style: _sans(w.size, b: true, ls: w.size * .08, c: fg, h: 1)),
        ),
    ];
    Widget box = AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      height: w.height,
      padding: EdgeInsets.symmetric(horizontal: w.hpad),
      decoration: BoxDecoration(
        color: filled ? w.color : (w.mask ? CockpitSkin.plate : null),
        border: Border.all(color: w.color, width: 1.5),
        borderRadius: BorderRadius.circular(3),
      ),
      child: w.trailing == null
          ? Align(widthFactor: 1, child: Row(mainAxisSize: MainAxisSize.min, children: kids))
          : Row(children: [...kids, w.trailing!(fg)]),
    );
    if (w.onTap == null) return Opacity(opacity: .55, child: box);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: w.onTap,
      child: box,
    );
  }
}

Widget _tabs(WidgetRef ref) =>
    _tabRow(const ['Laptop', 'Internet'], ref.watch(systemTabProvider), ref.read(systemTabProvider.notifier).set);

/// Latching buttons riding a frame's top edge (the System Laptop | Internet switch).
Widget _tabRow(List<String> items, int tab, ValueChanged<int> set) => Row(mainAxisSize: MainAxisSize.min, children: [
      for (final (i, l) in items.indexed) ...[
        if (i > 0) const SizedBox(width: 6),
        _Btn(label: l, height: 24, hpad: 10, size: 10.5, on: tab == i, mask: true, onTap: () => set(i)),
      ],
    ]);

// ------------------------------------------------------------------ text painting

void _text(Canvas cv, String s, TextStyle st, double x, double baseline, {TextAlign align = TextAlign.center}) {
  final tp = TextPainter(text: TextSpan(text: s, style: st), textDirection: TextDirection.ltr)..layout();
  final b = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  final dx = switch (align) {
    TextAlign.center => x - tp.width / 2,
    TextAlign.right || TextAlign.end => x - tp.width,
    _ => x,
  };
  tp.paint(cv, Offset(dx, baseline - b));
}

Offset _p(double cx, double cy, double r, double deg) =>
    Offset(cx + r * math.sin(deg * math.pi / 180), cy - r * math.cos(deg * math.pi / 180));

Path _arc(double cx, double cy, double r, double a0, double a1) =>
    Path()..addArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), (a0 - 90) * math.pi / 180, (a1 - a0) * math.pi / 180);

Paint _stroke(Color c, double w, {StrokeCap cap = StrokeCap.butt}) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = cap
  ..color = c;

// ------------------------------------------------------------------ engine dial

typedef _Zones = List<(double, double, Color)>;

const _std = <(double, double, Color)>[(0, 70, _g), (70, 90, _a), (90, 100, _r)];
const _usage = <(double, double, Color)>[(0, 50, _g), (50, 80, _a), (80, 100, _r)];

Color _zoneColor(_Zones z, double v) {
  for (final (f, t, c) in z) {
    if (v >= f && v <= t) return c;
  }
  return z.last.$3;
}

/// Engine-style dial: 240° scale, caution/warning zone arcs, sweep, needle, magenta target
/// bug and a boxed digital readout (concept `dial()`), fit into the box like an SVG.
class _Dial extends StatelessWidget {
  const _Dial({
    required this.value,
    this.max = 100,
    this.zones = _std,
    this.target,
    this.label,
    this.sub,
    this.unit = '%',
    this.text,
  });
  final double? value;
  final double max;
  static const double min = 0;
  final _Zones zones;
  final double? target;
  final String? label, sub, unit, text;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(end: (value ?? min).clamp(min, max).toDouble()),
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => CustomPaint(painter: _DialPainter(this, v), size: Size.infinite),
      );
}

class _DialPainter extends CustomPainter {
  _DialPainter(this.d, this.v);
  final _Dial d;
  final double v;

  @override
  void paint(Canvas canvas, Size size) {
    const cx = 60.0, cy = 56.0, r = 40.0, a0 = -120.0, a1 = 120.0;
    final vh = d.sub != null ? 118.0 : (d.label != null ? 108.0 : 92.0);
    final s = math.min(size.width / 120, size.height / vh);
    canvas.save();
    canvas.translate((size.width - 120 * s) / 2, (size.height - vh * s) / 2);
    canvas.scale(s);
    double ang(double x) => a0 + (x.clamp(_Dial.min, d.max) - _Dial.min) / (d.max - _Dial.min) * (a1 - a0);
    final real = d.value;
    final zc = real == null ? _gy : _zoneColor(d.zones, real);

    canvas.drawPath(_arc(cx, cy, r, a0, a1), _stroke(_w, 1.6));
    for (final (f, t, c) in d.zones) {
      if (c != _g) canvas.drawPath(_arc(cx, cy, r + 4, ang(f), ang(t)), _stroke(c, 3));
    }
    for (var i = 0; i <= 10; i++) {
      final a = a0 + i * 24;
      canvas.drawLine(_p(cx, cy, r, a), _p(cx, cy, r - (i % 5 != 0 ? 4 : 7), a), _stroke(_w, 1.4));
    }
    String lab(double x) => x == x.roundToDouble() ? x.round().toString() : x.toString();
    for (final (x, a) in [(_Dial.min, a0), (d.max, a1)]) {
      final p = _p(cx, cy, r - 15, a);
      _text(canvas, lab(x), _sans(7.5, c: _gy, h: 1), p.dx, p.dy + 3);
    }
    if (v > _Dial.min) {
      final av = ang(v);
      final path = Path()
        ..moveTo(cx, cy)
        ..lineTo(_p(cx, cy, r - 1, a0).dx, _p(cx, cy, r - 1, a0).dy)
        ..arcTo(Rect.fromCircle(center: const Offset(cx, cy), radius: r - 1), (a0 - 90) * math.pi / 180,
            (av - a0) * math.pi / 180, false)
        ..close();
      canvas.drawPath(path, Paint()..color = zc.withValues(alpha: .14));
    }
    if (d.target != null) {
      final a = ang(d.target!);
      final path = Path()
        ..moveTo(_p(cx, cy, r + 5, a).dx, _p(cx, cy, r + 5, a).dy)
        ..lineTo(_p(cx, cy, r + 11, a - 5).dx, _p(cx, cy, r + 11, a - 5).dy)
        ..lineTo(_p(cx, cy, r + 11, a + 5).dx, _p(cx, cy, r + 11, a + 5).dy)
        ..close();
      canvas.drawPath(path, Paint()..color = _m);
    }
    canvas.drawLine(const Offset(cx, cy), _p(cx, cy, r - 3, ang(v)), _stroke(_w, 2.4, cap: StrokeCap.round));
    canvas.drawCircle(const Offset(cx, cy), 2.6, Paint()..color = _w);

    final txt = d.text ?? (real == null ? 'N/A' : '${real.round()}${d.unit ?? ''}');
    final bw = math.max(30.0, txt.length * 7.4 + 10);
    final box = Rect.fromLTWH(cx - bw / 2, cy + 14, bw, 17);
    canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(1)), Paint()..color = _bg);
    canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(1)), _stroke(_w, 1.2));
    _text(canvas, txt, _mono(12.5, c: zc, h: 1), cx, cy + 27);
    if (d.label != null) _text(canvas, d.label!, _sans(8.5, b: true, ls: .9, h: 1), cx, cy + 46);
    if (d.sub != null) _text(canvas, d.sub!, _sans(7.5, c: _gy, h: 1), cx, cy + 57);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DialPainter o) =>
      o.v != v || o.d.value != d.value || o.d.text != d.text || o.d.sub != d.sub || o.d.target != d.target;
}

// ------------------------------------------------------------------ trend chart

/// Framed trend with dashed 4×6 grid (concept `trend()`).
class _Trend extends CustomPainter {
  _Trend(this.series, this.lo, this.hi);
  final List<(List<double?>, Color)> series;
  final double lo, hi;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final gp = _stroke(_frc, 1);
    void dash(Offset a, Offset b) {
      final len = (b - a).distance;
      final dir = (b - a) / len;
      for (double t = 0; t < len; t += 6) {
        canvas.drawLine(a + dir * t, a + dir * math.min(t + 2, len), gp);
      }
    }

    for (var i = 1; i < 4; i++) {
      dash(Offset(0, h * i / 4), Offset(w, h * i / 4));
    }
    for (var i = 1; i < 6; i++) {
      dash(Offset(w * i / 6, 0), Offset(w * i / 6, h));
    }
    canvas.drawRect(Rect.fromLTWH(.5, .5, w - 1, h - 1), gp);
    const pad = 3.0;
    double y(double v) => pad + (h - 2 * pad) * (1 - (v.clamp(lo, hi) - lo) / (hi - lo));
    for (final (vals, c) in series) {
      if (vals.length < 2) continue;
      final dx = w / (vals.length - 1);
      final p = Path();
      double? px, py;
      for (var i = 0; i < vals.length; i++) {
        final v = vals[i];
        if (v == null) {
          px = null;
          continue;
        }
        final x = i * dx, yy = y(v);
        if (px == null) {
          p.moveTo(x, yy);
        } else {
          final xm = (px + x) / 2;
          p.cubicTo(xm, py!, xm, yy, x, yy);
        }
        px = x;
        py = yy;
      }
      canvas.drawPath(p, _stroke(c, 1.8)..strokeJoin = StrokeJoin.round);
    }
  }

  @override
  bool shouldRepaint(_Trend o) => true;
}

Widget _trend(List<(List<double?>, Color)> series, {double lo = 0, double hi = 100}) =>
    CustomPaint(painter: _Trend(series, lo, hi), size: Size.infinite);

// ------------------------------------------------------------------ bars

/// Vertical bar chart (`.bars`): value on top, bar, label; [hi] marks today in green.
class _Bars extends StatelessWidget {
  const _Bars(this.items);

  /// (label, value text, height fraction 0..1, highlighted)
  final List<(String, String, double, bool)> items;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) => Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (final (i, (l, v, f, hi)) in items.indexed) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text(v, style: _mono(10, b: true, c: hi ? _g : _c, h: 1.2), maxLines: 1),
                const SizedBox(height: 4),
                TweenAnimationBuilder<double>(
                  tween: Tween(end: math.max(2, math.min(box.maxHeight * f, box.maxHeight - 34))),
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.easeOutCubic,
                  builder: (context, h, _) => Container(width: hi ? 11 : 9, height: h, color: hi ? _g : _c),
                ),
                const SizedBox(height: 4),
                Text(l, style: _sans(10, b: true, ls: .6, c: hi ? _g : _gy, h: 1.2), maxLines: 1),
              ]),
            ),
          ],
        ]),
      );
}

// ------------------------------------------------------------------ tables

Widget _th(String s, {bool right = false}) => Padding(
      padding: EdgeInsets.only(right: right ? 0 : 8, bottom: 6),
      child: Text(s, style: _sans(10, b: true, ls: 1, c: _gy), textAlign: right ? TextAlign.right : TextAlign.left),
    );

Widget _td(Object v, {Color c = _w, bool right = false, bool upper = true, double vpad = 5}) => Padding(
      padding: EdgeInsets.fromLTRB(0, vpad, right ? 0 : 8, vpad),
      child: v is Widget
          ? Align(alignment: right ? Alignment.centerRight : Alignment.centerLeft, child: v)
          : Text(upper ? '$v'.toUpperCase() : '$v',
              style: _mono(12.5, c: c),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              textAlign: right ? TextAlign.right : TextAlign.left),
    );

TableRow _tr(List<Widget> cells) => TableRow(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: _fr2))),
      children: cells,
    );

Widget _table({List<Widget>? head, required List<TableRow> rows, required Map<int, TableColumnWidth> widths}) => Table(
      columnWidths: widths,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [if (head != null) TableRow(children: head), ...rows],
    );

// ------------------------------------------------------------------ Home

class _Home extends ConsumerWidget {
  const _Home();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tm = ref.watch(timerProvider);
    return Ticker(
      period: tm.running ? const Duration(seconds: 1) : const Duration(minutes: 1),
      builder: (context, now) => Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(flex: 100, child: _time(context, ref, now, tm)),
        const SizedBox(width: _gap),
        Expanded(flex: 125, child: _engines(context, ref, now)),
        const SizedBox(width: _gap),
        Expanded(flex: 115, child: _memoFrame(context, ref, now)),
      ]),
    );
  }

  Widget _time(BuildContext context, WidgetRef ref, DateTime now, TimerState tm) {
    final h24 = ref.watch(settingsProvider.select((s) => s.clock24));
    final events = ref.watch(calendarEventsProvider);
    final n = nextEvent(events, now);
    // When today's last timed event ends (the calendar-magenta line under FOCUS).
    final ends = [for (final e in events) if (!e.allDay && sameDay(e.start, now) && e.end.isAfter(now)) e.end];
    final freeAt = ends.isEmpty ? null : ends.reduce((a, b) => a.isAfter(b) ? a : b);
    return _fr(
      'Time',
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(clock(now, h24: h24), style: _mono(64, h: 1)),
            ),
          ),
          const SizedBox(width: 6),
          Text(_ampm(now, h24), style: _mono(20, c: _gy, h: 1)),
        ]),
        const SizedBox(height: 6),
        _cap(longDate(now)),
        const SizedBox(height: 16),
        _memo([
          (tm.mode.isPomodoro ? 'FOCUS' : tm.mode.label.toUpperCase(), _ms(tm.display(now)), _w),
          ('FREE AFTER', freeAt == null ? 'NOW' : clockFull(freeAt, h24: h24), _m),
        ]),
        const Spacer(),
        Press(
          onTap: () => PageNav.go(context, PageId.calendar),
          scale: .99,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 8),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: _frc))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _cap('Next', c: _m),
              const SizedBox(height: 3),
              Text(n == null ? 'NONE TODAY' : n.title.toUpperCase(),
                  style: _sans(15, b: true, c: _m), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(
                  n == null
                      ? 'FREE UNTIL TOMORROW'
                      : '${_inText(n, now)}, ${n.allDay ? 'all day' : clockFull(n.start, h24: h24)}'.toUpperCase(),
                  style: _mono(12, c: _m),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _engines(BuildContext context, WidgetRef ref, DateTime now) {
    final s = topicData<SystemData>(ref, 'system');
    final c = topicData<ClaudeData>(ref, 'claude');
    final gpuOk = s != null && s.gpu.available;
    final ramOk = s != null && s.ramTotal > 0;
    const gb = 1024 * 1024 * 1024;
    Widget cell(Widget d, PageId to) =>
        Expanded(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => PageNav.go(context, to), child: d));
    return _fr(
      'Engines',
      Column(children: [
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            cell(_Dial(value: s?.cpu.pct, label: 'CPU'), PageId.system),
            const SizedBox(width: 2),
            cell(
                _Dial(
                    value: gpuOk ? s.gpu.pct : null,
                    label: 'GPU',
                    sub: gpuOk && s.gpu.tempC != null ? '${s.gpu.tempC!.round()}°C' : (gpuOk ? ' ' : 'N/A')),
                PageId.system),
          ]),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            cell(
                _Dial(
                    value: c?.fiveHour == null ? null : limitPct(c!.fiveHour, now),
                    label: '5-HOUR',
                    zones: _usage),
                PageId.claude),
            const SizedBox(width: 2),
            cell(
                _Dial(
                    value: ramOk ? s.ramUsed / s.ramTotal * 100 : null,
                    label: 'RAM',
                    sub: ramOk ? '${(s.ramUsed / gb).toStringAsFixed(1)}/${(s.ramTotal / gb).round()} GB' : ' '),
                PageId.system),
          ]),
        ),
      ]),
    );
  }

  Widget _memoFrame(BuildContext context, WidgetRef ref, DateTime now) {
    final settings = ref.watch(settingsProvider);
    final f = settings.fahrenheit;
    final sl = slackHome(ref);
    final slTop = sl.latest;
    final c = topicData<ClaudeData>(ref, 'claude');
    final m = topicData<MediaData>(ref, 'media');
    final w = ref.watch(weatherProvider);
    final conn = ref.watch(agentProvider);
    final five = limitPct(c?.fiveHour, now), week = limitPct(c?.sevenDay, now);
    final reset = c?.fiveHour?.resetsAt;
    final link = switch (conn.status) {
      LinkStatus.connected => conn.transport == Transport.usb ? 'USB' : 'Wi-Fi',
      LinkStatus.demo => 'Demo',
      _ => connSummary(conn).text,
    };
    return _fr(
      'Memo',
      Column(children: [
        const SizedBox(height: 4),
        // SLACK ..... 3 UNREAD (amber), then the newest sender and one line; green and calm
        // once everything is read.
        Press(
          onTap: () => PageNav.go(context, PageId.slack),
          scale: .99,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _lead('SLACK', (sl.headline == 'Slack' ? sl.detail : sl.headline).toUpperCase(), slTop == null ? _g : _a),
            if (slTop != null || sl.headline != 'Slack') ...[
              const SizedBox(height: 3),
              Text.rich(
                slTop == null
                    ? TextSpan(text: sl.detail, style: _sans(11.5, c: _gy))
                    : TextSpan(children: [
                        TextSpan(text: '${slTop.sender.toUpperCase()}  ', style: _mono(11.5, b: true, c: _c)),
                        TextSpan(text: slTop.text, style: _sans(11.5, c: _w)),
                      ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ]),
        ),
        const SizedBox(height: 7),
        _memo([
          (
            'CLAUDE 5H',
            c?.fiveHour == null
                ? '—'
                : '${five.round()}%${reset != null && !c!.fiveHour!.isExpired(now) ? ', RST ${dur(reset.difference(now))}' : ''}',
            c?.fiveHour == null ? _g : _zoneColor(_usage, five)
          ),
          ('CLAUDE WEEK', c?.sevenDay == null ? '—' : '${week.round()}%', c?.sevenDay == null ? _g : _zoneColor(_usage, week)),
          ('WX', w == null ? '—' : '${temp(w.now.tempC, f)}°${f ? 'F' : 'C'} ${w.now.condition.toUpperCase()}', _g),
          ('WIND', w == null ? '—' : wind(w.now.windKmh, f).toUpperCase(), _g),
          ('MUSIC', m?.title ?? '—', _c),
          ('LINK', link, conn.live ? _g : _a),
        ]),
        const Spacer(),
        Row(children: [
          _Btn(
              icon: m?.playing == true ? 'pause' : 'play',
              hpad: 14,
              onTap: m?.title == null ? null : () => act(context, ref, 'media.play_pause')),
          const SizedBox(width: 6),
          Expanded(child: _Btn(label: 'System page', onTap: () => PageNav.go(context, PageId.system))),
        ]),
      ]),
    );
  }
}

// ------------------------------------------------------------------ System

class _System extends ConsumerWidget {
  const _System();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(systemTabProvider) == 0 ? const _Pc() : const _Internet();
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
    final vramPct = g.available && g.vramUsed != null && (g.vramTotal ?? 0) > 0 ? g.vramUsed! / g.vramTotal! * 100 : null;
    final f = ref.watch(settingsProvider).fahrenheit;
    final cpuTemp = s.cpu.tempC == null ? null : '${temp(s.cpu.tempC!, f)}°${f ? 'F' : 'C'}';
    return Column(children: [
      Expanded(
        flex: 115,
        child: _fr(
          'Laptop',
          right: _tabs(ref),
          rightTop: -12,
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: _Dial(value: s.cpu.pct, label: 'CPU', sub: cpuTemp)),
              const SizedBox(width: _gap),
              Expanded(
                child: _Dial(
                  value: g.available ? g.pct : null,
                  label: 'GPU',
                  sub: !g.available ? 'N/A' : (g.tempC != null ? '${g.tempC!.round()}°C' : (g.model ?? ' ')),
                ),
              ),
              const SizedBox(width: _gap),
              Expanded(
                child: _Dial(
                  value: s.ramUsed / s.ramTotal * 100,
                  label: 'RAM',
                  sub: '${(s.ramUsed / gb).toStringAsFixed(1)}/${(s.ramTotal / gb).round()} GB',
                ),
              ),
              const SizedBox(width: _gap),
              Expanded(
                child: _Dial(
                  value: vramPct,
                  label: g.vramLabel.toUpperCase(),
                  sub: vramPct == null ? 'N/A' : '${(g.vramUsed! / gb).toStringAsFixed(1)}/${(g.vramTotal! / gb).round()} GB',
                ),
              ),
            ]),
          ),
        ),
      ),
      const SizedBox(height: _gap),
      Expanded(
        flex: 100,
        child: _fr(
          [_tg('Trend '), _tb('CPU'), _tg(' '), if (g.available) _tb('GPU', _g), _tg(', 60 s')],
          right: Container(
            color: CockpitSkin.plate,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Text('$down ${downU.toUpperCase()} DN   $up ${upU.toUpperCase()} UP',
                style: _mono(11, c: _g, b: true, h: 13 / 11)),
          ),
          Column(children: [
            const SizedBox(height: 2),
            Expanded(
              child: _trend([
                if (g.available) (s.gpuHistory, _g),
                (s.cpuHistory, _c),
              ]),
            ),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: _cap('${s.cpu.model}${g.model != null ? ' / ${g.model}' : ''}')),
              const SizedBox(width: 8),
              _capRich([('Disk ', null), ('${s.diskPct.round()}%', _g)]),
            ]),
          ]),
        ),
      ),
    ]);
  }
}

class _Internet extends ConsumerWidget {
  const _Internet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = topicData<NetworkData>(ref, 'network');
    if (n == null) {
      return _fr('Link', right: _tabs(ref), rightTop: -12, Center(child: _cap('Waiting for network data…')));
    }
    final live = ref.watch(agentProvider).live;
    final sys = topicData<SystemData>(ref, 'system');
    final now = DateTime.now();
    final st = n.speedtest;
    final last = st.last, prog = st.progress;
    final dl = st.running ? prog?.downBps : last?.downBps;
    final ul = st.running ? prog?.upBps : last?.upBps;
    Widget ro(String v) => Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
          decoration: BoxDecoration(border: Border.all(color: _w, width: 1.5), borderRadius: BorderRadius.circular(2)),
          child: Text(v, style: _mono(26, c: _g, h: 1.15)),
        );
    final status = !live ? ('NO DATA', _a) : (n.online ? ('ONLINE', _g) : ('OFFLINE', _r));
    return Column(children: [
      Expanded(
        flex: 110,
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            flex: 90,
            child: _fr(
              'Link',
              right: _tabs(ref),
              rightTop: -12,
              Column(children: [
                Expanded(
                  child: _Dial(
                    value: n.latencyMs,
                    max: 100,
                    unit: ' ms',
                    text: n.latencyMs == null ? 'TIMEOUT' : null,
                    label: 'LATENCY',
                    zones: const [(0, 40, _g), (40, 80, _a), (80, 100, _r)],
                  ),
                ),
                _capRich([
                  ('Jitter ', null),
                  ('${n.jitterMs?.toStringAsFixed(1) ?? '—'} ms', _g),
                  (' Loss ', null),
                  ('${n.lossPct.round()}%', _g),
                ], align: TextAlign.center),
              ]),
            ),
          ),
          const SizedBox(width: _gap),
          Expanded(
            flex: 100,
            child: _fr(
              'Status',
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 6),
                Text(status.$1, style: _sans(26, b: true, c: status.$2, h: 1.2)),
                const SizedBox(height: 12),
                _memo([
                  ('UPTIME', n.onlineSince == null ? '—' : durLong(now.difference(n.onlineSince!)).toUpperCase(), _w),
                  ('LAST DROP', n.lastDrop == null ? 'NONE' : ago(now.difference(n.lastDrop!)).toUpperCase(), _w),
                  ('TODAY', bytes(n.usageToday), _g),
                  ('MONTH', bytes(n.usageMonth, digits: 0), _g),
                ]),
              ]),
            ),
          ),
          const SizedBox(width: _gap),
          Expanded(
            flex: 125,
            child: _fr(
              'Speed test',
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SizedBox(height: 8),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _cap('Down'),
                    ro(dl == null ? '—' : mbps(dl)),
                  ]),
                  const SizedBox(width: 14),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _cap('Up'),
                    ro(ul == null ? '—' : mbps(ul)),
                  ]),
                  const SizedBox(width: 14),
                  Padding(padding: const EdgeInsets.only(bottom: 2), child: _cap('Mbps')),
                ]),
                const SizedBox(height: 10),
                st.running
                    ? _cap('Testing now${prog != null ? ', ${prog.phase}' : ''}')
                    : last == null
                        ? _cap('Never tested')
                        : _capRich([
                            ('Tested ${ago(now.difference(last.at))}, ping ', null),
                            ('${last.pingMs.round()} ms', _g),
                          ]),
                if (st.running) ...[
                  const SizedBox(height: 8),
                  _hbar((prog?.pct ?? 0) / 100),
                ],
                const Spacer(),
                _Btn(
                  label: st.running ? 'Testing…' : 'Run test',
                  onTap: st.running
                      ? null
                      : () => act(context, ref, 'speedtest.run', const {}, null, null, const Duration(seconds: 90)),
                ),
              ]),
            ),
          ),
        ]),
      ),
      const SizedBox(height: _gap),
      Expanded(
        flex: 100,
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            flex: 125,
            child: _fr('Latency trend, 2 min, 0 to 50 ms', _trend([(n.latencyHistory, _g)], hi: 50)),
          ),
          if (sys != null) ...[
            const SizedBox(width: _gap),
            Expanded(flex: 100, child: _macNet(sys)),
          ],
        ]),
      ),
    ]);
  }
}

/// The Mac's own traffic right now: DN / UP readouts on the frame plate and the last
/// minute as a trend (down green, up cyan) on a shared scale.
Widget _macNet(SystemData s) {
  final (down, downU) = rate(s.downBps);
  final (up, upU) = rate(s.upBps);
  final hi = maxOf([...s.downHistory, ...s.upHistory, s.downBps, s.upBps], floor: 64 * 1024) * 1.15;
  final (top, topU) = rate(hi);
  return _fr(
    [_tg('Mac net '), _tb('DN', _g), _tg(' '), _tb('UP'), _tg(', 60 s')],
    right: Container(
      color: CockpitSkin.plate,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: '$down ${downU.toUpperCase()} DN', style: _mono(11, c: _g, b: true, h: 13 / 11)),
          TextSpan(text: '   $up ${upU.toUpperCase()} UP', style: _mono(11, c: _c, b: true, h: 13 / 11)),
        ]),
        maxLines: 1,
        softWrap: false,
      ),
    ),
    s.downHistory.length < 2
        ? Center(child: _cap('Collecting…'))
        : Stack(children: [
            Positioned.fill(child: _trend([(s.upHistory, _c), (s.downHistory, _g)], hi: hi)),
            // Full-scale label in the corner, like an MFD trend.
            Positioned(
              left: 4,
              top: 4,
              child: Container(
                color: _bg,
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _cap('$top ${topU.toUpperCase()}'),
              ),
            ),
          ]),
  );
}

Widget _hbar(double p, {Color c = _c}) => SizedBox(
      height: 5,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: p.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 400),
        builder: (context, v, _) => Container(
          color: _fr2,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(widthFactor: v, heightFactor: 1, child: ColoredBox(color: c)),
        ),
      ),
    );

// ------------------------------------------------------------------ Claude

class _Claude extends ConsumerWidget {
  const _Claude();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = topicData<ClaudeData>(ref, 'claude')!;
    final h24 = ref.watch(settingsProvider.select((s) => s.clock24));
    return Ticker(builder: (context, now) {
      final five = limitPct(c.fiveHour, now), week = limitPct(c.sevenDay, now);
      Widget limit(LimitWindow? w, double pct, String label, List<(String, Color?)> cap) => Expanded(
            child: _fr(
              'Limit',
              Column(children: [
                Expanded(child: _Dial(value: w == null ? null : pct, label: label, zones: _usage)),
                _capRich(cap, align: TextAlign.center),
              ]),
            ),
          );
      final fiveCol = _zoneColor(_usage, five), weekCol = _zoneColor(_usage, week);
      final fiveCap = c.fiveHour?.resetsAt == null
          ? [('No data yet', null)]
          : c.fiveHour!.isExpired(now)
              ? [('Window has reset', null)]
              : [('Reset in ', null), (dur(c.fiveHour!.resetsAt!.difference(now)).toUpperCase(), fiveCol)];
      final r7 = c.sevenDay?.resetsAt?.toLocal();
      final weekCap = r7 == null
          ? [('No data yet', null)]
          : c.sevenDay!.isExpired(now)
              ? [('Window has reset', null)]
              : [('Reset ', null), ('${weekday3(r7)} ${clockFull(r7, h24: h24)}'.toUpperCase(), weekCol)];
      final peak = maxOf(c.days.map((d) => d.tokens));
      return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          flex: 200,
          child: Column(children: [
            Expanded(
              flex: 120,
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                limit(c.fiveHour, five, '5-HOUR', fiveCap),
                const SizedBox(width: _gap),
                limit(c.sevenDay, week, 'WEEKLY', weekCap),
              ]),
            ),
            const SizedBox(height: _gap),
            Expanded(
              flex: 100,
              child: _fr(
                'Tokens, 7 days, peak ${compact(peak)}',
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: _Bars([
                    for (final (i, d) in c.days.indexed)
                      (
                        i == c.days.length - 1 ? 'TOD' : dayLabel(d.date, now).substring(0, 3).toUpperCase(),
                        (d.tokens / 1e6).toStringAsFixed(0),
                        d.tokens / peak * .8,
                        i == c.days.length - 1,
                      ),
                  ]),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(width: _gap),
        Expanded(
          flex: 115,
          child: _fr(
            'Today',
            Column(children: [
              const SizedBox(height: 4),
              _memo([
                ('TOKENS', compact(c.tokens), _g),
                ('OUTPUT', compact(c.outputTokens), _g),
                ('MESSAGES', '${c.messages}', _g),
                ('LAST HOUR', compact(c.lastHourTokens), _g),
              ]),
              const Spacer(),
              if (c.modelsToday.isEmpty) _cap('No messages yet today'),
              _memo([for (final m in c.modelsToday.take(4)) (m.family.toUpperCase(), compact(m.tokens), _c)]),
            ]),
          ),
        ),
      ]);
    });
  }
}

// ------------------------------------------------------------------ Calendar

class _Calendar extends ConsumerWidget {
  const _Calendar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(calendarEventsProvider);
    final h24 = ref.watch(settingsProvider.select((s) => s.clock24));
    return Ticker(builder: (context, now) {
      final split = splitEvents(events, now);
      final n = nextEvent(events, now);
      return Column(children: [
        _fr(
          [_tg('Today, '), _tb(longDate(now))],
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: SizedBox(
              height: 74,
              child: CustomPaint(painter: _TimeTape(split.today, n, now, h24), size: Size.infinite),
            ),
          ),
        ),
        const SizedBox(height: _gap),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              flex: 160,
              child: _fr(
                'Plan',
                split.today.isEmpty
                    ? Align(alignment: Alignment.topLeft, child: Padding(padding: const EdgeInsets.only(top: 6), child: _cap('Nothing on the calendar today')))
                    : SingleChildScrollView(
                        child: _table(
                          widths: const {0: FlexColumnWidth(1.05), 1: FlexColumnWidth(1.75), 2: FlexColumnWidth(1.75), 3: FlexColumnWidth(1)},
                          head: [_th('Time'), _th('Event'), _th('Where'), _th('To go', right: true)],
                          rows: [
                            for (final e in split.today)
                              () {
                                final col = e == n ? _m : (e.end.isBefore(now) ? _gy : _w);
                                final togo = e == n
                                    ? _inText(e, now)
                                    : !e.start.isAfter(now)
                                        ? 'Done'
                                        : dur(e.start.difference(now));
                                return _tr([
                                  _td(e.allDay ? 'All day' : clockFull(e.start, h24: h24), c: col),
                                  _td(e.title, c: col),
                                  _td(e.location ?? e.calendar ?? '', c: col),
                                  _td(togo, c: col, right: true),
                                ]);
                              }(),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(width: _gap),
            Expanded(
              flex: 100,
              child: _fr(
                'Later',
                split.later.isEmpty
                    ? Align(alignment: Alignment.topLeft, child: Padding(padding: const EdgeInsets.only(top: 6), child: _cap('Nothing in the next 7 days')))
                    : SingleChildScrollView(
                        child: _table(
                          widths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth(), 2: IntrinsicColumnWidth()},
                          rows: [
                            for (final e in split.later)
                              _tr([
                                _td(weekday3(e.start), c: _c),
                                _td(e.title),
                                _td(e.allDay ? 'All day' : clockFull(e.start, h24: h24), c: _gy, right: true),
                              ]),
                          ],
                        ),
                      ),
              ),
            ),
          ]),
        ),
      ]);
    });
  }
}

/// Horizontal time tape: hour scale, event blocks (magenta = next, grey = past), and a
/// green "now" pointer.
class _TimeTape extends CustomPainter {
  _TimeTape(this.events, this.next, this.now, this.h24);
  final List<CalEvent> events;
  final CalEvent? next;
  final DateTime now;
  final bool h24;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final day = DateTime(now.year, now.month, now.day);
    double mins(DateTime t) => t.difference(day).inSeconds / 60;
    final timed = events.where((e) => !e.allDay).toList();
    var h0 = 7, h1 = 19;
    final nm = mins(now);
    h0 = math.min(h0, (nm / 60).floor());
    h1 = math.max(h1, (nm / 60).ceil());
    for (final e in timed) {
      h0 = math.min(h0, (mins(e.start) / 60).floor());
      h1 = math.max(h1, (math.min(mins(e.end), 24 * 60) / 60).ceil());
    }
    h0 = h0.clamp(0, 23);
    h1 = h1.clamp(h0 + 1, 24);
    double x(double m) => (m / 60 - h0) / (h1 - h0) * w;
    final base = h - 18;
    canvas.drawLine(Offset(0, base), Offset(w, base), _stroke(_w, 1.2));
    for (var hr = h0; hr <= h1; hr++) {
      final xx = x(hr * 60.0);
      canvas.drawLine(Offset(xx, base), Offset(xx, base + (hr.isOdd ? 4 : 7)), _stroke(_w, 1.2));
      if (hr.isEven) _text(canvas, two(hr % 24 == 0 && hr > 0 ? 24 : hr), _sans(10, c: _gy, h: 1), xx, h - 1);
    }
    for (var hr = h0; hr < h1; hr++) {
      for (final q in const [15, 30, 45]) {
        final xx = x(hr * 60.0 + q);
        canvas.drawLine(Offset(xx, base), Offset(xx, base + 2), _stroke(_gy, 1));
      }
    }
    for (final e in timed) {
      final x0 = x(mins(e.start)), x1 = math.max(x(mins(e.end)), x0 + 5);
      final c = e == next ? _m : (e.end.isBefore(now) ? _gy : _c);
      canvas.drawRect(Rect.fromLTWH(x0, h - 32, x1 - x0, 9), Paint()..color = c.withValues(alpha: .85));
      _text(canvas, e.title.toUpperCase(), _sans(10, b: true, c: c, h: 1), x0, h - 38, align: TextAlign.left);
    }
    final xn = x(nm);
    canvas.drawPath(
        Path()
          ..moveTo(xn, base)
          ..lineTo(xn - 6, base - 10)
          ..lineTo(xn + 6, base - 10)
          ..close(),
        Paint()..color = _g);
    for (double y = 4; y < h - 28; y += 6) {
      canvas.drawLine(Offset(xn, y), Offset(xn, math.min(y + 3, h - 28)), _stroke(_g, 1));
    }
    _text(canvas, clock(now, h24: h24), _mono(11, c: _g, h: 1), xn + 6, 12, align: TextAlign.left);
  }

  @override
  bool shouldRepaint(_TimeTape o) => true;
}

// ------------------------------------------------------------------ Weather

class _Weather extends ConsumerWidget {
  const _Weather();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(weatherProvider);
    final s = ref.watch(settingsProvider);
    if (w == null) {
      return _fr('Weather', Center(child: _cap('Set your location in Settings → Weather')));
    }
    final f = s.fahrenheit;
    int t(double c) => temp(c, f);
    return Column(children: [
      Expanded(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            flex: 70,
            child: _fr('Temp °${f ? 'F' : 'C'}',
                CustomPaint(
                    painter: _TempTape(t(w.now.tempC), w.days.isEmpty ? null : t(w.days.first.hiC),
                        w.days.isEmpty ? null : t(w.days.first.loC)),
                    size: Size.infinite)),
          ),
          const SizedBox(width: _gap),
          Expanded(
            flex: 100,
            child: _fr(
              'Wind, ${w.place}',
              Column(children: [
                Expanded(child: CustomPaint(painter: _Rose(wind(w.now.windKmh, f).toUpperCase()), size: Size.infinite)),
                _capRich([
                  ('${w.now.condition}, feels ', null),
                  ('${t(w.now.feelsC)}°', _g),
                  (', RH ', null),
                  ('${w.now.humidity}%', _g),
                ], align: TextAlign.center),
              ]),
            ),
          ),
          const SizedBox(width: _gap),
          Expanded(
            flex: 125,
            child: _fr(
              'Forecast',
              _table(
                widths: const {0: FlexColumnWidth(1.1), 1: FlexColumnWidth(.7), 2: FlexColumnWidth(1.6), 3: FlexColumnWidth(.9)},
                head: [_th('Day'), _th(''), _th('Hi / Lo', right: true), _th('Rain', right: true)],
                rows: [
                  for (final (i, d) in w.days.indexed)
                    _tr([
                      _td(i == 0 ? 'Today' : weekday3(d.date)),
                      _td(DpIcon(d.icon, size: 15, color: d.icon == 'rain' ? _c : _w)),
                      _td('${t(d.hiC)}° / ${t(d.loC)}°', c: _g, right: true),
                      _td(d.precipPct > 0 ? '${d.precipPct}%' : '—', c: d.precipPct > 50 ? _a : _c, right: true),
                    ]),
                ],
              ),
            ),
          ),
        ]),
      ),
      const SizedBox(height: _gap),
      _fr(
        'Next 12 hours',
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (final (i, h) in w.hours.take(12).indexed)
            Column(children: [
              Text(i == 0 ? 'NOW' : _hourLabel(h.time, s.clock24).toUpperCase(),
                  style: _sans(9.5, b: true, ls: .57, c: _gy)),
              Text('${t(h.tempC)}°', style: _mono(12, c: _g)),
            ]),
        ]),
      ),
    ]);
  }
}

/// Vertical temperature tape (like an altitude tape) with HI/LO bugs and a boxed readout.
class _TempTape extends CustomPainter {
  _TempTape(this.now, this.hi, this.lo);
  final int now;
  final int? hi, lo;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final mn = [now, ?lo].reduce(math.min), mx = [now, ?hi].reduce(math.max);
    final a = ((mn - 5) / 10).floor() * 10, b = ((mx + 5) / 10).ceil() * 10;
    double y(num t) => 8 + (h - 16) * (1 - (t - a) / (b - a));
    final x = w / 2 + 4;
    canvas.drawLine(Offset(x, y(b)), Offset(x, y(a)), _stroke(_w, 1.2));
    for (var t = a; t <= b; t += 5) {
      canvas.drawLine(Offset(x, y(t)), Offset(x + (t % 10 != 0 ? 6 : 10), y(t)), _stroke(_w, 1.2));
      if (t % 10 == 0) _text(canvas, '$t', _mono(10, c: _gy, h: 1), x + 14, y(t) + 3.5, align: TextAlign.left);
    }
    void bug(int t, String lab) {
      canvas.drawPath(
          Path()
            ..moveTo(x - 2, y(t))
            ..lineTo(x - 10, y(t) - 5)
            ..lineTo(x - 10, y(t) + 5)
            ..close(),
          Paint()..color = _c);
      _text(canvas, '$lab $t', _sans(9, b: true, c: _c, h: 1), x - 13, y(t) + 3.5, align: TextAlign.right);
    }

    if (hi != null) bug(hi!, 'HI');
    if (lo != null) bug(lo!, 'LO');
    final box = Rect.fromLTWH(x - 4, y(now) - 12, 46, 24);
    canvas.drawRect(box, Paint()..color = _bg);
    canvas.drawRect(box, _stroke(_w, 1.4));
    _text(canvas, '$now°', _mono(16, c: _g, h: 1), x + 19, y(now) + 5.5);
  }

  @override
  bool shouldRepaint(_TempTape o) => o.now != now || o.hi != hi || o.lo != lo;
}

/// Compass rose with the wind-speed readout. (No direction arrow: the weather feed doesn't
/// carry wind direction.)
class _Rose extends CustomPainter {
  _Rose(this.label);
  final String label;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2, r = math.min(size.width, size.height) / 2 - 16;
    if (r <= 20) return;
    canvas.drawCircle(Offset(cx, cy), r, _stroke(_w, 1.2));
    for (var a = 0; a < 360; a += 10) {
      canvas.drawLine(_p(cx, cy, r, a.toDouble()), _p(cx, cy, r - (a % 30 != 0 ? 5 : 9), a.toDouble()), _stroke(_w, 1.1));
    }
    for (final (l, a) in const [('N', 0.0), ('E', 90.0), ('S', 180.0), ('W', 270.0)]) {
      final p = _p(cx, cy, r - 20, a);
      _text(canvas, l, _sans(12, b: true, c: a == 0 ? _c : _w, h: 1), p.dx, p.dy + 4);
    }
    final bw = math.max(68.0, label.length * 8.0 + 14);
    final box = Rect.fromLTWH(cx - bw / 2, cy - 10, bw, 20);
    canvas.drawRect(box, Paint()..color = _bg);
    canvas.drawRect(box, _stroke(_w, 1.2));
    _text(canvas, label, _mono(12, c: _g, h: 1), cx, cy + 4.5);
  }

  @override
  bool shouldRepaint(_Rose o) => o.label != label;
}

// ------------------------------------------------------------------ Music

class _Music extends ConsumerWidget {
  const _Music();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = topicData<MediaData>(ref, 'media')!;
    final art = topicData<MediaArt>(ref, 'media.art');
    final skew = ref.read(agentProvider.notifier).clockSkewMs;
    final has = m.title != null;
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AspectRatio(
        aspectRatio: 1,
        child: _artfr(AlbumArt(title: m.title ?? 'Nothing playing', b64: art?.artId == m.artId ? art?.b64 : null)),
      ),
      const SizedBox(width: _gap),
      Expanded(
        child: _fr(
          'Audio${m.source != null ? ', ${m.source}' : ''}',
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 8),
            _cap('Track'),
            const SizedBox(height: 4),
            Text(m.title ?? 'Nothing playing',
                style: _sans(24, b: true, h: 1.1), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Text(m.artist ?? '', style: _sans(15, c: _g), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(m.album ?? '', style: _sans(12, c: _gy), maxLines: 1, overflow: TextOverflow.ellipsis),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
                child: _Scope(playing: m.playing),
              ),
            ),
            Ticker(
              period: const Duration(seconds: 1),
              builder: (context, now) {
                final pos = m.positionNow(now, skewMs: skew);
                final total = m.durationMs ?? 0;
                return Column(children: [
                  _Seek(
                    value: total == 0 ? 0 : pos / total,
                    enabled: m.canSeek && total > 0,
                    onSeek: (f) => act(context, ref, 'media.seek', {'position_ms': (f * total).round()}),
                  ),
                  const SizedBox(height: 2),
                  Row(children: [
                    Text(has ? mmss(pos) : '—', style: _mono(13, c: _g)),
                    const Spacer(),
                    Text(total == 0 ? '' : mmss(total), style: _mono(13, c: _gy)),
                  ]),
                ]);
              },
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(flex: 10, child: _Btn(icon: 'prev', height: 44, onTap: () => act(context, ref, 'media.prev'))),
              const SizedBox(width: _gap),
              Expanded(
                flex: 14,
                child: _Btn(
                  icon: m.playing ? 'pause' : 'play',
                  label: m.playing ? 'Pause' : 'Play',
                  height: 44,
                  color: _g,
                  onTap: () => act(context, ref, 'media.play_pause'),
                ),
              ),
              const SizedBox(width: _gap),
              Expanded(flex: 10, child: _Btn(icon: 'next', height: 44, onTap: () => act(context, ref, 'media.next'))),
            ]),
          ]),
        ),
      ),
    ]);
  }
}

// ------------------------------------------------------------------ audio scope

/// Smooth value noise in -1..1 (no audio data reaches the phone, so the scope's signal is
/// made up: a few drifting partials and some grit, pumped by a beat).
double _vnoise(double x) {
  double h(double i) {
    final s = math.sin(i * 127.1 + 311.7) * 43758.5453;
    return (s - s.floorToDouble()) * 2 - 1;
  }

  final i = x.floorToDouble(), f = x - i;
  final u = f * f * (3 - 2 * f);
  return h(i) * (1 - u) + h(i + 1) * u;
}

/// Loudness at time [t]: a kick on every beat (112 bpm) over a slow phrase-level swell.
double _beatEnv(double t) {
  final ph = (t * 112 / 60) % 1;
  final kick = math.exp(-ph * 4);
  return (.55 + .45 * kick) * (.78 + .22 * _vnoise(t * .35 + 40));
}

/// The trace at screen position [x] (0..1) and time [t], -1..1 (soft-clipped like a hot
/// input, so beats fill the screen without spiking off it).
double _wave(double x, double t, double env) {
  const tau = 2 * math.pi;
  var y = .38 * (.7 + .3 * _vnoise(t * .9 + 1)) * math.sin(tau * 2.2 * x + t * 7.1);
  y += .26 * (.55 + .45 * _vnoise(t * 1.3 + 7)) * math.sin(tau * 4.7 * x - t * 11.3 + 1.3);
  y += .18 * (.5 + .5 * _vnoise(t * 1.9 + 13)) * math.sin(tau * 8.3 * x + t * 17.9 + 2.1);
  y += .11 * (.5 + .5 * _vnoise(t * 2.7 + 21)) * math.sin(tau * 15.1 * x - t * 23);
  y += .09 * _vnoise(x * 70 + t * 40);
  final e = math.exp(4.8 * y * env); // tanh(2.4 · y · env)
  return (e - 1) / (e + 1);
}

/// Audio oscilloscope in a framed display: a phosphor-green trace with a short fading
/// trail (earlier sweeps redrawn fainter, no blur), graticule and a SIG readout. Runs on a
/// Ticker only while music plays (it pauses itself off screen); on pause the signal eases
/// down to a flat line and the ticker stops.
class _Scope extends StatefulWidget {
  const _Scope({required this.playing});
  final bool playing;
  @override
  State<_Scope> createState() => _ScopeState();
}

class _ScopeState extends State<_Scope> with SingleTickerProviderStateMixin {
  late final _ticker = createTicker(_tick);
  final _frame = ValueNotifier<int>(0); // repaint trigger
  final _sig = ValueNotifier<String?>(null); // readout, refreshed 4× a second
  double _t = 0; // signal time, s (advances only while running)
  double _level = 0; // 0 = flat line … 1 = full signal
  double _db = -60, _sigAt = -1;
  Duration _prev = Duration.zero;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_Scope old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.playing && !_ticker.isActive) {
      _prev = Duration.zero;
      _ticker.start();
    }
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _prev).inMicroseconds / 1e6).clamp(0.0, .1);
    _prev = elapsed;
    _t += dt;
    final target = widget.playing ? 1.0 : 0.0;
    _level += (target - _level) * (1 - math.exp(-dt * 6));
    if ((target - _level).abs() < .01) _level = target;
    // Readout: a smoothed level in dBFS, updated at instrument pace (not every frame).
    final db = 20 * math.log(math.max(1e-3, _level * _beatEnv(_t) * .6)) / math.ln10;
    _db += (db - _db) * math.min(1, dt * 8);
    if (_t - _sigAt >= .25) {
      _sigAt = _t;
      _sig.value = _level < .05 ? null : '${_db.toStringAsFixed(1)} dB';
    }
    _frame.value++;
    if (!widget.playing && _level == 0) {
      _sig.value = null;
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    _sig.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget plate(Widget child) => Container(
          color: _ScopeGrid.screen,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          child: child,
        );
    return Stack(children: [
      // The glass and graticule never change: their own layer, recorded once.
      const Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: _ScopeGrid()))),
      Positioned.fill(
        child: RepaintBoundary(child: CustomPaint(painter: _ScopeTrace(this, _frame), isComplex: true, willChange: true)),
      ),
      Positioned(
        left: 6,
        top: 5,
        child: plate(ValueListenableBuilder<String?>(
          valueListenable: _sig,
          builder: (context, v, _) => _capRich([('Sig ', null), (v ?? '—', v == null ? _gy : _g)]),
        )),
      ),
      Positioned(right: 6, top: 5, child: plate(_cap('CH1  L+R', c: _c))),
    ]);
  }
}

/// Scope glass, 10 × 4 dashed graticule, a solid centre cross with fine ticks, bezel line.
class _ScopeGrid extends CustomPainter {
  const _ScopeGrid();

  /// The display glass: a touch greener than the panel, like a phosphor tube face.
  static const screen = Color(0xFF040B09);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (w <= 0 || h <= 0) return;
    final box = Offset.zero & size;
    canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(2)), Paint()..color = screen);
    // All dashes in one path (one draw), likewise the axes and their ticks.
    final dashes = Path();
    void dash(Offset a, Offset b) {
      final len = (b - a).distance;
      final d = (b - a) / len;
      for (double t = 0; t < len; t += 6) {
        final p = a + d * t, q = a + d * math.min(t + 2, len);
        dashes
          ..moveTo(p.dx, p.dy)
          ..lineTo(q.dx, q.dy);
      }
    }

    for (var i = 1; i < 10; i++) {
      if (i != 5) dash(Offset(w * i / 10, 0), Offset(w * i / 10, h));
    }
    dash(Offset(0, h / 4), Offset(w, h / 4));
    dash(Offset(0, h * 3 / 4), Offset(w, h * 3 / 4));
    canvas.drawPath(dashes, _stroke(_frc, 1));
    final axes = Path()
      ..moveTo(0, h / 2)
      ..lineTo(w, h / 2)
      ..moveTo(w / 2, 0)
      ..lineTo(w / 2, h);
    for (var i = 1; i < 50; i++) {
      axes
        ..moveTo(w * i / 50, h / 2 - 2)
        ..lineTo(w * i / 50, h / 2 + 2);
    }
    for (var i = 1; i < 20; i++) {
      axes
        ..moveTo(w / 2 - 2, h * i / 20)
        ..lineTo(w / 2 + 2, h * i / 20);
    }
    canvas.drawPath(axes, _stroke(const Color(0xFF34414F), 1));
    canvas.drawRRect(RRect.fromRectAndRadius(box.deflate(.5), const Radius.circular(2)), _stroke(_frc, 1));
  }

  @override
  bool shouldRepaint(_ScopeGrid o) => false;
}

/// The trace: the current sweep with a flat halo under it (no blur) and earlier sweeps
/// redrawn fainter for the phosphor trail. Repaints every tick while running.
class _ScopeTrace extends CustomPainter {
  _ScopeTrace(this.s, Listenable frame) : super(repaint: frame);
  final _ScopeState s;

  /// Earlier sweeps for the phosphor trail (seconds back, alpha).
  static const _trail = [(.16, .07), (.12, .12), (.08, .2), (.04, .36)];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (w <= 0 || h <= 0) return;
    final n = math.max(24, (w / 3).round());
    final amp = h * .46 * s._level;
    Path trace(double t) {
      final env = _beatEnv(t);
      final p = Path();
      for (var i = 0; i <= n; i++) {
        final x = i / n;
        final y = h / 2 - (amp == 0 ? 0 : amp * _wave(x, t, env));
        i == 0 ? p.moveTo(0, y) : p.lineTo(x * w, y);
      }
      return p;
    }

    canvas.save();
    canvas.clipRect((Offset.zero & size).deflate(1));
    if (amp > 0) {
      for (final (back, a) in _trail) {
        canvas.drawPath(trace(s._t - back), _stroke(_g.withValues(alpha: a), 1.4)..strokeJoin = StrokeJoin.round);
      }
    }
    final now = trace(s._t);
    canvas.drawPath(now, _stroke(_g.withValues(alpha: .16), 4.5)..strokeJoin = StrokeJoin.round);
    canvas.drawPath(now, _stroke(_g, 1.6)..strokeJoin = StrokeJoin.round);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScopeTrace o) => o.s != s;
}

/// Tick-scale seek tape with a cyan pointer. Tap / drag to seek (one seek on release).
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
        final v = _drag ?? widget.value;
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
          child: SizedBox(height: 38, width: double.infinity, child: CustomPaint(painter: _SeekPainter(v.clamp(0.0, 1.0)))),
        );
      });
}

class _SeekPainter extends CustomPainter {
  _SeekPainter(this.p);
  final double p;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, y = h - 10;
    canvas.drawLine(Offset(0, y), Offset(w, y), _stroke(_w, 1.2));
    for (var i = 0; i <= 40; i++) {
      final x = i / 40 * w;
      canvas.drawLine(Offset(x, y), Offset(x, y + (i % 10 != 0 ? 4 : 8)), _stroke(i / 40 <= p ? _g : _w, 1.2));
    }
    canvas.drawLine(Offset(0, y), Offset(p * w, y), _stroke(_g, 3));
    canvas.drawPath(
        Path()
          ..moveTo(p * w, y - 2)
          ..lineTo(p * w - 6, y - 12)
          ..lineTo(p * w + 6, y - 12)
          ..close(),
        Paint()..color = _c);
  }

  @override
  bool shouldRepaint(_SeekPainter o) => o.p != p;
}

// ------------------------------------------------------------------ Hotspot

/// Signal-score zones, matching the grades (poor < 35 <= fair < 55 <= good).
const _scoreZones = <(double, double, Color)>[(0, 35, _r), (35, 55, _a), (55, 100, _g)];

/// Battery: red at the default low-battery alert (20%), amber just above.
const _battZones = <(double, double, Color)>[(0, 20, _r), (20, 30, _a), (30, 100, _g)];

/// Battery temperature, °C: the Hotspot Monitor's default warn (40) and stop-charging (45) points.
const _heatZones = <(double, double, Color)>[(0, 40, _g), (40, 45, _a), (45, 60, _r)];

/// The charge limit from a charge note like "limit 80%", for the magenta target bug.
double? _chargeLimit(String? note) {
  final m = RegExp(r'limit (\d+)%').firstMatch(note ?? '');
  return m == null ? null : double.parse(m[1]!);
}

/// The Hotspot Monitor Overview (the roof phone sharing mobile data), as an ECAM page:
/// a red warning strip when something is wrong, status memo, three gauges, speed
/// readouts, a systems memo and the event log.
class _Hotspot extends ConsumerWidget {
  const _Hotspot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = topicData<HotspotData>(ref, 'hotspot')!;
    final f = ref.watch(settingsProvider.select((s) => s.fahrenheit));
    return Ticker(
      builder: (context, now) {
        final alert = hsAlert(d, now);
        return Column(children: [
          if (alert != null) ...[_warning(alert), const SizedBox(height: _gap + 2)],
          Expanded(
            flex: 118,
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(flex: 106, child: _status(d, now)),
              const SizedBox(width: _gap),
              Expanded(flex: 164, child: _gauges(d, f)),
              const SizedBox(width: _gap),
              Expanded(flex: 86, child: _speed(d)),
            ]),
          ),
          const SizedBox(height: _gap + 2),
          Expanded(
            flex: 100,
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(flex: 140, child: _systems(d, f)),
              const SizedBox(width: _gap),
              Expanded(flex: 150, child: _log(d, now)),
            ]),
          ),
        ]);
      },
    );
  }

  /// Master-warning strip.
  Widget _warning(String alert) => Container(
        height: 28,
        padding: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: _r.withValues(alpha: .1),
          border: Border.all(color: _r, width: 1.5),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(children: [
          Container(
            color: _r,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('WARNING', style: _sans(11.5, b: true, ls: 1.2, c: _bg, h: 1)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(alert.toUpperCase(),
                style: _mono(12.5, c: _r, b: true, h: 1), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ]),
      );

  static Color _stateColor(HotspotData d) => switch (hsState(d)) {
        HsState.offline || HsState.internetDown || HsState.hot => _r,
        HsState.lowBattery => _a,
        HsState.ok => _g,
      };

  static Color _gradeColor(HotspotGrade? g) => switch (g) {
        HotspotGrade.excellent || HotspotGrade.good => _g,
        HotspotGrade.fair => _a,
        HotspotGrade.poor => _r,
        null => _gy,
      };

  Widget _status(HotspotData d, DateTime now) => _fr(
        [_tg('Status'), if (d.name != null) _tb(', ${d.name}')],
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(hsStateLabel(d).toUpperCase(), style: _sans(24, b: true, c: _stateColor(d), h: 1.2)),
          ),
          const Spacer(),
          _memo([
            ('SEEN', (d.lastSeen == null ? 'NEVER' : ago(now.difference(d.lastSeen!))).toUpperCase(), _w),
            ('NET', hsNetwork(d).toUpperCase(), _c),
            ('OPER', (d.operator ?? '—').toUpperCase(), _c),
            ('TETHER', hsSharing(d).replaceFirst('Sharing ', '').toUpperCase(), d.tetherOn == true ? _g : _a),
          ]),
          const SizedBox(height: 2),
        ]),
      );

  Widget _gauges(HotspotData d, bool f) => _fr(
        'Phone',
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: _Dial(
                value: d.score,
                zones: _scoreZones,
                unit: '',
                label: 'SIGNAL',
                sub: hsGradeLabel(d.grade).toUpperCase(),
              ),
            ),
            const SizedBox(width: _gap),
            Expanded(
              child: _Dial(
                value: d.batteryPct,
                zones: _battZones,
                target: _chargeLimit(d.chargeNote),
                label: d.lowBattery ? 'BATT LOW' : 'BATTERY',
                sub: hsCurrent(d.currentMa).toUpperCase(),
              ),
            ),
            const SizedBox(width: _gap),
            Expanded(
              child: _Dial(
                value: d.batteryC,
                max: 60,
                zones: _heatZones,
                text: d.batteryC == null ? null : hsTemp(d.batteryC, fahrenheit: f).replaceFirst(' ', ''),
                label: 'BATT TEMP',
                sub: d.radioResting ? 'RADIO RESTING' : d.heat.name.toUpperCase(),
              ),
            ),
          ]),
        ),
      );

  Widget _speed(HotspotData d) {
    final (dn, dnU) = hsBpsParts(d.rxBps);
    final (up, upU) = hsBpsParts(d.txBps);
    Widget ro(String label, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _cap(label),
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(border: Border.all(color: _w, width: 1.5), borderRadius: BorderRadius.circular(2)),
            child: Text(v, style: _mono(24, c: _g, h: 1.15)),
          ),
        ]);
    return _fr(
      'Speed now',
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            ro('Down $dnU', dn),
            const SizedBox(width: 12),
            ro('Up $upU', up),
          ]),
        ),
        const Spacer(),
        Text(hsPingLine(d).toUpperCase(), style: _capS(), maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
      ]),
    );
  }

  /// ECAM-style systems memo: one compact line per system, grey label, coloured value.
  Widget _systems(HotspotData d, bool f) {
    final q = d.quotaFrac;
    final qc = q == null ? _c : (q >= 1 ? _r : (q >= .8 ? _a : _g));
    final heatC = switch (d.heat) {
      HotspotHeat.hot => _r,
      HotspotHeat.warm => _a,
      HotspotHeat.ok => _g,
    };
    final rows = <(String, String, Color)>[
      ('SIGNAL', hsSignalLine(d), _gradeColor(d.grade)),
      ('POWER', hsPowerLine(d), d.lowBattery ? _a : _g),
      ('HEAT', hsHeatLine(d, fahrenheit: f), heatC),
      ('DATA', hsDataLine(d), qc),
      ('', hsTodayLine(d), _c),
      ('UPTIME', 'Phone ${hsUptime(d.uptimeS)} · agent ${hsUptime(d.agentUptimeS)}', _w),
      ('', hsBootLine(d), _c),
    ];
    return _fr(
      [_tg('Systems'), if (d.model != null) _tb(', ${d.model}', _gy)],
      LayoutBuilder(builder: (context, box) {
        // 15 px per line; the quota bar (if any) goes first when short.
        final showBar = q != null && box.maxHeight >= rows.length * 15 + 12;
        final fit = rows.take(math.max(1, (box.maxHeight / 15).floor()));
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 2),
          for (final (l, v, c) in fit) ...[
            SizedBox(
              height: 15,
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                SizedBox(width: 56, child: Text(l, style: _capS(), maxLines: 1)),
                Expanded(
                  child: Text(v.toUpperCase(),
                      style: _mono(11.5, c: c, h: 1), maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false),
                ),
              ]),
            ),
            if (l == 'DATA' && showBar)
              Padding(padding: const EdgeInsets.fromLTRB(56, 2, 0, 3), child: _hbar(q, c: qc)),
          ],
        ]);
      }),
    );
  }

  Widget _log(HotspotData d, DateTime now) {
    Color sev(HotspotEvent e) => switch (e.severity) {
          'critical' => _r,
          'warning' => _a,
          _ => _w,
        };
    final note = hsSessionNote(d, now);
    return _fr(
      [_tg('Event log'), if (d.events.isNotEmpty) _tb(', ${d.events.length} latest')],
      // DeskPanel's own sign-in to the Server running out: a magenta advisory on the frame.
      right: note == null
          ? null
          : Container(
              color: CockpitSkin.plate,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Text(note.toUpperCase(),
                  style: _mono(11, c: note.startsWith('Sign-in expired') ? _r : _m, b: true, h: 13 / 11)),
            ),
      d.events.isEmpty
          ? Align(alignment: Alignment.topLeft, child: Padding(padding: const EdgeInsets.only(top: 6), child: _cap('No events', c: _g)))
          : LayoutBuilder(builder: (context, box) {
              const rowH = 20.0;
              final n = math.min(d.events.length, ((box.maxHeight - 2) / rowH).floor());
              return Column(children: [
                const SizedBox(height: 2),
                for (final (i, e) in d.events.take(n).indexed)
                  Container(
                    height: rowH,
                    decoration: i == 0 ? null : const BoxDecoration(border: Border(top: BorderSide(color: _fr2))),
                    child: Row(children: [
                      Container(width: 3, height: 12, color: e.severity == 'info' ? _fr2 : sev(e)),
                      const SizedBox(width: 7),
                      SizedBox(
                        width: 34,
                        child: Text(slackTime(e.ts, now).toUpperCase(),
                            style: _mono(11.5, c: e.severity == 'info' ? _gy : sev(e), b: true, h: 1)),
                      ),
                      Expanded(
                        child: Text(e.message,
                            style: _sans(12.5, c: sev(e), h: 1), maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false),
                      ),
                    ]),
                  ),
              ]);
            }),
    );
  }
}

// ------------------------------------------------------------------ Timer

class _Timer extends ConsumerWidget {
  const _Timer();

  static String _len(TimerMode m, TimerState st) => switch (m) {
        TimerMode.stopwatch => 'UP',
        TimerMode.countdown => '${st.countdownMin}:00',
        _ => '${m.defaultMin}:00',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(timerProvider);
    final ctl = ref.read(timerProvider.notifier);
    return Ticker(
      period: const Duration(seconds: 1),
      builder: (context, now) {
        final label = st.running ? 'Pause' : (st.pristine ? 'Start' : 'Resume');
        final sw = st.mode == TimerMode.stopwatch;
        final frac = sw ? st.progress(now) : 1 - st.progress(now);
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            flex: 160,
            child: _fr(
              [_tg('Timer, '), _tb(st.mode.label)],
              CustomPaint(
                painter: _TimerDial(
                  frac: frac.clamp(0.0, 1.0),
                  digits: _ms(st.display(now)),
                  running: st.running,
                  status: st.running ? 'RUNNING' : (st.pristine ? 'STANDBY' : 'PAUSED'),
                ),
                size: Size.infinite,
              ),
            ),
          ),
          const SizedBox(width: _gap),
          Expanded(
            flex: 100,
            child: _fr(
              'Mode',
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SizedBox(height: 4),
                for (final (i, m) in TimerMode.values.indexed) ...[
                  if (i > 0) const SizedBox(height: 6),
                  _Btn(
                    label: m.label,
                    on: m == st.mode,
                    onTap: () => ctl.setMode(m),
                    trailing: (fg) => m == TimerMode.countdown && m == st.mode && !st.running
                        ? Row(mainAxisSize: MainAxisSize.min, children: [
                            _adj('−', fg, () => ctl.adjust(-1)),
                            const SizedBox(width: 6),
                            Text(_len(m, st), style: _mono(12.5, c: fg, b: true)),
                            const SizedBox(width: 6),
                            _adj('+', fg, () => ctl.adjust(1)),
                          ])
                        : Text(_len(m, st), style: _mono(12.5, c: fg, b: true)),
                  ),
                ],
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _Btn(label: label, color: _g, height: 44, onTap: ctl.toggle)),
                  const SizedBox(width: 6),
                  _Btn(icon: 'reset', height: 44, hpad: 13, onTap: ctl.reset),
                ]),
                const Spacer(),
                _capRich([('Focus sessions ', null), ('${st.sessions}/4', _g)]),
              ]),
            ),
          ),
        ]);
      },
    );
  }

  Widget _adj(String s, Color fg, VoidCallback onTap) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(border: Border.all(color: fg, width: 1.2), borderRadius: BorderRadius.circular(2)),
          alignment: Alignment.center,
          child: Text(s, style: _mono(14, c: fg, b: true, h: 1)),
        ),
      );
}

/// 60-tick bezel; ticks light green for the time remaining, magenta bug at the edge.
class _TimerDial extends CustomPainter {
  _TimerDial({required this.frac, required this.digits, required this.running, required this.status});
  final double frac;
  final String digits, status;
  final bool running;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2, r = math.min(size.width, size.height) / 2 - 12;
    if (r <= 20) return;
    canvas.drawCircle(Offset(cx, cy), r, _stroke(_frc, 1.2));
    for (var i = 0; i < 60; i++) {
      final a = i * 6.0;
      canvas.drawLine(_p(cx, cy, r, a), _p(cx, cy, r - (i % 5 != 0 ? 5 : 11), a),
          _stroke(i / 60 < frac ? _g : _gy, i % 5 != 0 ? 1.2 : 2));
    }
    if (frac > .002 && frac < 1) {
      canvas.drawCircle(_p(cx, cy, r - 16, frac * 360), 4, Paint()..color = _m);
    }
    _text(canvas, digits, _mono((r * .42).roundToDouble(), c: running ? _g : _w, h: 1), cx, cy + 14);
    _text(canvas, status, _sans(10, b: true, ls: 1, c: _gy, h: 1), cx, cy + 14 + r * .28);
  }

  @override
  bool shouldRepaint(_TimerDial o) => o.frac != frac || o.digits != digits || o.running != running || o.status != status;
}

// ------------------------------------------------------------------ Slack

/// Sender tag: initials in a square-cornered box outlined in the sender's colour.
Widget _avatar(SlackMsg m, double size, {bool dim = false}) {
  final c = hex(m.senderColor, _c).withValues(alpha: dim ? .5 : 1);
  return Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: c.withValues(alpha: dim ? .06 : .12),
      border: Border.all(color: c, width: 1.5),
      borderRadius: BorderRadius.circular(3),
    ),
    child: Text(m.initials, maxLines: 1, style: _mono(size * .38, b: true, c: c, h: 1)),
  );
}

/// Annunciator lamp: lit amber with a caution, dark green outline when clear.
Widget _lamp(String s, bool lit) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: lit ? _a.withValues(alpha: .14) : null,
        border: Border.all(color: lit ? _a : _g.withValues(alpha: .5), width: 1.5),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(s, style: _sans(10.5, b: true, ls: 1.2, c: lit ? _a : _g, h: 1.1)),
    );

class _Slack extends ConsumerWidget {
  const _Slack();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = topicData<SlackData>(ref, 'slack')!;
    return Ticker(
      builder: (context, now) => Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          flex: 100,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _status(context, ref, s, now),
            const SizedBox(height: _gap + 4),
            Expanded(child: _uplink(context, ref, s, now)),
          ]),
        ),
        const SizedBox(width: _gap),
        Expanded(flex: 150, child: _log(context, ref, s, now)),
      ]),
    );
  }

  /// Datalink status: lamp, unread count, mark-all-read key.
  Widget _status(BuildContext context, WidgetRef ref, SlackData s, DateTime now) {
    final lit = s.unread > 0;
    final last = s.messages.firstOrNull;
    return _fr(
      [_tg('Datalink, '), _tb(s.team ?? 'Slack')],
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 4),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Text(s.unread.toString().padLeft(2, '0'), style: _mono(46, c: lit ? _a : _g, h: 1)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _lamp(lit ? 'MSG' : 'CLEAR', lit),
              const SizedBox(height: 5),
              _cap(lit ? 'Unread' : 'No unread'),
            ]),
          ),
          _Btn(label: 'Mark all read', height: 32, hpad: 10, size: 10.5, onTap: lit ? () => slackReadAll(context, ref) : null),
        ]),
        const SizedBox(height: 8),
        _lead('LAST RX', last == null ? '—' : '${slackTime(last.ts, now)}, ${last.sender}'.toUpperCase(), _g),
      ]),
    );
  }

  /// The newest unread message, large.
  Widget _uplink(BuildContext context, WidgetRef ref, SlackData s, DateTime now) {
    final unread = s.unreadMessages;
    final top = unread.firstOrNull;
    final next = unread.length > 1 ? unread[1] : null;
    if (top == null) {
      return _fr(
        'Uplink',
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('ALL CAUGHT UP', style: _sans(16, b: true, ls: 1.6, c: _g)),
            const SizedBox(height: 6),
            _cap(s.messages.isEmpty ? 'No recent messages' : 'No unread messages'),
          ]),
        ),
      );
    }
    return Press(
      onTap: () => slackOpen(context, ref, top),
      scale: .99,
      child: _fr(
        [_tg('Uplink, '), _tb('newest unread', _m)],
        right: Container(
          color: CockpitSkin.plate,
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Text(slackTime(top.ts, now).toUpperCase(), style: _mono(10.5, b: true, c: _m, h: 1.3)),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 4),
          Row(children: [
            _avatar(top, 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(top.sender.toUpperCase(),
                    style: _sans(15, b: true, h: 1.2), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(slackWhere(top).toUpperCase(),
                    style: _mono(11.5, c: _c, h: 1.2), maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            SlackReadTick(top, color: _a, fill: _a, onFill: CockpitSkin.plate, radius: 3, size: 28, hit: 44),
          ]),
          const SizedBox(height: 10),
          Expanded(
            child: Text(top.text,
                style: _sans(16.5, h: 1.35), maxLines: 4, overflow: TextOverflow.ellipsis),
          ),
          _lead(
            'NEXT',
            next == null ? 'NONE' : '${next.sender}, ${slackTime(next.ts, now)}'.toUpperCase(),
            next == null ? _g : _m,
          ),
          const SizedBox(height: 6),
          _cap('Tap to open on laptop', c: _c),
        ]),
      ),
    );
  }

  /// Message log, newest first.
  Widget _log(BuildContext context, WidgetRef ref, SlackData s, DateTime now) {
    final ms = s.messages;
    return _fr(
      [_tg('Message log, '), _tb('${ms.length}', _w), _tg(' rx')],
      pad: const EdgeInsets.fromLTRB(10, 12, 8, 4),
      ms.isEmpty
          ? Center(child: _cap('No recent messages'))
          : ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: ms.length,
              itemBuilder: (context, i) => _row(context, ref, ms[i], now, first: i == 0),
            ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, SlackMsg m, DateTime now, {bool first = false}) {
    final u = m.unread;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => slackOpen(context, ref, m),
      child: Container(
        padding: const EdgeInsets.fromLTRB(0, 7, 0, 7),
        decoration: first ? null : const BoxDecoration(border: Border(top: BorderSide(color: _fr2))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Caution bar on unread rows.
          Container(width: 3, height: 34, color: u ? _a : null),
          const SizedBox(width: 7),
          _avatar(m, 30, dim: !u),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: m.sender.toUpperCase(), style: _sans(12, b: true, ls: .4, c: u ? _w : _gy)),
                      TextSpan(text: '  ${slackWhere(m).toUpperCase()}', style: _mono(11, c: u ? _c : _gy)),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(slackTime(m.ts, now).toUpperCase(), style: _mono(11, b: u, c: u ? _a : _gy)),
              ]),
              const SizedBox(height: 3),
              Text(m.text,
                  style: _sans(12.5, c: u ? _w : _gy, h: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          ),
          SlackReadTick(m, color: _a, fill: _a, onFill: CockpitSkin.plate, radius: 3, size: 24),
        ]),
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
    final mx = maxOf(g.thisWeek);
    final total = g.total.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    final b = g.bestDay;
    return Column(children: [
      _fr(
        'Contributions, $total in 12 months',
        right: _tabRow(codeSources, ref.watch(codeSourceProvider), ref.read(codeSourceProvider.notifier).set),
        rightTop: -12,
        Padding(padding: const EdgeInsets.only(top: 4), child: _Heat(g.weeks)),
      ),
      const SizedBox(height: _gap),
      Expanded(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            flex: 80,
            child: _fr(
              'Streak',
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 6),
                Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                  Text('${g.streakCurrent}', style: _mono(64, c: _g, h: 1)),
                  const SizedBox(width: 6),
                  _cap(g.streakCurrent == 1 ? 'day' : 'days'),
                ]),
                const Spacer(),
                _memo([
                  ('LONGEST', '${g.streakLongest} D', _w),
                  ('BEST', b == null ? '—' : '${b.count} ${month3(b.date).toUpperCase()} ${b.date.day}', _w),
                ]),
              ]),
            ),
          ),
          const SizedBox(width: _gap),
          Expanded(
            flex: 100,
            child: _fr(
              [_tg('This week, '), _tb('${g.weekTotal}'), _tg(' '), _tb('${g.weekDelta >= 0 ? '+' : ''}${g.weekDelta}', _g)],
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _Bars([
                  for (var i = 0; i < 7; i++)
                    () {
                      final v = i < g.thisWeek.length ? g.thisWeek[i] : null;
                      return ('SMTWTFS'[i], v == null ? '' : '$v', (v ?? 0) / mx * .78, i == today);
                    }(),
                ]),
              ),
            ),
          ),
          const SizedBox(width: _gap),
          Expanded(
            flex: 110,
            child: _fr(
              topReposLabel(ref),
              SingleChildScrollView(
                child: _table(
                  widths: const {0: FlexColumnWidth(), 1: IntrinsicColumnWidth()},
                  rows: [
                    for (final r in g.topRepos.take(6)) _tr([_td(r.name), _td('${r.count}', c: _g, right: true)]),
                  ],
                ),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }
}

/// Contribution calendar in cockpit green (opacity by level), today boxed in magenta.
class _Heat extends StatelessWidget {
  const _Heat(this.weeks);
  final List<List<ContribDay>> weeks;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        const lw = 24.0, top = 13.0;
        final cw = (c.maxWidth - lw) / 53;
        return SizedBox(
          width: c.maxWidth,
          height: top + 7 * cw,
          child: CustomPaint(painter: _HeatPainter(weeks)),
        );
      });
}

class _HeatPainter extends CustomPainter {
  _HeatPainter(this.weeks);
  final List<List<ContribDay>> weeks;

  @override
  void paint(Canvas canvas, Size size) {
    const lw = 24.0, top = 13.0;
    final ws = weeks.length > 53 ? weeks.sublist(weeks.length - 53) : weeks;
    final cw = (size.width - lw) / 53, cs = cw - 2.4;
    for (var x = 1; x < ws.length - 1; x++) {
      if (ws[x].isEmpty || ws[x - 1].isEmpty) continue;
      if (ws[x].first.date.month != ws[x - 1].first.date.month) {
        _text(canvas, month3(ws[x].first.date).toUpperCase(), _sans(9, c: _gy, h: 1), lw + x * cw, 9, align: TextAlign.left);
      }
    }
    for (final (i, d) in const ['MON', 'WED', 'FRI'].indexed) {
      _text(canvas, d, _sans(8.5, c: _gy, h: 1), 0, top + (1 + i * 2) * cw + cs * .78, align: TextAlign.left);
    }
    final now = DateTime.now();
    for (var x = 0; x < ws.length; x++) {
      for (final day in ws[x]) {
        final y = day.date.weekday % 7;
        final (col, o) = const [(_frc, .6), (_g, .25), (_g, .5), (_g, .78), (_g, 1.0)][day.level.clamp(0, 4)];
        final r = Rect.fromLTWH(lw + x * cw, top + y * cw, cs, cs);
        canvas.drawRect(r, Paint()..color = col.withValues(alpha: o));
        if (day.date.year == now.year && day.date.month == now.month && day.date.day == now.day) {
          canvas.drawRect(r, _stroke(_m, 1.5));
        }
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
    if (rows.isEmpty) return _fr('Keys', Center(child: _cap('No shortcuts configured')));
    return Column(children: [
      for (final (ri, row) in rows.indexed) ...[
        if (ri > 0) const SizedBox(height: _gap),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) const SizedBox(width: _gap),
              Expanded(child: i < row.length ? _Key(tile: row[i], vol: s.volumePct) : const SizedBox()),
            ],
          ]),
        ),
      ],
    ]);
  }
}

/// `.scb` soft button; on-state = amber caution box.
class _Key extends ConsumerStatefulWidget {
  const _Key({required this.tile, this.vol});
  final Tile tile;
  final int? vol;
  @override
  ConsumerState<_Key> createState() => _KeyState();
}

class _KeyState extends ConsumerState<_Key> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tile;
    final on = t.active;
    final fg = on ? _a : _w;
    final ic = on ? _a : _c;
    final detail = t.id.startsWith('volume') && widget.vol != null ? 'VOL ${widget.vol}%' : t.detail?.toUpperCase();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: () => act(context, ref, 'shortcut.run', {'id': t.id}),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        decoration: BoxDecoration(
          color: on ? const Color(0x14FFB020) : (_down ? const Color(0x1F37D6FF) : null),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: on ? _a : (_down ? _c : _frc), width: on ? 2 : (_down ? 1.5 : 1)),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          DpIcon(tileIcon(t), size: 32, color: ic, stroke: 1.6),
          const SizedBox(height: 10),
          Text(tileLabel(t).toUpperCase(),
              style: _sans(11.5, b: true, ls: .92, c: fg), maxLines: 1, overflow: TextOverflow.ellipsis),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(detail, style: _mono(11, c: _g)),
          ],
        ]),
      ),
    );
  }
}
