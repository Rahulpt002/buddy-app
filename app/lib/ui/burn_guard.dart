// Burn-in protection for always-on (often older OLED) screens:
//  - pixel shift: the whole UI drifts around a small circle so static edges move;
//  - dim when idle: a black veil after N minutes without touches (OLED emits less);
//  - screensaver: after longer idle, pure black with a dim clock that wanders.
// Idle is measured with Timers restarted on every touch (testable with fake time).
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/data/weather.dart';
import '../core/settings.dart';
import '../core/timer.dart';
import 'fmt.dart';
import 'skin.dart';

/// Last touch anywhere in the app (used by page rotation).
class Activity {
  static DateTime last = DateTime.now();

  /// Last real finger on the screen (unlike [last], not bumped by programmatic wakes).
  static DateTime lastTouch = DateTime.now();
}

/// Bump to wake the screen (undim, close the saver), e.g. when a Slack message arrives.
final screenWake = ValueNotifier<int>(0);

/// Full screens open over the dashboard (Settings, pairing). They paint the skin's base
/// [SkinTokens.bg], so while one is open the shift strip uses that instead of
/// [Skin.backdrop] (which can differ, e.g. Diorama at night).
final overlayScreens = ValueNotifier<int>(0);
final overlayScreenObserver = OverlayScreenObserver();

class OverlayScreenObserver extends NavigatorObserver {
  void _bump(Route<dynamic> r, Route<dynamic>? below, int d) {
    if (r is! PageRoute || below == null) return; // dialogs and the home route don't count
    scheduleMicrotask(() => overlayScreens.value = math.max(0, overlayScreens.value + d));
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _bump(route, previousRoute, 1);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _bump(route, previousRoute, -1);
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _bump(route, previousRoute, -1);
}

class BurnGuard extends ConsumerStatefulWidget {
  const BurnGuard({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<BurnGuard> createState() => _BurnGuardState();
}

class _BurnGuardState extends ConsumerState<BurnGuard> {
  Timer? _dimT, _saverT, _shiftT;
  bool _dim = false, _saver = false;
  int _step = 0;

  /// 12 points around a circle, visited in a star order so consecutive moves are
  /// far apart (every pixel row/column changes over a cycle).
  static Offset _offset(int step, double r) {
    if (r == 0) return Offset.zero;
    final k = (step * 5) % 12;
    final a = k / 12 * 2 * math.pi;
    final rr = step % 2 == 0 ? r : r * .55;
    return Offset(math.cos(a) * rr, math.sin(a) * rr);
  }

  @override
  void initState() {
    super.initState();
    _arm();
    _startShift();
    screenWake.addListener(_wake);
  }

  @override
  void dispose() {
    screenWake.removeListener(_wake);
    _dimT?.cancel();
    _saverT?.cancel();
    _shiftT?.cancel();
    super.dispose();
  }

  void _arm() {
    _dimT?.cancel();
    _saverT?.cancel();
    final s = ref.read(settingsProvider);
    if (s.idleDimMin > 0) {
      _dimT = Timer(Duration(minutes: s.idleDimMin), () => mounted ? setState(() => _dim = true) : null);
    }
    if (s.saverMin > 0) {
      _saverT = Timer(Duration(minutes: s.saverMin), () => mounted ? setState(() => _saver = true) : null);
    }
  }

  void _startShift() {
    _shiftT?.cancel();
    final lvl = ref.read(settingsProvider).shift;
    if (lvl == ShiftLevel.off) return;
    _shiftT = Timer.periodic(lvl.every, (_) => setState(() => _step++));
  }

  void _touched() {
    Activity.last = Activity.lastTouch = DateTime.now();
    if (_saver) return; // the saver's own tap handler wakes (and swallows that tap)
    if (_dim) setState(() => _dim = false);
    _arm();
  }

  void _wake() {
    Activity.last = DateTime.now();
    if (!mounted) return;
    setState(() {
      _saver = false;
      _dim = false;
    });
    _arm();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(settingsProvider.select((s) => (s.idleDimMin, s.saverMin)), (_, _) => _wake());
    ref.listen(settingsProvider.select((s) => s.shift), (_, _) => _startShift());
    final shift = ref.watch(settingsProvider.select((s) => s.shift));
    final backdrop = context.skin.backdrop(context, ref);
    final base = context.tk.bg;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _touched(),
      child: Stack(fit: StackFit.expand, children: [
        // Fills the strip uncovered by the shift, in the colour of whatever screen is showing.
        ValueListenableBuilder<int>(
          valueListenable: overlayScreens,
          builder: (context, n, _) => ColoredBox(color: n > 0 ? base : backdrop),
        ),
        TweenAnimationBuilder<Offset>(
          tween: Tween(end: _offset(_step, shift.radius)),
          duration: const Duration(seconds: 4),
          curve: Curves.easeInOut,
          builder: (context, o, child) => Transform.translate(offset: o, child: child),
          child: widget.child,
        ),
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: _dim && !_saver ? .6 : 0,
            duration: const Duration(seconds: 3),
            child: const ColoredBox(color: Color(0xFF000000)),
          ),
        ),
        if (_saver) Positioned.fill(child: _Saver(onWake: _wake)),
      ]),
    );
  }
}

/// Pure black with a small, dim, wandering clock. Tap anywhere to wake.
class _Saver extends ConsumerStatefulWidget {
  const _Saver({required this.onWake});
  final VoidCallback onWake;
  @override
  ConsumerState<_Saver> createState() => _SaverState();
}

class _SaverState extends ConsumerState<_Saver> {
  final _rng = math.Random();
  late Timer _move, _tick;
  Alignment _at = Alignment.center;

  @override
  void initState() {
    super.initState();
    _move = Timer.periodic(const Duration(seconds: 20), (_) {
      setState(() => _at = Alignment(_rng.nextDouble() * 1.6 - .8, _rng.nextDouble() * 1.6 - .8));
    });
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _move.cancel();
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final s = ref.watch(settingsProvider);
    final w = ref.watch(weatherProvider);
    final timer = ref.watch(timerProvider);
    final now = DateTime.now();
    const dim = Color(0xFF6E6E6E); // low emission, still readable across a desk
    final lines = <String>[
      longDate(now),
      if (w != null) '${temp(w.now.tempC, s.fahrenheit)}° ${w.now.condition.toLowerCase()}',
      if (timer.running) '${timer.mode.label} ${mmss(timer.display(now).inMilliseconds)}',
    ];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onWake,
      child: ColoredBox(
        color: const Color(0xFF000000),
        child: AnimatedAlign(
          alignment: _at,
          duration: const Duration(seconds: 6),
          curve: Curves.easeInOut,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(clockFull(now, h24: s.clock24),
                style: TextStyle(fontFamily: t.display, fontSize: 72, fontWeight: FontWeight.w300, color: dim, height: 1)),
            const SizedBox(height: 8),
            Text(lines.join('  ·  '),
                style: TextStyle(fontFamily: t.body, fontSize: 15, color: dim.withValues(alpha: .8))),
          ]),
        ),
      ),
    );
  }
}
