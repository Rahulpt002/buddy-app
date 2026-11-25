import 'package:deskpanel/core/settings.dart';
import 'package:deskpanel/ui/burn_guard.dart';
import 'package:deskpanel/ui/skin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

Future<void> _pump(WidgetTester tester, AppSettings s, ValueNotifier<int> taps) async {
  SharedPreferences.setMockInitialValues({'settings.v1': jsonEncode(s.toJson()), 'migrated.celsius': true});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: [prefsProvider.overrideWithValue(prefs)],
    child: SkinScope(
      skin: Skin.of(SkinId.slate),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: BurnGuard(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => taps.value++,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    ),
  ));
}

void main() {
  testWidgets('dims after idle, screensaver later, first tap only wakes', (tester) async {
    final taps = ValueNotifier(0);
    await _pump(tester, const AppSettings(idleDimMin: 5, saverMin: 10, shift: ShiftLevel.off), taps);

    Finder veil() => find.byWidgetPredicate((w) => w is AnimatedOpacity && w.opacity > 0);
    expect(veil(), findsNothing);

    await tester.pump(const Duration(minutes: 5, seconds: 1));
    expect(veil(), findsOneWidget, reason: 'dimmed after 5 idle minutes');

    // A touch while dimmed undims and still reaches the app.
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pump();
    expect(veil(), findsNothing);
    expect(taps.value, 1);

    // 10 minutes after that touch: screensaver (clock on black).
    await tester.pump(const Duration(minutes: 10, seconds: 1));
    expect(find.textContaining(':'), findsWidgets);

    // Waking tap is swallowed, the next one goes through.
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    expect(taps.value, 1, reason: 'the wake tap must not press whatever is underneath');
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    expect(taps.value, 2);

    await tester.pumpWidget(const SizedBox()); // cancel timers
  });

  testWidgets('pixel shift moves the content', (tester) async {
    final taps = ValueNotifier(0);
    await _pump(tester, const AppSettings(idleDimMin: 0, saverMin: 0, shift: ShiftLevel.strong), taps);
    Offset pos() => tester.getTopLeft(find.byType(SizedBox).last);
    final before = pos();
    await tester.pump(const Duration(minutes: 1));
    await tester.pump(const Duration(seconds: 5)); // let the 4 s glide finish
    final after = pos();
    expect((after - before).distance, greaterThan(2), reason: 'it moved');
    // Every position stays within the shift radius of the true layout (origin).
    expect(before.distance, lessThanOrEqualTo(ShiftLevel.strong.radius + .01));
    expect(after.distance, lessThanOrEqualTo(ShiftLevel.strong.radius + .01));
    await tester.pumpWidget(const SizedBox());
  });

  test('old on/off setting migrates: on -> strong, off -> off', () {
    expect(AppSettings.fromJson({'burn': true}).shift, ShiftLevel.strong);
    expect(AppSettings.fromJson({'burn': false}).shift, ShiftLevel.off);
    expect(AppSettings.fromJson({}).saverMin, 30);
  });
}
