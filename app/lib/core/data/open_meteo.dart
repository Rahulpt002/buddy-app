// Open-Meteo (https://open-meteo.com): free, no API key. Forecast + geocoding.
import 'dart:convert';
import 'dart:io';

import '../settings.dart';
import 'weather.dart';

const _forecastHost = 'api.open-meteo.com';
const _geoHost = 'geocoding-api.open-meteo.com';

Future<Map<String, dynamic>> _getJson(Uri uri) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final req = await client.getUrl(uri);
    final res = await req.close().timeout(const Duration(seconds: 15));
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}: $body', uri: uri);
    return jsonDecode(body) as Map<String, dynamic>;
  } finally {
    client.close(force: true);
  }
}

Uri forecastUri(WeatherPlace p) => Uri.https(_forecastHost, '/v1/forecast', {
      'latitude': p.lat.toStringAsFixed(4),
      'longitude': p.lon.toStringAsFixed(4),
      'current':
          'temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,wind_direction_10m',
      'hourly': 'temperature_2m,weather_code',
      'daily': 'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max',
      'timezone': 'auto',
      'forecast_days': '7',
      'wind_speed_unit': 'kmh',
    });

Future<Map<String, dynamic>> fetchForecastJson(WeatherPlace p) => _getJson(forecastUri(p));

/// Parses an Open-Meteo forecast response (canonical units °C, km/h). Times are the
/// location's local wall-clock times.
WeatherData parseForecast(Map<String, dynamic> j, String place, {DateTime? now}) {
  final cur = j['current'] as Map<String, dynamic>;
  num n(Object? v) => (v as num?) ?? 0;
  final (icon, cond) = iconForWmo(n(cur['weather_code']).toInt());

  final h = j['hourly'] as Map<String, dynamic>;
  final hTimes = (h['time'] as List).map((s) => DateTime.parse(s as String)).toList();
  final hTemps = (h['temperature_2m'] as List).map(n).toList();
  final hCodes = (h['weather_code'] as List).map(n).toList();
  // Start at the hour containing "now" in the location's own clock (the API's current.time).
  final curTime = DateTime.parse(cur['time'] as String);
  final start = DateTime(curTime.year, curTime.month, curTime.day, curTime.hour);
  var i0 = hTimes.indexWhere((t) => !t.isBefore(start));
  if (i0 < 0) i0 = 0;
  final hours = <WeatherHour>[
    for (var i = i0; i < hTimes.length && i < i0 + 12; i++)
      WeatherHour(hTimes[i], hTemps[i].toDouble(), iconForWmo(hCodes[i].toInt()).$1),
  ];

  final d = j['daily'] as Map<String, dynamic>;
  final dTimes = (d['time'] as List).map((s) => DateTime.parse(s as String)).toList();
  final days = <WeatherDay>[
    for (var i = 0; i < dTimes.length && i < 6; i++)
      WeatherDay(
        dTimes[i],
        n((d['temperature_2m_max'] as List)[i]).toDouble(),
        n((d['temperature_2m_min'] as List)[i]).toDouble(),
        n((d['precipitation_probability_max'] as List)[i]).round(),
        iconForWmo(n((d['weather_code'] as List)[i]).toInt()).$1,
      ),
  ];

  return WeatherData(
    place: place,
    now: WeatherNow(
      tempC: n(cur['temperature_2m']).toDouble(),
      feelsC: n(cur['apparent_temperature']).toDouble(),
      humidity: n(cur['relative_humidity_2m']).round(),
      windKmh: n(cur['wind_speed_10m']).toDouble(),
      windDeg: (cur['wind_direction_10m'] as num?)?.toDouble(),
      icon: icon,
      condition: cond,
      updated: now ?? DateTime.now(),
    ),
    hours: hours,
    days: days,
  );
}

/// A geocoding search hit.
class PlaceHit {
  const PlaceHit(this.place, this.detail);
  final WeatherPlace place;

  /// "Kerala, India"
  final String detail;
}

Future<List<PlaceHit>> searchPlaces(String query) async {
  final q = query.trim();
  if (q.length < 2) return const [];
  final j = await _getJson(Uri.https(_geoHost, '/v1/search', {'name': q, 'count': '8', 'language': 'en', 'format': 'json'}));
  return parsePlaces(j);
}

List<PlaceHit> parsePlaces(Map<String, dynamic> j) => [
      for (final r in ((j['results'] as List?) ?? const []).cast<Map<String, dynamic>>())
        PlaceHit(
          WeatherPlace(r['name'] as String, (r['latitude'] as num).toDouble(), (r['longitude'] as num).toDouble()),
          [r['admin1'], r['country']].whereType<String>().where((s) => s.isNotEmpty).join(', '),
        ),
    ];
