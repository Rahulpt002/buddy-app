import 'dart:convert';
import 'dart:io';

import 'package:deskpanel/core/data/open_meteo.dart';
import 'package:deskpanel/core/data/weather.dart';
import 'package:deskpanel/core/settings.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _fx(String name) =>
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('parses a real Open-Meteo forecast', () {
    final j = _fx('open_meteo_forecast');
    final w = parseForecast(j, 'Charlotte');
    final cur = j['current'] as Map<String, dynamic>;
    expect(w.place, 'Charlotte');
    expect(w.now.tempC, (cur['temperature_2m'] as num).toDouble());
    expect(w.now.humidity, (cur['relative_humidity_2m'] as num).round());
    expect(w.now.windDeg, isNotNull);
    expect(w.hours, hasLength(12));
    expect(w.days, hasLength(6));
    // Hourly strip starts at the location's current hour and is consecutive.
    final t0 = DateTime.parse(cur['time'] as String);
    expect(w.hours.first.time.hour, t0.hour);
    for (var i = 1; i < w.hours.length; i++) {
      expect(w.hours[i].time.difference(w.hours[i - 1].time), const Duration(hours: 1));
    }
    for (final d in w.days) {
      expect(d.hiC, greaterThanOrEqualTo(d.loC));
      expect(['sun', 'partly', 'cloud', 'rain'], contains(d.icon));
    }
  });

  test('parses geocoding results with region detail', () {
    final hits = parsePlaces(_fx('open_meteo_geocode'));
    expect(hits, isNotEmpty);
    expect(hits.first.place.name, 'Kochi');
    expect(hits.first.detail, isNotEmpty);
    expect(parsePlaces({}), isEmpty);
  });

  test('units: °C canonical, °F and mph on request', () {
    expect(temp(14.4, false), 14);
    expect(temp(14.4, true), 58);
    expect(wind(8.0, false), '8 km/h');
    expect(wind(8.0, true), '5 mph');
    expect(compass(225), 'SW');
    expect(iconForWmo(61).$1, 'rain');
  });

  test('automatic location is the default; a previously picked city stays manual', () {
    expect(const AppSettings().autoLocation, isTrue);
    expect(AppSettings.fromJson({}).autoLocation, isTrue);
    expect(AppSettings.fromJson({'place': {'name': 'Kochi', 'lat': 9.97, 'lon': 76.28}}).autoLocation, isFalse);
    expect(AppSettings.fromJson({'autoLoc': true, 'place': {'name': 'Kochi', 'lat': 9.97, 'lon': 76.28}}).autoLocation, isTrue);
  });
}
