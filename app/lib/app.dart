import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/conn/controller.dart';
import 'core/data/topics.dart';
import 'core/pages.dart';
import 'core/platform/notify_sound.dart';
import 'core/proto/models.dart';
import 'core/settings.dart';
import 'core/timer.dart';
import 'ui/burn_guard.dart';
import 'ui/pages/page_host.dart';
import 'ui/remote_cursor.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/skin.dart';

class DeskPanelApp extends ConsumerWidget {
  const DeskPanelApp({super.key, this.initialPage = PageId.home});

  /// For tests / screenshots.
  final PageId initialPage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = Skin.of(ref.watch(settingsProvider.select((s) => s.skin)));
    final t = skin.tokens;
    return SkinScope(
      skin: skin,
      child: MaterialApp(
        title: 'DeskPanel',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: t.dark ? Brightness.dark : Brightness.light,
          scaffoldBackgroundColor: t.bg,
          fontFamily: t.body,
          colorScheme: ColorScheme.fromSeed(
            seedColor: t.accent,
            brightness: t.dark ? Brightness.dark : Brightness.light,
            primary: t.accent,
            onPrimary: t.onAccent,
            surface: t.bg,
          ),
        ),
        builder: (context, child) =>
            RemoteCursor(child: DesignScale(child: TimerFlash(child: BurnGuard(child: child!)))),
        navigatorObservers: [overlayScreenObserver],
        home: DeskPanelHome(initialPage: initialPage),
      ),
    );
  }
}

class DeskPanelHome extends ConsumerStatefulWidget {
  const DeskPanelHome({super.key, this.initialPage = PageId.home});
  final PageId initialPage;
  @override
  ConsumerState<DeskPanelHome> createState() => _DeskPanelHomeState();
}

class _DeskPanelHomeState extends ConsumerState<DeskPanelHome> {
  late PageId _page = widget.initialPage;
  Timer? _rotate;

  /// Set when a new Slack message opened the Slack page: rotation waits until the next
  /// real touch after that moment, then carries on as usual.
  DateTime? _slackHoldSince;
  static const _alertedKey = 'slack.alertedTs';

  @override
  void initState() {
    super.initState();
    ref.listenManual(topicStoreProvider.select((m) => m['slack']?.data), (_, d) => _onSlack(d),
        fireImmediately: true);
    // Burn-in: while nobody touches the screen, cycle through the visible pages.
    _rotate = Timer.periodic(const Duration(seconds: 30), (_) {
      final s = ref.read(settingsProvider);
      if (s.rotateMin == 0 || !mounted) return;
      final hold = _slackHoldSince;
      if (hold != null) {
        if (!Activity.lastTouch.isAfter(hold)) return; // still showing the new message
        _slackHoldSince = null;
      }
      final idle = DateTime.now().difference(Activity.last);
      final sinceSwitch = DateTime.now().difference(_switchedAt);
      final every = Duration(minutes: s.rotateMin);
      if (idle >= every && sinceSwitch >= every) {
        final pages = s.visiblePages;
        _go(pages[(pages.indexOf(_page) + 1) % pages.length]);
      }
    });
  }

  @override
  void dispose() {
    _rotate?.cancel();
    super.dispose();
  }

  DateTime _switchedAt = DateTime.now();

  void _go(PageId p) {
    _switchedAt = DateTime.now();
    setState(() => _page = p);
    ref.read(agentProvider.notifier).setPage(p);
  }

  void _openSettings() => Navigator.of(context).push(settingsRoute(context));

  /// A Slack message newer than any seen before jumps straight to the Slack page (and
  /// wakes the screen). The first data ever just records where we are, so installing or
  /// pairing doesn't replay old messages.
  void _onSlack(TopicData? d) {
    if (d is! SlackData) return;
    final prefs = ref.read(prefsProvider);
    final seen = prefs.getInt(_alertedKey);
    final unread = d.unreadMessages;
    if (unread.isEmpty) {
      // Nothing waiting: start from here, so the very next message opens the page.
      if (seen == null && d.status == TopicStatus.ok) prefs.setInt(_alertedKey, 0);
      return;
    }
    final newest = unread.map((m) => m.ts.millisecondsSinceEpoch).reduce((a, b) => a > b ? a : b);
    if (seen != null && newest <= seen) return;
    prefs.setInt(_alertedKey, newest);
    if (seen == null || !mounted) return;
    final s = ref.read(settingsProvider);
    if (s.demo || s.hidden.contains(PageId.slack)) return;
    if (s.slackSound) playNotificationSound();
    screenWake.value++;
    if (overlayScreens.value > 0) return; // don't pull you out of Settings
    _slackHoldSince = DateTime.now();
    if (_page != PageId.slack) _go(PageId.slack);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final conn = ref.watch(agentProvider);
    final pages = settings.visiblePages;
    if (!pages.contains(_page)) _page = PageId.home;
    final skin = context.skin;

    return Scaffold(
      backgroundColor: skin.tokens.bg,
      body: NightDim(
        settings: settings,
        child: Stack(fit: StackFit.expand, children: [
            skin.shell(ShellArgs(
              pages: pages,
              current: _page,
              onSelect: _go,
              conn: conn,
              onStatusTap: _openSettings,
              settings: settings,
              child: AnimatedSwitcher(
                duration: skin.pageTransition,
                child: KeyedSubtree(
                  key: ValueKey((_page, settings.skin)),
                  child: PageHost(page: _page, onOpen: _go, onSettings: _openSettings),
                ),
              ),
            )),
            OfflineBanner(conn: conn, onTap: _openSettings),
          ]),
      ),
    );
  }
}

/// Optional schedule that dims the screen with a black overlay at night.
class NightDim extends StatelessWidget {
  const NightDim({super.key, required this.settings, required this.child});
  final AppSettings settings;
  final Widget child;

  static bool active(AppSettings s, DateTime now) {
    if (!s.nightDim) return false;
    final m = now.hour * 60 + now.minute;
    final a = s.nightStartMin, b = s.nightEndMin;
    return a <= b ? (m >= a && m < b) : (m >= a || m < b);
  }

  @override
  Widget build(BuildContext context) {
    if (!settings.nightDim) return child;
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(minutes: 1), (i) => i),
      builder: (context, _) {
        final on = active(settings, DateTime.now());
        return Stack(fit: StackFit.expand, children: [
          child,
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: on ? .72 : 0,
              duration: const Duration(seconds: 2),
              child: const ColoredBox(color: Colors.black),
            ),
          ),
        ]);
      },
    );
  }
}

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.conn, required this.onTap});
  final ConnState conn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final show = conn.status == LinkStatus.offline ||
        conn.status == LinkStatus.authFailed ||
        conn.status == LinkStatus.protoMismatch;
    final t = context.tk;
    final msg = switch (conn.status) {
      LinkStatus.authFailed => 'The laptop rejected this phone. Tap to pair again.',
      LinkStatus.protoMismatch => 'The app and the laptop agent are different versions. Update both.',
      _ => 'Showing the last data received. Plug in the USB cable or check both devices are on the same Wi-Fi.'
          '${conn.retryIn != null ? '  Retrying in ${max(1, conn.retryIn!.inSeconds)}s.' : ''}',
    };
    return Positioned(
      left: 0,
      right: 0,
      bottom: 14,
      child: IgnorePointer(
        ignoring: !show,
        child: AnimatedOpacity(
          opacity: show ? 1 : 0,
          duration: const Duration(milliseconds: 250),
          child: Center(
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 640),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: Color.alphaBlend(t.bad.withValues(alpha: .14), t.dark ? const Color(0xF20D0F12) : t.bg),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: t.bad.withValues(alpha: .5)),
                ),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: 'Laptop not connected.  ',
                        style: t.t(12.5, w: FontWeight.w700, c: t.text)),
                    TextSpan(text: msg, style: t.t(12.5, c: t.muted)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The concepts are designed at 915×412 logical px. Scale the whole UI so that canvas
/// fits the screen: phones (~1018×458) get ×1.11, a 1280×800 tablet ×1.4 with a taller
/// layout, small phones shrink down to ×0.8. System font scaling is pinned to 1 because
/// every layout is fixed-size.
class DesignScale extends StatelessWidget {
  const DesignScale({super.key, required this.child});
  final Widget child;
  static const designW = 915.0, designH = 412.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        if (!c.maxWidth.isFinite || !c.maxHeight.isFinite || c.maxWidth == 0) return child;
        final s = min(c.maxWidth / designW, c.maxHeight / designH).clamp(.8, 3.0);
        final w = c.maxWidth / s, h = c.maxHeight / s;
        final mq = MediaQuery.of(context);
        return FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(
            width: w,
            height: h,
            child: MediaQuery(
              data: mq.copyWith(
                size: Size(w, h),
                padding: mq.padding / s,
                viewPadding: mq.viewPadding / s,
                viewInsets: mq.viewInsets / s,
                textScaler: TextScaler.noScaling,
              ),
              child: child,
            ),
          ),
        );
      });
}

/// Flashes the screen and plays a chime when a timer finishes (works on any page).
class TimerFlash extends ConsumerStatefulWidget {
  const TimerFlash({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<TimerFlash> createState() => _TimerFlashState();
}

class _TimerFlashState extends ConsumerState<TimerFlash> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  AudioPlayer? _player; // created on first use (keeps tests plugin-free)

  @override
  void initState() {
    super.initState();
    TimerNotifier.onFinished = () {
      _c.forward(from: 0);
      (_player ??= AudioPlayer()).play(AssetSource('sounds/chime.wav'));
    };
  }

  @override
  void dispose() {
    TimerNotifier.onFinished = null;
    _c.dispose();
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        widget.child,
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              // Three pulses that fade out.
              final v = _c.value;
              final a = _c.isAnimating ? (sin(v * pi * 6).abs() * (1 - v) * .55) : 0.0;
              return ColoredBox(color: context.tk.accent.withValues(alpha: a));
            },
          ),
        ),
      ]);
}
