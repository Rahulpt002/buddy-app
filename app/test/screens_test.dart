// Renders every skin × page to PNG at the concepts' design size, with the shared
// fixtures as data. Opt-in (it writes files):
//
//   SCREENS=1 flutter test test/screens_test.dart
//   SCREENS=1 ONLY=glow flutter test test/screens_test.dart        # one skin
//   SCREENS=1 ONLY=glow PAGE=music flutter test test/screens_test.dart
//   NAV=bottom ...            # bottom nav bar instead of the rail (slate/expressive/blueprint)
//   FIXTURES=/some/dir ...    # other fixture JSONs, e.g. live agent data
//
// Output: build/screens/<skin>-<page>.png (2x).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:deskpanel/app.dart';
import 'package:deskpanel/core/conn/controller.dart';
import 'package:deskpanel/core/data/demo.dart';
import 'package:deskpanel/core/data/device_calendar.dart';
import 'package:deskpanel/core/data/topics.dart';
import 'package:deskpanel/core/pages.dart';
import 'package:deskpanel/core/settings.dart';
import 'package:deskpanel/ui/screens/mouse_arrange_screen.dart';
import 'package:deskpanel/ui/icons.dart';
import 'package:deskpanel/ui/pages/kit.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SampleWeather extends WeatherNotifier {
  @override
  WeatherData? build() => sampleWeather();
}

class NoDeviceCalendar extends DeviceCalendarNotifier {
  @override
  DeviceCalendarState build() => const DeviceCalendarState();
}

class FakeAgent extends AgentController {
  @override
  ConnState build() => const ConnState(LinkStatus.demo, agentName: 'Demo laptop');

  @override
  Future<ActionResult> request(String action,
      [Map<String, dynamic> params = const {},
      void Function(Map<String, dynamic>)? onProgress,
      Duration timeout = const Duration(seconds: 10)]) async {
    if (action == 'mouse.displays') {
      return const ActionResult(true, result: {
        'displays': [
          {'x': 0, 'y': 0, 'w': 2560, 'h': 1440, 'mm_w': 591.1, 'mm_h': 329.5, 'main': true, 'builtin': false},
        ],
      });
    }
    return const ActionResult(true);
  }
}

class FixtureStore extends TopicStore {
  FixtureStore(this.data);
  final Map<String, Json> data;
  @override
  Map<String, TopicEntry> build() => {
        for (final e in data.entries) e.key: TopicEntry(parseTopic(e.key, e.value), e.value, DateTime.now()),
      };
}

Map<String, Json> loadFixtures() {
  final dir = Directory(Platform.environment['FIXTURES'] ?? '../shared/fixtures');
  final meta = jsonDecode(File('${dir.path}/_meta.json').readAsStringSync()) as Json;
  final data = <String, Json>{
    for (final t in allTopics) t: jsonDecode(File('${dir.path}/$t.json').readAsStringSync()) as Json,
  };
  rebaseFixtures(data, meta['generated_at'] as int, DateTime.now());
  return data;
}

Future<void> loadFonts() async {
  const fams = {
    'Inter': ['inter-400', 'inter-500', 'inter-600', 'inter-700'],
    'Fraunces': ['fraunces-300', 'fraunces-400', 'fraunces-500'],
    'Manrope': ['manrope-400', 'manrope-500', 'manrope-600', 'manrope-700'],
    'Barlow': ['barlow-400', 'barlow-500', 'barlow-600', 'barlow-700'],
    'Barlow Condensed': ['barlow-condensed-500', 'barlow-condensed-600'],
    'Bricolage Grotesque': ['bricolage-grotesque-var'],
    'Atkinson Hyperlegible': ['atkinson-hyperlegible-400', 'atkinson-hyperlegible-700'],
    'Archivo': ['archivo-var'],
    'B612': ['b612-400', 'b612-700'],
    'B612 Mono': ['b612-mono-400', 'b612-mono-700'],
    'Overpass': ['overpass-var'],
    'Overpass Mono': ['overpass-mono-var'],
    'JetBrains Mono': ['jetbrains-mono-400', 'jetbrains-mono-700'],
    'Oswald': ['oswald-var'],
    'Roboto Flex': ['roboto-flex-var'],
    'Shantell Sans': ['shantell-sans-var'],
    'Fredoka': ['fredoka-var'],
  };
  for (final f in fams.entries) {
    final l = FontLoader(f.key);
    for (final file in f.value) {
      l.addFont(Future.value(ByteData.sublistView(File('assets/fonts/$file.ttf').readAsBytesSync())));
    }
    await l.load();
  }
}

void main() {
  final enabled = Platform.environment['SCREENS'] == '1';
  final only = Platform.environment['ONLY'];
  final onlyPage = Platform.environment['PAGE'];

  setUpAll(() async {
    if (enabled) await loadFonts();
  });

  // PAGE=arrange: the Settings → Phone position screen, per skin.
  for (final skin in SkinId.values) {
    if (only != null && only != skin.name) continue;
    testWidgets('${skin.name}-arrange', skip: !enabled || onlyPage != 'arrange', (tester) async {
      SharedPreferences.setMockInitialValues({
        'settings.v1': jsonEncode(AppSettings(skin: skin, shift: ShiftLevel.off, idleDimMin: 0, saverMin: 0).toJson()),
      });
      final prefs = await SharedPreferences.getInstance();
      tester.view.physicalSize = const ui.Size(915 * 2, 412 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          agentProvider.overrideWith(FakeAgent.new),
          topicStoreProvider.overrideWith(() => FixtureStore(loadFixtures())),
          weatherProvider.overrideWith(SampleWeather.new),
          deviceCalendarProvider.overrideWith(NoDeviceCalendar.new),
        ],
        child: RepaintBoundary(key: key, child: const DeskPanelApp()),
      ));
      await tester.pump();
      tester.state<NavigatorState>(find.byType(Navigator).first).push(mouseArrangeRoute());
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 60)));
        await tester.pump(const Duration(milliseconds: 400));
      }
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final bytes = await tester.runAsync(() async {
        final img = await boundary.toImage(pixelRatio: 2);
        return (await img.toByteData(format: ui.ImageByteFormat.png))!;
      });
      File('build/screens/${skin.name}-arrange.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes!.buffer.asUint8List());
      await tester.pumpWidget(const SizedBox());
    });
  }

  final variants = <(PageId, int)>[
    for (final p in PageId.values) ...[(p, 0), if (p == PageId.system || p == PageId.github) (p, 1)],
  ];

  for (final skin in SkinId.values) {
    if (only != null && only != skin.name) continue;
    for (final (page, tab) in variants) {
      if (onlyPage != null && onlyPage != page.name) continue;
      final name = '${skin.name}-${page.name}${tab == 1 ? (page == PageId.system ? '-internet' : '-gitlab') : ''}';
      testWidgets(name, skip: !enabled, (tester) async {
        SharedPreferences.setMockInitialValues({
          'settings.v1': jsonEncode(AppSettings(skin: skin, shift: ShiftLevel.off, idleDimMin: 0, saverMin: 0, navStyle: Platform.environment['NAV'] == 'bottom' ? NavStyle.bottom : NavStyle.rail).toJson()),
          // GLASS=tinted: the Liquid theme's Tinted glass.
          if (Platform.environment['GLASS'] != null) 'liquid.glass': Platform.environment['GLASS']!,
        });
        final prefs = await SharedPreferences.getInstance();
        tester.view.physicalSize = const ui.Size(915 * 2, 412 * 2);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        final data = loadFixtures();
        await tester.pumpWidget(ProviderScope(
          overrides: [
            prefsProvider.overrideWithValue(prefs),
            agentProvider.overrideWith(FakeAgent.new),
            topicStoreProvider.overrideWith(() => FixtureStore(data)),
            systemTabProvider.overrideWith(() => SystemTab(page == PageId.system ? tab : 0)),
            codeSourceProvider.overrideWith(() => CodeSource(page == PageId.github ? tab : 0)),
            weatherProvider.overrideWith(SampleWeather.new),
            deviceCalendarProvider.overrideWith(NoDeviceCalendar.new),
          ],
          child: RepaintBoundary(key: key, child: DeskPanelApp(initialPage: page)),
        ));
        // SVG icons decode asynchronously; let them land, then settle animations.
        for (var i = 0; i < 3; i++) {
          await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 60)));
          await tester.pump(const Duration(milliseconds: 400));
        }
        await tester.pump(const Duration(seconds: 2));
        // TAP=<icon name>: tap that icon first (e.g. TAP=speaker opens Liquid's volume bar).
        final tap = Platform.environment['TAP'];
        if (tap != null) {
          await tester.tap(find.byWidgetPredicate((w) => w is DpIcon && w.name == tap).first);
          await tester.pump(); // starts the animations
          for (var i = 0; i < 6; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
        }
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final bytes = await tester.runAsync(() async {
          final img = await boundary.toImage(pixelRatio: 2);
          return (await img.toByteData(format: ui.ImageByteFormat.png))!;
        });
        final out = File('build/screens/$name.png')..createSync(recursive: true);
        out.writeAsBytesSync(bytes!.buffer.asUint8List());
        // Unmount so periodic timers (clocks, tickers) are cancelled.
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
