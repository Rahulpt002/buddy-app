import 'dart:typed_data';

import 'package:deskpanel/ui/widgets/aurora.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Uint8List _img(List<(Color, int)> parts) {
  final out = <int>[];
  for (final (c, n) in parts) {
    for (var i = 0; i < n; i++) {
      out.addAll([(c.r * 255).round(), (c.g * 255).round(), (c.b * 255).round(), 255]);
    }
  }
  return Uint8List.fromList(out);
}

void main() {
  test('album colours become four glowing aurora colours, biggest first', () {
    final p = paletteFromRgba(_img([
      (const Color(0xFF1E4FD8), 300), // blue (most)
      (const Color(0xFFE0447A), 150), // pink
      (const Color(0xFF808080), 400), // grey: ignored
      (const Color(0xFF0A0A0A), 200), // black: ignored
    ]));
    expect(p, hasLength(4));
    expect(HSVColor.fromColor(p[0]).hue, closeTo(HSVColor.fromColor(const Color(0xFF1E4FD8)).hue, 12));
    expect(HSVColor.fromColor(p[1]).hue, closeTo(HSVColor.fromColor(const Color(0xFFE0447A)).hue, 12));
    expect(p.every((c) => HSVColor.fromColor(c).value > .9), isTrue); // brightened to glow
  });

  test('grey or black covers fall back to northern-light colours', () {
    expect(paletteFromRgba(_img([(const Color(0xFF777777), 500), (const Color(0xFF050505), 76)])), auroraDefault);
  });

  test('a one-colour cover still gets four related colours', () {
    final p = paletteFromRgba(_img([(const Color(0xFFD83A1E), 576)]));
    expect(p, hasLength(4));
    expect(p.toSet(), hasLength(4));
  });
}
