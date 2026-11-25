import 'dart:async';

import 'package:flutter/widgets.dart';

import '../pages/kit.dart';
import '../skin.dart';

/// Wrap a chart made of [count] equal-width columns: tapping a column shows a small
/// bubble with [label] for it (e.g. "Fri · 55.3M tokens"). Tap it again, tap outside,
/// or wait a few seconds to hide. Styled like the skin's toast.
class BarTapTip extends StatefulWidget {
  const BarTapTip({super.key, required this.count, required this.label, required this.child});
  final int count;
  final String Function(int i) label;
  final Widget child;

  @override
  State<BarTapTip> createState() => _BarTapTipState();
}

class _BarTapTipState extends State<BarTapTip> {
  int? _sel;
  Timer? _hide;

  void _tap(Offset p, double w) {
    if (widget.count <= 0 || w <= 0) return;
    final i = (p.dx / w * widget.count).floor().clamp(0, widget.count - 1);
    _hide?.cancel();
    setState(() => _sel = _sel == i ? null : i);
    if (_sel != null) _hide = Timer(const Duration(seconds: 4), () => mounted ? setState(() => _sel = null) : null);
  }

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ts = toastStyleOf(context.skin);
    final sel = _sel;
    return GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Use the chart's real width (some charts are narrower than their slot).
        onTapUp: (d) => _tap(d.localPosition, (context.findRenderObject() as RenderBox?)?.size.width ?? 0),
        child: Stack(clipBehavior: Clip.none, children: [
          widget.child,
          if (sel != null && sel < widget.count)
            Positioned.fill(
              child: IgnorePointer(
                child: Align(
                  // Centre over the column; Align keeps the bubble inside the chart.
                  alignment: Alignment(-1 + 2 * (sel + .5) / widget.count, -1),
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(sel),
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 160),
                    builder: (context, v, child) => Opacity(opacity: v, child: child),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: ts.bg.withValues(alpha: ts.bg.a < .5 ? .92 : ts.bg.a),
                        borderRadius: BorderRadius.circular(ts.radius.clamp(0, 10).toDouble()),
                        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 10, offset: Offset(0, 3))],
                      ),
                      child: Text(widget.label(sel),
                          style: TextStyle(
                              fontFamily: ts.font,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: ts.fg,
                              decoration: TextDecoration.none)),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      );
  }
}
