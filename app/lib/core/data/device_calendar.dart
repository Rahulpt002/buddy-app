// Events from the phone's own calendars (Google, Samsung, Exchange... whatever is synced),
// read with the user's permission. Refreshed every 10 minutes and when the app resumes.
import 'dart:async';

import 'package:device_calendar/device_calendar.dart' as dc;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../proto/models.dart';
import '../settings.dart';

enum CalendarAccess { unknown, granted, denied }

class DeviceCalendarState {
  const DeviceCalendarState({this.events = const [], this.access = CalendarAccess.unknown});
  final List<CalEvent> events;
  final CalendarAccess access;
}

String _hex(int? argb) =>
    argb == null ? '#5AA9FF' : '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

class DeviceCalendarNotifier extends Notifier<DeviceCalendarState> with WidgetsBindingObserver {
  final _plugin = dc.DeviceCalendarPlugin();
  Timer? _timer;
  bool _loading = false;

  /// Ask at most once per app run. The permission dialog pauses and resumes the app, and
  /// a resume triggers a load, so re-asking on every load loops when the system auto-denies.
  static bool _asked = false;

  @override
  DeviceCalendarState build() {
    final demo = ref.watch(settingsProvider.select((s) => s.demo));
    _timer?.cancel();
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      _timer?.cancel();
      WidgetsBinding.instance.removeObserver(this);
    });
    if (demo) return const DeviceCalendarState();
    _timer = Timer.periodic(const Duration(minutes: 10), (_) => load());
    Future.microtask(load);
    return const DeviceCalendarState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) load();
  }

  Future<void> load() async {
    if (_loading || ref.read(settingsProvider).demo) return;
    _loading = true;
    try {
      var ok = (await _plugin.hasPermissions()).data ?? false;
      if (!ok && !_asked) {
        _asked = true;
        ok = (await _plugin.requestPermissions()).data ?? false;
      }
      if (!ok) {
        state = const DeviceCalendarState(access: CalendarAccess.denied);
        return;
      }
      final cals = (await _plugin.retrieveCalendars()).data ?? const [];
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, now.day);
      final to = from.add(const Duration(days: 8));
      final out = <CalEvent>[];
      for (final cal in cals) {
        final res = await _plugin.retrieveEvents(cal.id, dc.RetrieveEventsParams(startDate: from, endDate: to));
        for (final e in res.data ?? const <dc.Event>[]) {
          if (e.start == null || e.end == null) continue;
          out.add(CalEvent(
            id: 'dev-${cal.id}-${e.eventId}-${e.start!.millisecondsSinceEpoch}',
            title: (e.title?.trim().isNotEmpty ?? false) ? e.title!.trim() : '(No title)',
            start: DateTime.fromMillisecondsSinceEpoch(e.start!.millisecondsSinceEpoch),
            end: DateTime.fromMillisecondsSinceEpoch(e.end!.millisecondsSinceEpoch),
            allDay: e.allDay ?? false,
            location: (e.location?.trim().isNotEmpty ?? false) ? e.location!.trim() : null,
            calendar: cal.name,
            color: _hex(cal.color),
          ));
        }
      }
      state = DeviceCalendarState(events: out, access: CalendarAccess.granted);
    } catch (e) {
      debugPrint('DeskPanel calendar: $e'); // keep the previous events
    } finally {
      _loading = false;
    }
  }
}

final deviceCalendarProvider =
    NotifierProvider<DeviceCalendarNotifier, DeviceCalendarState>(DeviceCalendarNotifier.new);
