// Drawing primitives shared by all skins. Every widget animates value changes subtly
// (sweeps/tweens ~600 ms) and takes explicit colours so each skin styles them.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../core/proto/models.dart';
import '../fmt.dart';

const _anim = Duration(milliseconds: 650);

// ------------------------------------------------------------------ arc / ring gauge

/// Arc gauge drawn in a 100×[viewH] box (the concepts' SVG viewBox), scaled to fit.
/// Angles in degrees, 0 = 12 o'clock, clockwise (same as the concepts' `arc()` helper).
class ArcGauge extends StatelessWidget {
  const ArcGauge({
    super.key,
    required this.value,
    required this.color,
    required this.track,
    this.start = -135,
    this.end = 135,
    this.stroke = 8,
    this.radius = 40,
    this.cx = 50,
    this.cy = 50,
    this.viewW = 100,
    this.viewH = 92,
    this.glow = false,
    this.child,
  });

  /// 0..1
  final double value;
  final Color color, track;
  final double start, end, stroke, radius, cx, cy, viewW, viewH;
  final bool glow;

  /// Laid out over the whole box (use Align/Positioned inside).
  final Widget? child;

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: viewW / viewH,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value.clamp(0.0, 1.0)),
          duration: _anim,
          curve: Curves.easeOutCubic,
          builder: (context, v, child) => CustomPaint(painter: _ArcPainter(this, v), child: child),
          child: child == null ? null : SizedBox.expand(child: child),
        ),
      );
}

class _ArcPainter extends CustomPainter {
  _ArcPainter(this.g, this.v);
  final ArcGauge g;
  final double v;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / g.viewW;
    final rect = Rect.fromCircle(center: Offset(g.cx * s, g.cy * s), radius: g.radius * s);
    double rad(double deg) => (deg - 90) * math.pi / 180;
    final sweep = (g.end - g.start) * math.pi / 180;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = g.stroke * s
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, rad(g.start), sweep, false, p..color = g.track);
    if (v > .004) {
      if (g.glow) {
        canvas.drawArc(
            rect,
            rad(g.start),
            sweep * v,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = g.stroke * s * 2
              ..strokeCap = StrokeCap.round
              ..color = g.color.withValues(alpha: .25)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * s));
      }
      canvas.drawArc(rect, rad(g.start), sweep * v, false, p..color = g.color);
    }
  }

  @override
  bool shouldRepaint(_ArcPainter o) => o.v != v || o.g.color != g.color || o.g.track != g.track;
}

// ------------------------------------------------------------------ bars

/// Rounded progress bar (Slate `.bar`, Glow `.line` with [glow]).
class DpBar extends StatelessWidget {
  const DpBar({
    super.key,
    required this.value,
    required this.color,
    required this.track,
    this.height = 6,
    this.glow = false,
  });
  final double value;
  final Color color, track;
  final double height;
  final bool glow;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value.clamp(0.0, 1.0)),
          duration: _anim,
          curve: Curves.easeOut,
          builder: (context, v, _) => CustomPaint(painter: _BarPainter(v, color, track, glow)),
        ),
      );
}

class _BarPainter extends CustomPainter {
  _BarPainter(this.v, this.color, this.track, this.glow);
  final double v;
  final Color color, track;
  final bool glow;
  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.height / 2);
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, r), Paint()..color = track);
    if (v <= 0) return;
    final fill = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, math.max(size.height, size.width * v), size.height), r);
    if (glow) {
      canvas.drawRRect(
          fill,
          Paint()
            ..color = color.withValues(alpha: .8)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    }
    canvas.drawRRect(fill, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BarPainter o) => o.v != v || o.color != color || o.track != track;
}

/// Panel LED segment bar. Fill rounds *up* to whole segments, like the concept.
class LedBar extends StatelessWidget {
  const LedBar({
    super.key,
    required this.value,
    required this.color,
    this.segments = 20,
    this.vertical = false,
    this.off = const Color(0xFF252A2E),
    this.gap = 2,
    this.thickness,
  });
  final double value;
  final Color color, off;
  final int segments;
  final bool vertical;
  final double gap;

  /// Height (horizontal) or width (vertical). Null = fill the parent's cross axis.
  final double? thickness;

  @override
  Widget build(BuildContext context) {
    final painter = TweenAnimationBuilder<double>(
      tween: Tween(end: value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 400),
      builder: (context, v, _) => CustomPaint(painter: _LedPainter(v, color, off, segments, vertical, gap)),
    );
    if (thickness == null) return painter;
    return vertical
        ? SizedBox(width: thickness, height: double.infinity, child: painter)
        : SizedBox(height: thickness, width: double.infinity, child: painter);
  }
}

class _LedPainter extends CustomPainter {
  _LedPainter(this.v, this.color, this.off, this.n, this.vertical, this.gap);
  final double v, gap;
  final Color color, off;
  final int n;
  final bool vertical;

  @override
  void paint(Canvas canvas, Size size) {
    final lit = v <= 0 ? 0 : (v * n - 1e-9).ceil().clamp(0, n);
    final len = vertical ? size.height : size.width;
    final seg = len / n;
    final glow = Paint()
      ..color = color.withValues(alpha: .55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    for (var i = 0; i < n; i++) {
      final a = i * seg, b = (i + 1) * seg - gap;
      final r = vertical
          ? Rect.fromLTRB(0, size.height - b, size.width, size.height - a)
          : Rect.fromLTRB(a, 0, b, size.height);
      if (i < lit) {
        canvas.drawRect(r, glow);
        canvas.drawRect(r, Paint()..color = color);
      } else {
        canvas.drawRect(r, Paint()..color = off);
      }
    }
  }

  @override
  bool shouldRepaint(_LedPainter o) => o.v != v || o.color != color || o.n != n;
}

/// Glow printer "layers" ruler: thin ticks every 6px, lit ticks up to [value].
class TickBar extends StatelessWidget {
  const TickBar({super.key, required this.value, required this.color, required this.rule, this.height = 18});
  final double value, height;
  final Color color, rule;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value.clamp(0.0, 1.0)),
          duration: _anim,
          builder: (context, v, _) => CustomPaint(painter: _TickPainter(v, color, rule)),
        ),
      );
}

class _TickPainter extends CustomPainter {
  _TickPainter(this.v, this.color, this.rule);
  final double v;
  final Color color, rule;
  @override
  void paint(Canvas canvas, Size size) {
    final r = Paint()..color = rule;
    final c = Paint()..color = color;
    final g = Paint()
      ..color = color.withValues(alpha: .6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final lim = size.width * v;
    for (double x = 0; x < size.width; x += 6) {
      if (x < lim) {
        canvas.drawRect(Rect.fromLTWH(x, 0, 1.5, size.height), g);
        canvas.drawRect(Rect.fromLTWH(x, 0, 1.5, size.height), c);
      } else {
        canvas.drawRect(Rect.fromLTWH(x, 0, 1, size.height), r);
      }
    }
  }

  @override
  bool shouldRepaint(_TickPainter o) => o.v != v || o.color != color;
}

// ------------------------------------------------------------------ line charts

class LineSeries {
  const LineSeries(this.values, this.color, {this.width = 2, this.glow = false, this.step = false, this.halo = 4});
  final List<double?> values;
  final Color color;
  final double width;

  /// Soft blurred halo under the line (Glow / Panel traces).
  final bool glow;

  /// Square-wave steps instead of smooth curves (Panel CPU/GPU scope).
  final bool step;

  /// Halo width as a multiple of [width].
  final double halo;
}

enum ChartGrid {
  none,

  /// Slate: horizontal rules at 25/50/75%.
  quarters,

  /// Slate latency: one rule at 50%.
  mid,

  /// Panel oscilloscope: 10 vertical × 4 horizontal divisions.
  scope,
}

class LineChart extends StatelessWidget {
  const LineChart({
    super.key,
    required this.series,
    this.min = 0,
    this.max = 100,
    this.grid = ChartGrid.none,
    this.gridColor = const Color(0xFF20262E),
    this.pad = 2,
  });
  final List<LineSeries> series;
  final double min, max, pad;
  final ChartGrid grid;
  final Color gridColor;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _LinePainter(this), size: Size.infinite);
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.c);
  final LineChart c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final gp = Paint()
      ..color = c.gridColor
      ..strokeWidth = 1;
    switch (c.grid) {
      case ChartGrid.quarters:
        for (final f in const [.25, .5, .75]) {
          canvas.drawLine(Offset(0, h * f), Offset(w, h * f), gp);
        }
      case ChartGrid.mid:
        canvas.drawLine(Offset(0, h / 2), Offset(w, h / 2), gp);
      case ChartGrid.scope:
        for (var i = 1; i < 10; i++) {
          canvas.drawLine(Offset(w * i / 10, 0), Offset(w * i / 10, h), gp);
        }
        for (var i = 1; i < 4; i++) {
          canvas.drawLine(Offset(0, h * i / 4), Offset(w, h * i / 4), gp);
        }
      case ChartGrid.none:
        break;
    }
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(-4, -8, w + 8, h + 16));
    for (final s in c.series) {
      final path = s.step ? _step(s.values, w, h) : _smooth(s.values, w, h);
      if (path == null) continue;
      if (s.glow) {
        canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = s.width * s.halo
              ..color = s.color.withValues(alpha: .2)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      }
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = s.width
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = s.color);
    }
    canvas.restore();
  }

  double _y(double v, double h) {
    final t = ((v.clamp(c.min, c.max) - c.min) / (c.max - c.min));
    return c.pad + (h - 2 * c.pad) * (1 - t);
  }

  /// Monotone-ish smooth curve through midpoints (the concepts' `linePath`). Nulls
  /// (e.g. lost pings) break the line.
  Path? _smooth(List<double?> vals, double w, double h) {
    if (vals.length < 2) return null;
    final dx = w / (vals.length - 1);
    final p = Path();
    double? px, py;
    for (var i = 0; i < vals.length; i++) {
      final v = vals[i];
      if (v == null) {
        px = null;
        continue;
      }
      final x = i * dx, y = _y(v, h);
      if (px == null) {
        p.moveTo(x, y);
      } else {
        final xm = (px + x) / 2;
        p.cubicTo(xm, py!, xm, y, x, y);
      }
      px = x;
      py = y;
    }
    return p;
  }

  /// Square steps, like the concepts' `stepPath` (M0 y0, then H x V y per sample).
  Path? _step(List<double?> vals, double w, double h) {
    if (vals.isEmpty) return null;
    final dx = w / vals.length;
    var y = _y(vals.first ?? c.min, h);
    final p = Path()..moveTo(0, y);
    for (var i = 0; i < vals.length; i++) {
      final ny = _y(vals[i] ?? c.min, h);
      p
        ..lineTo(i * dx, y)
        ..lineTo(i * dx, ny);
      y = ny;
    }
    return p..lineTo(w, y);
  }

  @override
  bool shouldRepaint(_LinePainter o) => true;
}

// ------------------------------------------------------------------ heatmap

enum HeatStyle { slate, glow, panel }

/// GitHub contribution calendar: 53 week columns × 7 days, month labels on top.
/// Height is derived from the width (square cells) unless [fill] is set (Glow dots).
class Heatmap extends StatelessWidget {
  const Heatmap({
    super.key,
    required this.weeks,
    required this.style,
    required this.labelStyle,
    this.dayLabels = true,
    this.highlightToday = true,
    this.fill = false,
  });
  final List<List<ContribDay>> weeks;
  final HeatStyle style;
  final TextStyle labelStyle;
  final bool dayLabels, highlightToday, fill;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final lw = dayLabels ? 26.0 : 0.0;
        final cw = (c.maxWidth - lw) / 53;
        final h = fill && c.maxHeight.isFinite ? c.maxHeight : 14 + 7 * cw;
        return SizedBox(
          width: c.maxWidth,
          height: h,
          child: CustomPaint(painter: _HeatPainter(this, lw)),
        );
      });
}

class _HeatPainter extends CustomPainter {
  _HeatPainter(this.m, this.lw);
  final Heatmap m;
  final double lw;

  @override
  void paint(Canvas canvas, Size size) {
    final weeks = m.weeks.length > 53 ? m.weeks.sublist(m.weeks.length - 53) : m.weeks;
    final cw = (size.width - lw) / 53;
    const top = 14.0;
    final rh = m.fill ? math.min(cw, (size.height - top) / 7) : cw;
    void text(String s, double x, double y) {
      final tp = TextPainter(text: TextSpan(text: s, style: m.labelStyle), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(x, y - tp.height * .8));
    }

    // Month labels where a new month starts (skip the first and last columns).
    for (var x = 1; x < weeks.length - 1; x++) {
      if (weeks[x].isEmpty || weeks[x - 1].isEmpty) continue;
      if (weeks[x].first.date.month != weeks[x - 1].first.date.month) {
        text(month3(weeks[x].first.date), lw + x * cw, 10);
      }
    }
    if (m.dayLabels) {
      for (final (i, d) in const ['Mon', 'Wed', 'Fri'].indexed) {
        text(d, 0, top + (1 + i * 2) * rh + rh * .78);
      }
    }
    final now = DateTime.now();
    for (var x = 0; x < weeks.length; x++) {
      for (final day in weeks[x]) {
        final y = day.date.weekday % 7; // Sunday = 0
        final isToday = m.highlightToday && day.date.year == now.year && day.date.month == now.month && day.date.day == now.day;
        switch (m.style) {
          case HeatStyle.slate:
            final cs = cw - 2.6;
            final col = const [Color(0xFF1F252D), Color(0xFF0E4429), Color(0xFF006D32), Color(0xFF26A641), Color(0xFF39D353)][day.level.clamp(0, 4)];
            final r = RRect.fromRectAndRadius(Rect.fromLTWH(lw + x * cw, top + y * cw, cs, cs), const Radius.circular(2));
            canvas.drawRRect(r, Paint()..color = col);
            if (isToday) {
              canvas.drawRRect(r, Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1
                ..color = const Color(0xB3FFFFFF));
            }
          case HeatStyle.panel:
            final cs = cw - 2.2;
            final (col, gl) = const [
              (Color(0xFF1D2124), 0.0), (Color(0xFF14522C), 0.0), (Color(0xFF1E9A4D), .3),
              (Color(0xFF36D06E), .6), (Color(0xFF7DFFA9), 1.0),
            ][day.level.clamp(0, 4)];
            final r = RRect.fromRectAndRadius(Rect.fromLTWH(lw + x * cw, top + y * cw, cs, cs), const Radius.circular(1.5));
            if (gl > 0) {
              canvas.drawRRect(r, Paint()
                ..color = col
                ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 * gl));
            }
            canvas.drawRRect(r, Paint()..color = col);
          case HeatStyle.glow:
            final o = const [.08, .32, .55, .8, 1.0][day.level.clamp(0, 4)];
            final base = math.min(cw, rh) * .34;
            final rr = day.count > 0 ? base * (1 + o * .35) : base * .7;
            final col = day.count > 0 ? const Color(0xFF5CF08A) : const Color(0xFFF4EFE6);
            canvas.drawCircle(Offset(lw + x * cw + cw / 2, top + y * rh + rh / 2), rr,
                Paint()..color = col.withValues(alpha: o));
        }
      }
    }
  }

  @override
  bool shouldRepaint(_HeatPainter o) => o.m.weeks != m.weeks;
}

/// Utility: a text style's font with tabular figures and no extra line height.
TextStyle tight(TextStyle s) => s.copyWith(height: 1, fontFeatures: const [ui.FontFeature.tabularFigures()]);
