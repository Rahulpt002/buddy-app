import 'package:deskpanel/core/remote_pointer.dart';
import 'package:deskpanel/ui/remote_cursor.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> send(WidgetTester t, Map<String, dynamic> m) async {
    remotePointer.add(m);
    await t.pump();
  }

  testWidgets('laptop mouse: click taps, drag drags, wheel scrolls, leave hides', (t) async {
    t.view.physicalSize = const Size(800, 400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    var taps = 0;
    var dragged = 0.0;
    final scroll = ScrollController();
    await t.pumpWidget(MaterialApp(
      builder: (context, child) => RemoteCursor(child: child!),
      home: Row(children: [
        SizedBox(
          width: 400,
          child: Column(children: [
            GestureDetector(onTap: () => taps++, child: Container(width: 400, height: 200, color: Colors.red)),
            GestureDetector(
              onHorizontalDragUpdate: (d) => dragged += d.delta.dx,
              child: Container(width: 400, height: 200, color: Colors.blue),
            ),
          ]),
        ),
        Expanded(
          child: ListView(controller: scroll, children: [for (var i = 0; i < 50; i++) SizedBox(height: 40, child: Text('$i'))]),
        ),
      ]),
    ));

    await send(t, {'k': 'enter', 'x': .1, 'y': .25});
    expect(find.byType(CustomPaint), findsWidgets); // the arrow is drawn
    await send(t, {'k': 'down'});
    await send(t, {'k': 'up'});
    await t.pump(const Duration(milliseconds: 400));
    expect(taps, 1);

    await send(t, {'k': 'move', 'x': .1, 'y': .75});
    await send(t, {'k': 'down'});
    for (var i = 1; i <= 6; i++) {
      await send(t, {'k': 'move', 'x': .1 + i * .03, 'y': .75});
    }
    await send(t, {'k': 'up'});
    expect(dragged, greaterThan(100));

    await send(t, {'k': 'move', 'x': .75, 'y': .5});
    await send(t, {'k': 'scroll', 'dy': 120});
    await t.pumpAndSettle();
    expect(scroll.offset, greaterThan(0));

    await send(t, {'k': 'leave'});
    expect(taps, 1);
  });
}
