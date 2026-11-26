import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pages.dart';

enum SkinId {
  slate('Slate', 'Rounded cards, icon rail. Closest to the reference.'),
  glow('Glow', 'Editorial serif numbers on a soft coloured glow.'),
  panel('Panel', 'Bench hardware: aluminium face, LCD windows, LED bars.'),
  ink('Ink', 'E-paper: black ink on grey, patterns instead of colour.'),
  mosaic('Mosaic', 'Solid colour tiles on true black; every page owns a colour.'),
  cockpit('Cockpit', 'Glass-cockpit display: bezel soft-keys, dials, caution colours.'),
  blueprint('Blueprint', 'Drawing sheets: graph-paper blue, white line work.'),
  terminal('Terminal', 'A tmux session: btop panes, ping output, monospace.'),
  departures('Departures', 'Split-flap departures board; values flip when they change.'),
  expressive('Expressive', 'Native Android, Material 3 Expressive.'),
  sketch('Sketch', 'Hand-drawn whiteboard: wobbly boxes, hatching, sticky notes.'),
  diorama('Diorama', 'A cozy isometric room where every object on your desk is live.'),
  liquid('Liquid', 'Liquid Glass: clear glass floating over a living wallpaper.');

  const SkinId(this.label, this.blurb);
  final String label, blurb;
}

enum NavStyle { rail, bottom }

/// Where the phone sits in the laptop's display arrangement: a rectangle in the Mac's
/// global points (origin top-left of the main display), touching a display edge.
class PhoneRect {
  const PhoneRect(this.x, this.y, this.w, this.h);
  final double x, y, w, h;
  List<double> toJson() => [x, y, w, h];
  static PhoneRect? fromJson(Object? j) {
    if (j is! List || j.length != 4) return null;
    final v = [for (final e in j) (e as num).toDouble()];
    return PhoneRect(v[0], v[1], v[2], v[3]);
  }
}

/// How far and how often the whole UI drifts to spread wear on OLED pixels.
enum ShiftLevel {
  off(0, Duration.zero),
  gentle(2, Duration(minutes: 3)),
  strong(6, Duration(minutes: 1));

  const ShiftLevel(this.radius, this.every);

  /// Max offset in design pixels.
  final double radius;
  final Duration every;
}

class WeatherPlace {
  const WeatherPlace(this.name, this.lat, this.lon);
  final String name;
  final double lat, lon;
  Map<String, dynamic> toJson() => {'name': name, 'lat': lat, 'lon': lon};
  static WeatherPlace fromJson(Map<String, dynamic> j) =>
      WeatherPlace(j['name'] as String, (j['lat'] as num).toDouble(), (j['lon'] as num).toDouble());
}

class AppSettings {
  const AppSettings({
    this.skin = SkinId.slate,
    this.navStyle = NavStyle.rail,
    this.pages = PageId.values,
    this.hidden = const {},
    this.fahrenheit = false,
    this.clock24 = false,
    this.place,
    this.autoLocation = true,
    this.nightDim = false,
    this.slackSound = true,
    this.mouseOn = false,
    this.mouseRect,
    this.nightStartMin = 23 * 60,
    this.nightEndMin = 7 * 60,
    this.demo = false,
    this.shift = ShiftLevel.strong,
    this.idleDimMin = 10,
    this.saverMin = 30,
    this.rotateMin = 0,
    this.tileOrder = const [],
  });

  final SkinId skin;
  final NavStyle navStyle;

  /// Page order (all pages, including hidden ones).
  final List<PageId> pages;
  final Set<PageId> hidden;
  final bool fahrenheit, clock24;
  final WeatherPlace? place;

  /// Weather follows the phone's (approximate) location; [place] is the last resolved one.
  final bool autoLocation;
  final bool nightDim;

  /// Play the phone's notification sound when a new Slack message arrives.
  final bool slackSound;

  /// Laptop mouse sharing on, and where the phone sits next to the laptop's screen(s).
  final bool mouseOn;
  final PhoneRect? mouseRect;
  final int nightStartMin, nightEndMin;
  final bool demo;

  /// Burn-in protection. Minutes of no touches before dimming / screensaver / page
  /// rotation; 0 = off.
  final ShiftLevel shift;
  final int idleDimMin, saverMin, rotateMin;

  /// Shortcut tile ids in display order (tiles not listed go last).
  final List<String> tileOrder;

  List<PageId> get visiblePages => pages.where((p) => !hidden.contains(p)).toList();

  AppSettings copyWith({
    SkinId? skin,
    NavStyle? navStyle,
    List<PageId>? pages,
    Set<PageId>? hidden,
    bool? fahrenheit,
    bool? clock24,
    WeatherPlace? place,
    bool? autoLocation,
    bool? nightDim,
    bool? slackSound,
    bool? mouseOn,
    PhoneRect? mouseRect,
    int? nightStartMin,
    int? nightEndMin,
    bool? demo,
    ShiftLevel? shift,
    int? idleDimMin,
    int? saverMin,
    int? rotateMin,
    List<String>? tileOrder,
  }) =>
      AppSettings(
        skin: skin ?? this.skin,
        navStyle: navStyle ?? this.navStyle,
        pages: pages ?? this.pages,
        hidden: hidden ?? this.hidden,
        fahrenheit: fahrenheit ?? this.fahrenheit,
        clock24: clock24 ?? this.clock24,
        place: place ?? this.place,
        autoLocation: autoLocation ?? this.autoLocation,
        nightDim: nightDim ?? this.nightDim,
        slackSound: slackSound ?? this.slackSound,
        mouseOn: mouseOn ?? this.mouseOn,
        mouseRect: mouseRect ?? this.mouseRect,
        nightStartMin: nightStartMin ?? this.nightStartMin,
        nightEndMin: nightEndMin ?? this.nightEndMin,
        demo: demo ?? this.demo,
        shift: shift ?? this.shift,
        idleDimMin: idleDimMin ?? this.idleDimMin,
        saverMin: saverMin ?? this.saverMin,
        rotateMin: rotateMin ?? this.rotateMin,
        tileOrder: tileOrder ?? this.tileOrder,
      );

  Map<String, dynamic> toJson() => {
        'skin': skin.name,
        'nav': navStyle.name,
        'pages': pages.map((p) => p.name).toList(),
        'hidden': hidden.map((p) => p.name).toList(),
        'f': fahrenheit,
        'h24': clock24,
        'place': place?.toJson(),
        'autoLoc': autoLocation,
        'dim': nightDim,
        'slackSnd': slackSound,
        'mouseOn': mouseOn,
        if (mouseRect != null) 'mouseRect': mouseRect!.toJson(),
        'dimS': nightStartMin,
        'dimE': nightEndMin,
        'demo': demo,
        'shift': shift.name,
        'idleDim': idleDimMin,
        'saver': saverMin,
        'rotate': rotateMin,
        'tiles': tileOrder,
      };

  static AppSettings fromJson(Map<String, dynamic> j) {
    T byName<T extends Enum>(List<T> vs, Object? n, T d) =>
        vs.firstWhere((v) => v.name == n, orElse: () => d);
    // 'games' was replaced by 'slack' (same slot, same hidden state).
    Object? renamed(Object? n) => switch (n) { 'games' => 'slack', 'printer' => 'hotspot', _ => n };
    final saved = ((j['pages'] as List?) ?? const [])
        .map((n) => PageId.values.where((p) => p.name == renamed(n)))
        .expand((e) => e)
        .toList();
    // Pages added in later versions go at the end.
    final pages = [...saved, ...PageId.values.where((p) => !saved.contains(p))];
    return AppSettings(
      skin: byName(SkinId.values, j['skin'], SkinId.slate),
      navStyle: byName(NavStyle.values, j['nav'], NavStyle.rail),
      pages: pages,
      // The Printer page became Hotspot: it takes Printer's slot but isn't hidden like it was.
      hidden: ((j['hidden'] as List?) ?? const [])
          .where((n) => n != 'printer')
          .map((n) => PageId.values.where((p) => p.name == renamed(n)))
          .expand((e) => e)
          .where((p) => p != PageId.home)
          .toSet(),
      fahrenheit: (j['f'] as bool?) ?? false,
      clock24: (j['h24'] as bool?) ?? false,
      place: j['place'] == null ? null : WeatherPlace.fromJson(j['place'] as Map<String, dynamic>),
      // A city picked before automatic location existed stays the user's choice.
      autoLocation: (j['autoLoc'] as bool?) ?? (j['place'] == null),
      nightDim: (j['dim'] as bool?) ?? false,
      slackSound: (j['slackSnd'] as bool?) ?? true,
      mouseOn: (j['mouseOn'] as bool?) ?? false,
      mouseRect: PhoneRect.fromJson(j['mouseRect']),
      nightStartMin: (j['dimS'] as int?) ?? 23 * 60,
      nightEndMin: (j['dimE'] as int?) ?? 7 * 60,
      demo: (j['demo'] as bool?) ?? false,
      // Older builds stored a single on/off switch ('burn'); off stays off.
      shift: j['shift'] != null
          ? byName(ShiftLevel.values, j['shift'], ShiftLevel.strong)
          : (j['burn'] == false ? ShiftLevel.off : ShiftLevel.strong),
      idleDimMin: (j['idleDim'] as int?) ?? 10,
      saverMin: (j['saver'] as int?) ?? 30,
      rotateMin: (j['rotate'] as int?) ?? 0,
      tileOrder: ((j['tiles'] as List?) ?? const []).cast<String>(),
    );
  }
}

/// Overridden in main() with the instance loaded before the first frame.
final prefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());

class SettingsNotifier extends Notifier<AppSettings> {
  static const _key = 'settings.v1';

  @override
  AppSettings build() {
    final prefs = ref.read(prefsProvider);
    final raw = prefs.getString(_key);
    var s = const AppSettings();
    if (raw != null) {
      try {
        s = AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    // One-time move to Celsius: early builds defaulted to °F and saved that default, so
    // it can't be told apart from a real choice. After this, the setting is respected.
    if (prefs.getBool('migrated.celsius') != true) {
      prefs.setBool('migrated.celsius', true);
      if (s.fahrenheit) {
        s = s.copyWith(fahrenheit: false);
        prefs.setString(_key, jsonEncode(s.toJson()));
      }
    }
    return s;
  }

  void update(AppSettings Function(AppSettings s) f) {
    state = f(state);
    ref.read(prefsProvider).setString(_key, jsonEncode(state.toJson()));
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
