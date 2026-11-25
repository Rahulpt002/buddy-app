import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// Stable 32-bit FNV-1a hash (Dart's String.hashCode isn't stable across runs).
int stableHash(String s) {
  var h = 0x811c9dc5;
  for (final c in utf8.encode(s)) {
    h = ((h ^ c) * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}

/// Hue derived from a title; deterministic so the same game/track always gets the same art.
double hueFor(String title) => (stableHash(title) % 360).toDouble();

/// The "sun over layered hills" fallback artwork from the reference screenshots
/// (port of the concepts' `art()` SVG). Fills its box, cropped like `xMidYMid slice`.
class FallbackArt extends StatelessWidget {
  const FallbackArt({super.key, required this.title, this.hue, this.seed, this.radius = 0});
  final String title;
  final double? hue;
  final int? seed;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final h = hue ?? hueFor(title);
    final s = seed ?? (stableHash('$title#') % 7) + 1;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CustomPaint(painter: _ArtPainter(h, s), size: Size.infinite),
    );
  }
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(this.hue, this.seed);
  final double hue;
  final int seed;

  Color hsl(double h, double s, double l) =>
      HSLColor.fromAHSL(1, h % 360, (s / 100).clamp(0, 1), (l / 100).clamp(0, 1)).toColor();

  @override
  void paint(Canvas canvas, Size size) {
    const sat = 58.0;
    // The SVG is 100 units tall and W units wide (W = 100 * aspect). It's drawn with
    // "slice": scale to cover, centred.
    final aspect = size.width / size.height;
    final w = 100 * aspect, k = w / 100;
    final scale = size.height / 100;
    canvas.save();
    canvas.scale(scale);
    final sky = Rect.fromLTWH(0, 0, w, 100);
    canvas.drawRect(
        sky,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [hsl(hue, sat, 20), hsl(hue + 18, sat + 8, 44)],
          ).createShader(sky));
    final sx = (28 + (seed * 37) % 44) * k, sy = 30.0 + (seed * 13) % 14;
    canvas.drawCircle(Offset(sx, sy), 15, Paint()..color = hsl(44, 96, 82));
    canvas.save();
    canvas.scale(k, 1);
    final back = Path()
      ..moveTo(0, 64)
      ..cubicTo(22, 55, 42, 70, 66, 60)
      ..cubicTo(90, 50, 100, 56, 100, 56)
      ..lineTo(100, 100)
      ..lineTo(0, 100)
      ..close();
    canvas.drawPath(back, Paint()..color = hsl(hue + 6, sat - 10, 30));
    final front = Path()
      ..moveTo(0, 78)
      ..cubicTo(28, 70, 58, 86, 100, 72)
      ..lineTo(100, 100)
      ..lineTo(0, 100)
      ..close();
    canvas.drawPath(front, Paint()..color = hsl(hue, sat, 15));
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ArtPainter o) => o.hue != hue || o.seed != seed;
}

/// Album art from the agent (base64 JPEG) with the generated fallback.
class AlbumArt extends StatelessWidget {
  const AlbumArt({super.key, required this.title, this.b64, this.radius = 0});
  final String title;
  final String? b64;
  final double radius;

  static final _cache = <String, Uint8List>{};

  @override
  Widget build(BuildContext context) {
    final data = b64;
    if (data == null || data.isEmpty) return FallbackArt(title: title, radius: radius);
    final bytes = _cache.putIfAbsent(data.length > 64 ? data.substring(0, 64) + data.length.toString() : data,
        () => base64Decode(data));
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.memory(bytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => FallbackArt(title: title)),
    );
  }
}
