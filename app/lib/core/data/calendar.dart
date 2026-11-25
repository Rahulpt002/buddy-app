import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../proto/models.dart';
import 'device_calendar.dart';
import 'topics.dart';

/// Upcoming events (today + 7 days), sorted. Sources merged: the phone's own calendars
/// and the agent's optional ICS feeds (calendar topic). The same event seen in both
/// (same title and start) appears once.
final calendarEventsProvider = Provider<List<CalEvent>>((ref) {
  final e = ref.watch(topicProvider('calendar'));
  final agent = e?.data is CalendarData ? (e!.data as CalendarData).events : const <CalEvent>[];
  final device = ref.watch(deviceCalendarProvider).events;
  return mergeEvents([...device, ...agent], DateTime.now());
});

List<CalEvent> mergeEvents(List<CalEvent> all, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final horizon = today.add(const Duration(days: 8));
  final seen = <String>{};
  final out = <CalEvent>[];
  for (final ev in all) {
    if (!ev.end.isAfter(today) || !ev.start.isBefore(horizon)) continue;
    final key = '${ev.title.trim().toLowerCase()}|${ev.start.millisecondsSinceEpoch ~/ 60000}';
    if (seen.add(key)) out.add(ev);
  }
  return out..sort((a, b) => a.start.compareTo(b.start));
}

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Today's events (including ones already over) and later ones.
({List<CalEvent> today, List<CalEvent> later}) splitEvents(List<CalEvent> all, DateTime now) => (
      today: all.where((e) => sameDay(e.start, now)).toList(),
      later: all.where((e) => e.start.isAfter(DateTime(now.year, now.month, now.day + 1))).toList(),
    );

/// The next event that hasn't started yet today (or is in progress), else null.
CalEvent? nextEvent(List<CalEvent> all, DateTime now) {
  for (final e in all) {
    if (!sameDay(e.start, now)) continue;
    if (e.end.isAfter(now)) return e;
  }
  return null;
}
