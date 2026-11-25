import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings.dart';

enum TimerMode {
  focus('Focus', 25),
  shortBreak('Short break', 5),
  longBreak('Long break', 15),
  countdown('Timer', 10),
  stopwatch('Stopwatch', 0);

  const TimerMode(this.label, this.defaultMin);
  final String label;
  final int defaultMin;
  bool get isPomodoro => index <= 2;
}

class TimerState {
  const TimerState({
    this.mode = TimerMode.focus,
    this.running = false,
    this.endAt,
    this.remaining = const Duration(minutes: 25),
    this.startedAt,
    this.elapsed = Duration.zero,
    this.sessions = 0,
    this.sessionsDay = 0,
    this.countdownMin = 10,
    this.doneAt,
  });

  final TimerMode mode;
  final bool running;

  /// Countdown modes: wall-clock end while running, [remaining] while paused.
  final DateTime? endAt;
  final Duration remaining;

  /// Stopwatch: start while running, accumulated [elapsed] while paused.
  final DateTime? startedAt;
  final Duration elapsed;

  /// Completed focus sessions today ([sessionsDay] = yyyymmdd they belong to).
  final int sessions, sessionsDay;
  final int countdownMin;

  /// Set when a countdown finishes; drives the screen flash.
  final DateTime? doneAt;

  Duration get total => mode == TimerMode.countdown
      ? Duration(minutes: countdownMin)
      : Duration(minutes: mode.defaultMin);

  /// What the big digits show.
  Duration display(DateTime now) {
    if (mode == TimerMode.stopwatch) {
      return running && startedAt != null ? elapsed + now.difference(startedAt!) : elapsed;
    }
    if (running && endAt != null) {
      final r = endAt!.difference(now);
      return r.isNegative ? Duration.zero : r;
    }
    return remaining;
  }

  /// 0..1 progress through the current countdown (stopwatch: seconds in the minute).
  double progress(DateTime now) {
    if (mode == TimerMode.stopwatch) return (display(now).inMilliseconds % 60000) / 60000;
    final t = total.inMilliseconds;
    return t == 0 ? 0 : 1 - display(now).inMilliseconds / t;
  }

  bool get pristine => mode == TimerMode.stopwatch ? elapsed == Duration.zero && !running : remaining == total && !running;

  TimerState copy({
    TimerMode? mode,
    bool? running,
    DateTime? endAt,
    bool clearEnd = false,
    Duration? remaining,
    DateTime? startedAt,
    bool clearStart = false,
    Duration? elapsed,
    int? sessions,
    int? sessionsDay,
    int? countdownMin,
    DateTime? doneAt,
  }) =>
      TimerState(
        mode: mode ?? this.mode,
        running: running ?? this.running,
        endAt: clearEnd ? null : (endAt ?? this.endAt),
        remaining: remaining ?? this.remaining,
        startedAt: clearStart ? null : (startedAt ?? this.startedAt),
        elapsed: elapsed ?? this.elapsed,
        sessions: sessions ?? this.sessions,
        sessionsDay: sessionsDay ?? this.sessionsDay,
        countdownMin: countdownMin ?? this.countdownMin,
        doneAt: doneAt ?? this.doneAt,
      );
}

int _dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

/// Runs on the phone. Time is computed from wall-clock instants, so it stays exact across
/// page switches and app pauses.
class TimerNotifier extends Notifier<TimerState> {
  Timer? _done;

  /// Hook for the finish chime (set by the app; kept out of here for testability).
  static void Function()? onFinished;

  @override
  TimerState build() {
    ref.onDispose(() => _done?.cancel());
    final p = ref.read(prefsProvider);
    final day = p.getInt('timer.sessionsDay') ?? 0;
    final today = _dayKey(DateTime.now());
    return TimerState(
      sessions: day == today ? (p.getInt('timer.sessions') ?? 0) : 0,
      sessionsDay: today,
      countdownMin: p.getInt('timer.countdownMin') ?? 10,
    );
  }

  void setMode(TimerMode m) {
    _done?.cancel();
    final base = state.copy(mode: m, running: false, clearEnd: true, clearStart: true, elapsed: Duration.zero);
    state = base.copy(remaining: base.total);
  }

  void toggle() => state.running ? pause() : start();

  void start() {
    final now = DateTime.now();
    if (state.mode == TimerMode.stopwatch) {
      state = state.copy(running: true, startedAt: now);
      return;
    }
    var rem = state.remaining;
    if (rem <= Duration.zero) rem = state.total;
    state = state.copy(running: true, endAt: now.add(rem), remaining: rem);
    _done?.cancel();
    _done = Timer(rem, _finish);
  }

  void pause() {
    final now = DateTime.now();
    _done?.cancel();
    if (state.mode == TimerMode.stopwatch) {
      state = state.copy(running: false, elapsed: state.display(now), clearStart: true);
    } else {
      state = state.copy(running: false, remaining: state.display(now), clearEnd: true);
    }
  }

  void reset() => setMode(state.mode);

  /// Countdown mode: change length by [deltaMin] (1..180).
  void adjust(int deltaMin) {
    if (state.mode != TimerMode.countdown || state.running) return;
    final m = (state.countdownMin + deltaMin).clamp(1, 180);
    ref.read(prefsProvider).setInt('timer.countdownMin', m);
    state = state.copy(countdownMin: m, remaining: Duration(minutes: m));
  }

  void _finish() {
    final now = DateTime.now();
    var sessions = state.sessions;
    final today = _dayKey(now);
    if (state.sessionsDay != today) sessions = 0;
    if (state.mode == TimerMode.focus) sessions++;
    final p = ref.read(prefsProvider);
    p.setInt('timer.sessions', sessions);
    p.setInt('timer.sessionsDay', today);
    state = state.copy(
        running: false, clearEnd: true, remaining: state.total, sessions: sessions, sessionsDay: today, doneAt: now);
    HapticFeedback.heavyImpact();
    onFinished?.call();
  }
}

final timerProvider = NotifierProvider<TimerNotifier, TimerState>(TimerNotifier.new);
