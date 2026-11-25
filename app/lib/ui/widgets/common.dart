import 'dart:async';

import 'package:flutter/widgets.dart';

/// Rebuilds on every [period] boundary (default: each minute, aligned to the wall clock).
class Ticker extends StatefulWidget {
  const Ticker({super.key, required this.builder, this.period = const Duration(minutes: 1)});
  final Widget Function(BuildContext, DateTime now) builder;
  final Duration period;
  @override
  State<Ticker> createState() => _TickerState();
}

class _TickerState extends State<Ticker> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  void _schedule() {
    final now = DateTime.now();
    final p = widget.period.inMilliseconds;
    final wait = p - now.millisecondsSinceEpoch % p;
    _t = Timer(Duration(milliseconds: wait + 5), () {
      if (!mounted) return;
      setState(() {});
      _schedule();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, DateTime.now());
}

/// Tap target with a subtle press-scale; no Material ink.
class Press extends StatefulWidget {
  const Press({super.key, required this.child, this.onTap, this.scale = .97, this.onLongPress});
  final Widget child;
  final VoidCallback? onTap, onLongPress;
  final double scale;
  @override
  State<Press> createState() => _PressState();
}

class _PressState extends State<Press> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null && widget.onLongPress == null) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 90),
        child: widget.child,
      ),
    );
  }
}

Color hex(String? s, [Color fallback = const Color(0xFF888888)]) {
  if (s == null) return fallback;
  final h = s.replaceFirst('#', '');
  final v = int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16);
  return v == null ? fallback : Color(v);
}
