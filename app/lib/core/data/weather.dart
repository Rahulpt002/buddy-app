import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings.dart';
import 'location.dart';
import 'open_meteo.dart';

/// Weather is fetched by the phone (Open-Meteo, step 5). Canonical units: °C, km/h.
class WeatherNow {
  const WeatherNow({
    required this.tempC,
    required this.feelsC,
    required this.humidity,
    required this.windKmh,
    required this.icon,
    required this.condition,
    required this.updated,
    this.windDeg,
  });
  final double tempC, feelsC, windKmh;

  /// Direction the wind comes FROM, degrees (0 = N). Null when unknown.
  final double? windDeg;
  final int humidity;

  /// Concept icon key: sun | partly | cloud | rain (see [iconForWmo]).
  final String icon;
  final String condition;
  final DateTime updated;
}

class WeatherHour {
  const WeatherHour(this.time, this.tempC, this.icon);
  final DateTime time;
  final double tempC;
  final String icon;
}

class WeatherDay {
  const WeatherDay(this.date, this.hiC, this.loC, this.precipPct, this.icon);
  final DateTime date;
  final double hiC, loC;
  final int precipPct;
  final String icon;
}

class WeatherData {
  const WeatherData({required this.place, required this.now, required this.hours, required this.days});
  final String place;
  final WeatherNow now;

  /// Next 12 hours, starting with the current hour.
  final List<WeatherHour> hours;

  /// Today + 5 days.
  final List<WeatherDay> days;
}

/// WMO weather code -> (icon key, condition text).
(String, String) iconForWmo(int code) => switch (code) {
      0 => ('sun', 'Clear'),
      1 => ('sun', 'Mostly clear'),
      2 => ('partly', 'Partly cloudy'),
      3 => ('cloud', 'Overcast'),
      45 || 48 => ('cloud', 'Fog'),
      51 || 53 || 55 || 56 || 57 => ('rain', 'Drizzle'),
      61 || 63 || 65 || 66 || 67 || 80 || 81 || 82 => ('rain', 'Rain'),
      71 || 73 || 75 || 77 || 85 || 86 => ('rain', 'Snow'),
      95 || 96 || 99 => ('rain', 'Thunderstorms'),
      _ => ('cloud', 'Cloudy'),
    };

/// 16-point compass label ("SW") for a wind direction.
String compass(double deg) =>
    const ['N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE', 'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'][
        ((deg % 360) / 22.5).round() % 16];

double fToC(num f) => (f - 32) * 5 / 9;
double cToF(num c) => c * 9 / 5 + 32;

/// Rounded display temperature in the user's unit.
int temp(double c, bool fahrenheit) => (fahrenheit ? cToF(c) : c).round();

String wind(double kmh, bool fahrenheit) =>
    fahrenheit ? '${(kmh / 1.609).round()} mph' : '${kmh.round()} km/h';

/// Sample data (the reference screenshots' Charlotte forecast) used until a location is
/// set and in demo mode.
WeatherData sampleWeather([DateTime? at]) {
  final now = at ?? DateTime.now();
  final h0 = DateTime(now.year, now.month, now.day, now.hour);
  const hours = [58, 59, 61, 63, 65, 67, 68, 69, 67, 64, 61, 57];
  const hicons = ['cloud', 'cloud', 'cloud', 'partly', 'partly', 'sun', 'sun', 'sun', 'partly', 'cloud', 'cloud', 'cloud'];
  const days = [(69, 40, 0, 'cloud'), (61, 48, 63, 'rain'), (57, 54, 54, 'rain'), (68, 56, 38, 'rain'),
    (62, 50, 0, 'cloud'), (50, 43, 46, 'rain')];
  return WeatherData(
    place: 'Charlotte',
    now: WeatherNow(
      tempC: fToC(58),
      feelsC: fToC(53),
      humidity: 53,
      windKmh: 5 * 1.609,
      windDeg: 225,
      icon: 'cloud',
      condition: 'Overcast',
      updated: now.subtract(const Duration(minutes: 5)),
    ),
    hours: [for (var i = 0; i < 12; i++) WeatherHour(h0.add(Duration(hours: i)), fToC(hours[i]), hicons[i])],
    days: [
      for (var i = 0; i < 6; i++)
        WeatherDay(DateTime(now.year, now.month, now.day + i), fToC(days[i].$1), fToC(days[i].$2), days[i].$3,
            days[i].$4),
    ],
  );
}

/// Live weather (Open-Meteo, refreshed every 15 min, last result cached for offline).
/// Location: the phone's approximate position (re-checked every 6 h) unless the user
/// picked a city. Sample data in demo mode; null until a place is known.
class WeatherNotifier extends Notifier<WeatherData?> {
  Timer? _timer;
  static const _cacheKey = 'weather.cache.v1';
  static const _locatedKey = 'weather.locatedAt';
  static const relocateEvery = Duration(hours: 6);
  bool _locating = false;

  @override
  WeatherData? build() {
    final s = ref.watch(settingsProvider.select((s) => (s.demo, s.place, s.autoLocation)));
    _timer?.cancel();
    ref.onDispose(() => _timer?.cancel());
    if (s.$1) return sampleWeather();
    final place = s.$2;
    _timer = Timer.periodic(const Duration(minutes: 15), (_) => _tick());
    Future.microtask(_tick);
    return place == null ? null : _loadCache(place);
  }

  bool get _locationStale {
    final at = ref.read(prefsProvider).getInt(_locatedKey) ?? 0;
    return DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(at)) > relocateEvery;
  }

  Future<void> _tick() async {
    final s = ref.read(settingsProvider);
    if (s.demo) return;
    if (s.autoLocation && (s.place == null || _locationStale)) {
      await locate(); // updates settings.place -> rebuild -> fetch
      if (ref.read(settingsProvider).place != s.place) return;
    }
    await refresh();
  }

  /// Resolve the phone's location now (also used by Settings → "Use phone location").
  Future<void> locate() async {
    if (_locating) return;
    _locating = true;
    try {
      final p = await locatePhone();
      ref.read(prefsProvider).setInt(_locatedKey, DateTime.now().millisecondsSinceEpoch);
      ref.read(weatherIssueProvider.notifier).set(null);
      final cur = ref.read(settingsProvider);
      if (cur.place?.lat != p.lat || cur.place?.lon != p.lon || cur.place?.name != p.name) {
        ref.read(settingsProvider.notifier).update((x) => x.copyWith(place: p));
      }
    } on LocateException catch (e) {
      ref.read(weatherIssueProvider.notifier).set(e.message);
    } catch (e) {
      ref.read(weatherIssueProvider.notifier).set("Couldn't get the phone's location. Pick a city instead.");
      debugPrint('DeskPanel location: $e');
    } finally {
      _locating = false;
    }
  }

  Future<void> refresh() async {
    final place = ref.read(settingsProvider).place;
    if (place == null || ref.read(settingsProvider).demo) return;
    try {
      final j = await fetchForecastJson(place);
      final w = parseForecast(j, place.name);
      if (ref.read(settingsProvider).place?.name != place.name) return; // changed meanwhile
      state = w;
      ref.read(prefsProvider).setString(_cacheKey, jsonEncode({'place': place.toJson(), 'json': j, 'at': DateTime.now().millisecondsSinceEpoch}));
    } catch (e) {
      debugPrint('DeskPanel weather: $e'); // keep showing the last forecast
    }
  }

  WeatherData? _loadCache(WeatherPlace place) {
    final raw = ref.read(prefsProvider).getString(_cacheKey);
    if (raw == null) return null;
    try {
      final c = jsonDecode(raw) as Map<String, dynamic>;
      if (WeatherPlace.fromJson(c['place'] as Map<String, dynamic>).name != place.name) return null;
      return parseForecast(c['json'] as Map<String, dynamic>, place.name,
          now: DateTime.fromMillisecondsSinceEpoch(c['at'] as int));
    } catch (_) {
      return null;
    }
  }
}

/// Why weather can't be shown (e.g. location declined); null when fine.
class WeatherIssue extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? m) => state = m;
}

final weatherIssueProvider = NotifierProvider<WeatherIssue, String?>(WeatherIssue.new);

final weatherProvider = NotifierProvider<WeatherNotifier, WeatherData?>(WeatherNotifier.new);
