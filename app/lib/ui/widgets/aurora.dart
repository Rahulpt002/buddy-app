import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Classic northern-lights colours, used until (or without) album art.
const auroraDefault = [Color(0xFF3DF5A6), Color(0xFF22D3EE), Color(0xFF8B5CF6), Color(0xFFFF6FB5)];

// ------------------------------------------------------------------ palette

final _paletteCache = <String, List<Color>>{};

/// Four vivid colours from album art (base64 JPEG/PNG), like Apple Music's animated
/// backgrounds: the image is shrunk to 24×24, pixels are grouped by hue, and the biggest,
/// most colourful groups win (greys and near-blacks are skipped). Brightened so they glow
/// on the dark aurora base. Falls back to [auroraDefault] for grey or unreadable art.
Future<List<Color>> artPalette(String b64) async {
  final hit = _paletteCache[b64];
  if (hit != null) return hit;
  try {
    final codec = await ui.instantiateImageCodec(base64Decode(b64), targetWidth: 24, targetHeight: 24);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
    frame.image.dispose();
    final out = data == null ? auroraDefault : paletteFromRgba(data.buffer.asUint8List());
    if (_paletteCache.length > 40) _paletteCache.clear();
    return _paletteCache[b64] = out;
  } catch (_) {
    return auroraDefault;
  }
}

/// Pure part of [artPalette] (testable): RGBA bytes → up to four glowing colours.
List<Color> paletteFromRgba(Uint8List rgba) {
  const buckets = 18; // 20° hue bins
  final weight = List<double>.filled(buckets, 0);
  final sumH = List<double>.filled(buckets, 0), sumS = List<double>.filled(buckets, 0);
  for (var i = 0; i + 3 < rgba.length; i += 4) {
    final hsv = HSVColor.fromColor(Color.fromARGB(255, rgba[i], rgba[i + 1], rgba[i + 2]));
    if (hsv.saturation < .22 || hsv.value < .18) continue; // grey / black
    final b = (hsv.hue / (360 / buckets)).floor() % buckets;
    final w = hsv.saturation * (.4 + hsv.value);
    weight[b] += w;
    sumH[b] += hsv.hue * w;
    sumS[b] += hsv.saturation * w;
  }
  final order = List<int>.generate(buckets, (i) => i)..sort((a, b) => weight[b].compareTo(weight[a]));
  final picked = <Color>[];
  final total = weight.fold<double>(0, (a, b) => a + b);
  for (final b in order) {
    if (weight[b] <= 0 || weight[b] < total * .04) break;
    // Skip near neighbours of a colour already picked (keeps the mix varied).
    final hue = sumH[b] / weight[b];
    if (picked.any((c) => _hueDist(HSVColor.fromColor(c).hue, hue) < 28)) continue;
    final sat = (sumS[b] / weight[b]).clamp(.55, .95).toDouble();
    picked.add(HSVColor.fromAHSV(1, hue, sat, .98).toColor());
    if (picked.length == 4) break;
  }
  if (picked.isEmpty) return auroraDefault;
  // Too few colours (a one-hue cover): add soft neighbours so the lights still move.
  var i = 0;
  while (picked.length < 4) {
    final h = HSVColor.fromColor(picked[i % picked.length]);
    picked.add(
      h.withHue((h.hue + (i.isEven ? 38 : -42)) % 360).withSaturation(math.max(.5, h.saturation - .1)).toColor(),
    );
    i++;
  }
  return picked;
}

double _hueDist(double a, double b) {
  final d = (a - b).abs() % 360;
  return d > 180 ? 360 - d : d;
}

// ------------------------------------------------------------------ aurora

/// Slow, glowing northern lights in [colors] over a dark base.
///
/// Drawn by a GPU shader (shaders/aurora.frag): one draw call per frame, smooth at any
/// size, light on the desk phone's CPU. Where shaders can't load, the lights are painted at
/// ~1/10 size into a tiny image and stretched up instead. Runs every frame, only while on
/// screen, and eases between palettes when the song changes.
class Aurora extends StatefulWidget {
  const Aurora({
    super.key,
    required this.colors,
    this.base = const Color(0xFF07060E),
    this.speed = 1,
    this.animate = true,
  });
  final List<Color> colors;
  final Color base;
  final double speed;

  /// False: hold still (no frames at all), e.g. on Home while nothing plays. A palette
  /// change still eases in, then it stops again.
  final bool animate;

  @override
  State<Aurora> createState() => _AuroraState();
}

/// The GPU version (shaders/aurora.frag), loaded once; null where shaders aren't available.
Future<ui.FragmentProgram?>? _program;
Future<ui.FragmentProgram?> _loadProgram() => _program ??= ui.FragmentProgram.fromAsset('shaders/aurora.frag')
    .then<ui.FragmentProgram?>((p) => p)
    .catchError((Object _) => null);

class _AuroraState extends State<Aurora> with SingleTickerProviderStateMixin {
  ui.FragmentShader? _shader;
  // Every screen refresh (120 Hz on the desk phone) for the smoothest motion. The ticker
  // pauses by itself while the page is off screen, and on Home while nothing plays.
  late final Ticker _ticker;
  final _time = ValueNotifier<double>(0);
  double _base = 0; // seconds accumulated before the ticker last (re)started
  late List<Color> _from = widget.colors, _to = widget.colors;
  double _blendAt = -10; // seconds when the current palette change started

  bool get _blending => _time.value - _blendAt < 1.7;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _time.value = _base + elapsed.inMicroseconds / 1e6;
      if (!widget.animate && !_blending) _stop();
    });
    if (widget.animate) _ticker.start();
    _loadProgram().then((p) {
      if (p != null && mounted) setState(() => _shader = p.fragmentShader());
    });
  }

  void _start() {
    if (!_ticker.isActive) _ticker.start();
  }

  void _stop() {
    if (!_ticker.isActive) return;
    _base = _time.value;
    _ticker.stop();
  }

  @override
  void didUpdateWidget(Aurora old) {
    super.didUpdateWidget(old);
    if (!_same(old.colors, widget.colors)) {
      _from = _current();
      _to = widget.colors;
      _blendAt = _time.value;
      _start(); // ease in (then stop again if not animating)
    }
    if (widget.animate) _start();
  }

  bool _same(List<Color> a, List<Color> b) =>
      a.length == b.length && [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((x) => x);

  List<Color> _current() {
    final f = ((_time.value - _blendAt) / 1.6).clamp(0.0, 1.0);
    final n = math.max(_from.length, _to.length);
    return [
      for (var i = 0; i < n; i++)
        Color.lerp(_from[i % _from.length], _to[i % _to.length], Curves.easeInOut.transform(f))!,
    ];
  }

  @override
  void dispose() {
    _shader?.dispose();
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: _AuroraPainter(this, _time),
      isComplex: true,
      willChange: true,
      child: const SizedBox.expand(),
    ),
  );
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.s, this.time) : super(repaint: time);
  final _AuroraState s;
  final ValueNotifier<double> time;
  ui.Image? _prev;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = time.value * s.widget.speed;
    final colors = s._current();
    final full = Offset.zero & size;
    final sh = s._shader;
    if (sh != null) {
      // One draw: the shader computes every pixel on the GPU.
      sh
        ..setFloat(0, size.width)
        ..setFloat(1, size.height)
        ..setFloat(2, t);
      var i = 3;
      for (var c = 0; c < 4; c++) {
        final col = colors[c % colors.length];
        sh
          ..setFloat(i++, col.r)
          ..setFloat(i++, col.g)
          ..setFloat(i++, col.b)
          ..setFloat(i++, 1);
      }
      final b = s.widget.base;
      sh
        ..setFloat(i++, b.r)
        ..setFloat(i++, b.g)
        ..setFloat(i++, b.b)
        ..setFloat(i++, 1);
      canvas.drawRect(full, Paint()..shader = sh);
      return;
    }
    canvas.drawRect(full, Paint()..color = s.widget.base);

    // Paint small, stretch big: the stretch is the blur.
    const down = 10.0;
    final lw = math.max(8, (size.width / down).ceil()), lh = math.max(6, (size.height / down).ceil());
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    _paintLights(c, Size(lw.toDouble(), lh.toDouble()), t, colors);
    final pic = rec.endRecording();
    try {
      final img = pic.toImageSync(lw, lh);
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, lw.toDouble(), lh.toDouble()),
        full,
        Paint()..filterQuality = FilterQuality.medium,
      );
      _prev?.dispose();
      _prev = img;
    } catch (_) {
      // No offscreen images here (e.g. some test setups): paint at full size instead.
      canvas.save();
      canvas.scale(size.width / lw, size.height / lh);
      _paintLights(canvas, Size(lw.toDouble(), lh.toDouble()), t, colors);
      canvas.restore();
    } finally {
      pic.dispose();
    }
    // A faint top-to-bottom shade keeps white text readable everywhere.
    canvas.drawRect(
      full,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.height),
          [const Color(0x00000000), const Color(0x00000000), const Color(0x59000000)],
          [0, .45, 1],
        ),
    );
  }

  /// The lights, in a w×h (small) space.
  void _paintLights(Canvas c, Size z, double t, List<Color> colors) {
    final w = z.width, h = z.height;
    final glow = Paint()..blendMode = BlendMode.plus;
    // Soft glows drifting on slow Lissajous paths.
    for (var i = 0; i < colors.length; i++) {
      final p = i * 1.7;
      final cx = w * (.5 + .42 * math.sin(t * (.07 + i * .013) + p));
      final cy = h * (.55 + .38 * math.cos(t * (.05 + i * .011) + p * 1.3));
      final r = math.max(w, h) * (.42 + .08 * math.sin(t * .09 + p));
      glow.shader = ui.Gradient.radial(Offset(cx, cy), r, [
        colors[i].withValues(alpha: .42),
        colors[i].withValues(alpha: 0),
      ]);
      c.drawCircle(Offset(cx, cy), r, glow);
    }
    // Curtains: tall streaks hanging from a wavy line, brightest near the top, fading down.
    for (var k = 0; k < 3; k++) {
      final col = colors[(k + 1) % colors.length];
      final base = h * (.18 + .14 * k);
      const steps = 30;
      for (var j = 0; j < steps; j++) {
        final x = w * (j + .5) / steps;
        final wave = math.sin(x / w * math.pi * (1.6 + k * .5) + t * (.35 + k * .12) + k * 2.1);
        final top = base + h * .1 * wave;
        final len = h * (.38 + .22 * (.5 + .5 * math.sin(t * .5 + j * .35 + k)));
        // Neighbouring streaks breathe together, so the curtain reads as one flowing sheet.
        final a = .2 * (.6 + .4 * math.sin(t * .7 + j * .45 + k * 2)).clamp(0.0, 1.0);
        final streak = Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.linear(
            Offset(x, top),
            Offset(x, top + len),
            [
              col.withValues(alpha: 0),
              col.withValues(alpha: a),
              col.withValues(alpha: a * .45),
              col.withValues(alpha: 0),
            ],
            [0, .12, .45, 1],
          );
        c.drawRect(Rect.fromLTWH(x - w / steps * 1.4, top, w / steps * 2.8, len), streak);
      }
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => true;
}

// ------------------------------------------------------------------ liquid glass

/// A Liquid Glass surface (after Apple's 2025 material): a clear tint, a bright rim that's
/// strongest at the top-left (the light), a soft sheen across the top half and a faint
/// shadow. No backdrop blur: over the already-soft aurora it isn't needed, and blur is
/// expensive on the desk phone.
class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    this.radius = 999,
    this.tint = const Color(0x1FFFFFFF),
    this.padding,
  });
  final Widget child;
  final double radius;
  final Color tint;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _GlassPainter(radius, tint),
    child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
  );
}

class _GlassPainter extends CustomPainter {
  _GlassPainter(this.radius, this.tint);
  final double radius;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(math.min(radius, size.shortestSide / 2)));
    canvas.drawRRect(r.shift(const Offset(0, 3)), Paint()..color = const Color(0x24000000));
    canvas.drawRRect(r, Paint()..color = tint);
    // Sheen: top half, fading down.
    canvas.save();
    canvas.clipRRect(r);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * .55),
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height * .55), [
          const Color(0x2EFFFFFF),
          const Color(0x00FFFFFF),
        ]),
    );
    canvas.restore();
    // Rim light.
    canvas.drawRRect(
      r.deflate(.6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(size.width, size.height),
          [const Color(0xB3FFFFFF), const Color(0x14FFFFFF), const Color(0x59FFFFFF)],
          [0, .55, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(_GlassPainter old) => old.radius != radius || old.tint != tint;
}

/// Keeps a palette for the current art: [auroraDefault] until [artPalette] finishes.
class ArtPalette extends StatefulWidget {
  const ArtPalette({super.key, required this.b64, required this.builder});
  final String? b64;
  final Widget Function(BuildContext context, List<Color> colors) builder;
  @override
  State<ArtPalette> createState() => _ArtPaletteState();
}

class _ArtPaletteState extends State<ArtPalette> {
  List<Color> _colors = auroraDefault;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ArtPalette old) {
    super.didUpdateWidget(old);
    if (old.b64 != widget.b64) _load();
  }

  Future<void> _load() async {
    final b = widget.b64;
    final c = b == null ? auroraDefault : await artPalette(b);
    if (mounted && b == widget.b64) setState(() => _colors = c);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _colors);
}
