import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../core/remote_pointer.dart';
import 'burn_guard.dart';

/// The laptop's mouse on the phone. While the agent says the mouse is here ([remotePointer]
/// frames), draws an arrow and feeds Flutter real pointer events at that spot:
/// - button down / drag / up → a touch (so taps, drags and swipes behave like a finger),
/// - moves with no button   → mouse hover,
/// - wheel                  → a scroll.
/// Wraps the whole app (outside DesignScale) so 0..1 coordinates map to the real screen.
class RemoteCursor extends StatefulWidget {
  const RemoteCursor({super.key, required this.child});
  final Widget child;

  @override
  State<RemoteCursor> createState() => _RemoteCursorState();
}

class _RemoteCursorState extends State<RemoteCursor> {
  // Device ids well away from the real touchscreen's.
  static const _mouse = 7101, _touch = 7102;
  static int _nextPointer = 1 << 20;

  final _clock = Stopwatch()..start();
  StreamSubscription<Map<String, dynamic>>? _sub;
  final _pos = ValueNotifier<Offset?>(null); // local position, null = not on the phone
  Offset? _global;
  int? _down; // active touch pointer id while the button is held
  DateTime _woke = DateTime(0);

  @override
  void initState() {
    super.initState();
    _sub = remotePointer.stream.listen(_on);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _leave();
    _pos.dispose();
    super.dispose();
  }

  Duration get _now => _clock.elapsed;

  void _dispatch(PointerEvent e) => GestureBinding.instance.handlePointerEvent(e);

  void _on(Map<String, dynamic> m) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final k = m['k'] as String?;
    if (k == 'leave') return _leave();
    final x = (m['x'] as num?)?.toDouble(), y = (m['y'] as num?)?.toDouble();
    if (x != null && y != null) {
      final local = Offset(x * box.size.width, y * box.size.height);
      _pos.value = local;
      _global = box.localToGlobal(local);
    }
    final g = _global;
    if (g == null) return;
    switch (k) {
      case 'enter':
        _dispatch(PointerAddedEvent(timeStamp: _now, kind: PointerDeviceKind.mouse, device: _mouse, position: g));
        _wake(force: true);
      case 'move':
        if (_down != null) {
          _dispatch(PointerMoveEvent(
              timeStamp: _now, kind: PointerDeviceKind.touch, device: _touch, pointer: _down!,
              position: g, delta: g - (_lastTouch ?? g), buttons: kPrimaryButton));
          _lastTouch = g;
        } else {
          _dispatch(PointerHoverEvent(timeStamp: _now, kind: PointerDeviceKind.mouse, device: _mouse, position: g));
        }
        _wake();
      case 'down':
        if (_down != null) break;
        _down = _nextPointer++;
        _lastTouch = g;
        _dispatch(PointerAddedEvent(timeStamp: _now, kind: PointerDeviceKind.touch, device: _touch, position: g));
        _dispatch(PointerDownEvent(
            timeStamp: _now, kind: PointerDeviceKind.touch, device: _touch, pointer: _down!,
            position: g, buttons: kPrimaryButton));
      case 'up':
        _release(cancel: false);
      case 'scroll':
        final dy = (m['dy'] as num?)?.toDouble() ?? 0;
        if (dy != 0) {
          _dispatch(PointerScrollEvent(
              timeStamp: _now, kind: PointerDeviceKind.mouse, device: _mouse, position: g, scrollDelta: Offset(0, dy)));
        }
        _wake();
    }
  }

  Offset? _lastTouch;

  void _release({required bool cancel}) {
    final p = _down, g = _global;
    if (p == null || g == null) return;
    _down = null;
    _dispatch(cancel
        ? PointerCancelEvent(timeStamp: _now, kind: PointerDeviceKind.touch, device: _touch, pointer: p, position: g)
        : PointerUpEvent(timeStamp: _now, kind: PointerDeviceKind.touch, device: _touch, pointer: p, position: g));
    _dispatch(PointerRemovedEvent(timeStamp: _now, kind: PointerDeviceKind.touch, device: _touch, position: g));
  }

  void _leave() {
    _release(cancel: true);
    final g = _global;
    if (g != null && _pos.value != null) {
      _dispatch(PointerRemovedEvent(timeStamp: _now, kind: PointerDeviceKind.mouse, device: _mouse, position: g));
    }
    if (mounted) _pos.value = null;
  }

  /// Moving the laptop's mouse over the phone keeps the screen awake, like a finger would.
  void _wake({bool force = false}) {
    final now = DateTime.now();
    if (!force && now.difference(_woke) < const Duration(seconds: 2)) return;
    _woke = now;
    Activity.last = now;
    screenWake.value++;
  }

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        widget.child,
        IgnorePointer(
          child: ValueListenableBuilder<Offset?>(
            valueListenable: _pos,
            builder: (context, p, _) => p == null
                ? const SizedBox.shrink()
                : CustomPaint(painter: _ArrowPainter(p)),
          ),
        ),
      ]);
}

/// A classic arrow pointer: white with a dark outline, tip at [tip].
class _ArrowPainter extends CustomPainter {
  _ArrowPainter(this.tip);
  final Offset tip;

  @override
  void paint(Canvas canvas, Size size) {
    const s = 1.25; // ~24 px tall
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(0, 17 * s)
      ..lineTo(4.2 * s, 13 * s)
      ..lineTo(7.2 * s, 19.5 * s)
      ..lineTo(10 * s, 18.3 * s)
      ..lineTo(7.1 * s, 11.9 * s)
      ..lineTo(12.6 * s, 11.9 * s)
      ..close();
    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    canvas.drawShadow(p, const Color(0xFF000000), 2, false);
    canvas.drawPath(p, Paint()..color = const Color(0xFFFFFFFF));
    canvas.drawPath(
        p,
        Paint()
          ..color = const Color(0xFF111111)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..strokeJoin = StrokeJoin.round);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ArrowPainter o) => o.tip != tip;
}
