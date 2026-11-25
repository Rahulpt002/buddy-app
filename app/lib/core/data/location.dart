// Phone location for weather: approximate (city-level) only, never precise GPS.
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../settings.dart';

class LocateException implements Exception {
  const LocateException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Finds roughly where the phone is and names the place (e.g. "Kochi").
/// Throws [LocateException] with a user-facing message when it can't.
Future<WeatherPlace> locatePhone() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const LocateException('Location is off on the phone. Turn it on, or pick a city.');
  }
  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
  if (perm == LocationPermission.denied) {
    throw const LocateException('Location permission was declined. Pick a city instead.');
  }
  if (perm == LocationPermission.deniedForever) {
    throw const LocateException('Location is blocked for DeskPanel in Android settings. Pick a city instead.');
  }

  Position? pos = await Geolocator.getLastKnownPosition();
  if (pos == null || DateTime.now().difference(pos.timestamp) > const Duration(hours: 6)) {
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 20)),
      );
    } catch (_) {
      if (pos == null) throw const LocateException("Couldn't get the phone's location. Pick a city instead.");
    }
  }

  // ~1 km precision is plenty for weather and avoids sending an exact position.
  double round2(double v) => (v * 100).roundToDouble() / 100;
  var name = 'Current location';
  try {
    final marks = await Geocoding().placemarkFromCoordinates(pos.latitude, pos.longitude);
    if (marks.isNotEmpty) {
      final m = marks.first;
      name = [m.locality, m.subAdministrativeArea, m.administrativeArea]
          .firstWhere((s) => s != null && s.isNotEmpty, orElse: () => name)!;
    }
  } catch (_) {
    // No geocoder / offline: weather still works, just without a nice name.
  }
  return WeatherPlace(name, round2(pos.latitude), round2(pos.longitude));
}
