import 'package:deskpanel/core/settings.dart';
import 'package:deskpanel/ui/skin.dart';
import 'package:deskpanel/ui/widgets/bar_tip.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tapping a column shows its label; tapping again hides it', (tester) async {
    const labels = ['Mon · 1M', 'Tue · 2M', 'Wed · 3M', 'Thu · 4M', 'Fri · 5M', 'Sat · 6M', 'Today · 7M'];
    await tester.pumpWidget(SkinScope(
      skin: Skin.of(SkinId.slate),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 700,
            height: 200,
            child: BarTapTip(count: 7, label: (i) => labels[i], child: const SizedBox.expand()),
          ),
        ),
      ),
    ));
    final box = tester.getRect(find.byType(BarTapTip));
    Offset col(int i) => Offset(box.left + box.width * (i + .5) / 7, box.center.dy);

    await tester.tapAt(col(4));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Fri · 5M'), findsOneWidget);

    await tester.tapAt(col(6));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Fri · 5M'), findsNothing);
    expect(find.text('Today · 7M'), findsOneWidget);

    await tester.tapAt(col(6));
    await tester.pump();
    expect(find.text('Today · 7M'), findsNothing);

    await tester.tapAt(col(0));
    await tester.pump(const Duration(seconds: 5)); // auto-hides
    expect(find.text('Mon · 1M'), findsNothing);
  });
}
