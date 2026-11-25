import 'dart:ui';

import 'package:deskpanel/core/mouse_layout.dart';
import 'package:deskpanel/core/settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const main = Rect.fromLTWH(0, 0, 2560, 1440);

  test('a phone dropped under the left of the screen snaps to the bottom edge there', () {
    final r = snapPhone([main], const Rect.fromLTWH(180, 1500, 700, 315));
    expect(r.top, 1440);
    expect(r.left, 180);
    expect(describePlacement([main], r), 'Below your screen, at the left');
  });

  test('dropped on the screen, it moves to the nearest outside edge', () {
    final r = snapPhone([main], const Rect.fromLTWH(20, 600, 700, 315));
    expect(r.right, 0); // left of the screen
    expect(describePlacement([main], r), 'Left of your screen, in the middle');
  });

  test('it keeps at least a quarter of its side against the screen', () {
    final r = snapPhone([main], const Rect.fromLTWH(2500, 1500, 700, 315));
    expect(r.top, 1440);
    expect(r.left, 2560 - 700 / 4);
  });

  test('never covers a second display', () {
    const right = Rect.fromLTWH(2560, 0, 1920, 1080);
    final r = snapPhone([main, right], const Rect.fromLTWH(2400, 1200, 700, 315));
    expect([main, right].every((d) => d.intersect(r).width <= .5 || d.intersect(r).height <= .5), isTrue);
  });

  test('phone drawn to scale from the monitor size', () {
    final d = MacDisplay({'x': 0, 'y': 0, 'w': 2560, 'h': 1440, 'mm_w': 591.1, 'main': true});
    final s = phoneSizeInPoints(const Size(1024, 461), d);
    expect(s.width, closeTo(1024 * 25.4 / 160 * 2560 / 591.1, .01)); // ≈ 704 pt, ~27% of the width
    final noMm = MacDisplay({'x': 0, 'y': 0, 'w': 1920, 'h': 1080, 'mm_w': 0});
    expect(phoneSizeInPoints(const Size(1024, 461), noMm), const Size(1024, 461));
  });

  test('saved position round-trips through settings', () {
    final s = const AppSettings().copyWith(mouseOn: true, mouseRect: const PhoneRect(180, 1440, 704, 317));
    final back = AppSettings.fromJson(s.toJson());
    expect(back.mouseOn, isTrue);
    expect(back.mouseRect!.y, 1440);
  });
}
