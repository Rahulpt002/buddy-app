// Concept 15 — Diorama: your desk as a cozy isometric room. Every object is live and
// tappable; detail pages pair a close-up of the object with soft cards. Light and dark
// variants: Auto follows the phone, the top-bar button switches (saved as `diorama.mode`).
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/conn/controller.dart';
import '../../core/pages.dart';
import '../../core/settings.dart';
import '../fmt.dart';
import '../icons.dart';
import '../pages/kit.dart';
import '../skin.dart';
import '../widgets/common.dart';
import 'diorama_pages.dart';

// ------------------------------------------------------------------ mode

enum DioramaMode {
  auto('Auto'),
  light('Light'),
  dark('Dark');

  const DioramaMode(this.label);
  final String label;
}

/// Auto → Light → Dark → Auto (concept `DP.A.theme`), persisted in SharedPreferences.
class DioramaModeNotifier extends Notifier<DioramaMode> {
  static const key = 'diorama.mode';

  @override
  DioramaMode build() {
    final s = ref.read(prefsProvider).getString(key);
    return DioramaMode.values.firstWhere((m) => m.name == s, orElse: () => DioramaMode.auto);
  }

  void cycle() {
    state = switch (state) {
      DioramaMode.auto => DioramaMode.light,
      DioramaMode.light => DioramaMode.dark,
      DioramaMode.dark => DioramaMode.auto,
    };
    ref.read(prefsProvider).setString(key, state.name);
  }
}

final dioramaModeProvider = NotifierProvider<DioramaModeNotifier, DioramaMode>(DioramaModeNotifier.new);

// ------------------------------------------------------------------ palette

/// The concept's CSS custom properties (`.diorama` and `.diorama[data-mode="dark"]`).
class Dio {
  const Dio._({
    required this.dark,
    required this.bg,
    required this.card,
    required this.ink,
    required this.mu,
    required this.line,
    required this.soft,
    required this.softsh,
    required this.track,
    required this.hot,
    required this.hotsh,
    required this.lkbg,
    required this.lkfg,
    required this.latfill,
    required this.swring,
    required this.leafink,
    required this.h1,
    required this.h2,
    required this.h4,
    required this.shA,
    required this.shB,
    required this.page0,
    required this.page1,
    required this.scene0,
    required this.scene1,
    required this.offbg,
    required this.offfg,
    required this.keySh,
  });

  final bool dark;
  final Color bg, card, ink, mu, line, soft, softsh, track, hot, hotsh, lkbg, lkfg, latfill, swring, leafink;
  final Color h1, h2, h4, shA, shB, page0, page1, scene0, scene1, offbg, offfg, keySh;

  static const coral = Color(0xFFFF7A59);
  static const coralSh = Color(0xFFD9573A);
  static const mustard = Color(0xFFFFC857);
  static const teal = Color(0xFF2EC4B6);
  static const sky = Color(0xFF7FB7E6);
  static const plum = Color(0xFF8E7CC3);
  static const leaf = Color(0xFF5BBF6A);
  static const claude = Color(0xFFD97757);
  static const amber = Color(0xFFF5A623);
  static const rain = Color(0xFF4E8FD0);
  static const white = Color(0xFFFFFFFF);

  static const light = Dio._(
    dark: false,
    bg: Color(0xFFEEF1F6),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF2B2D42),
    mu: Color(0xFF6C7086),
    line: Color(0xFFE3E7EE),
    soft: Color(0xFFEEF1F6),
    softsh: Color(0xFFD5DBE5),
    track: Color(0xFFEEF1F6),
    hot: Color(0xFFFFFFFF),
    hotsh: Color(0xFFD5DBE5),
    lkbg: Color(0xFFDFF5EA),
    lkfg: Color(0xFF1F7A4D),
    latfill: Color(0xFFDFF5F2),
    swring: Color(0x402B2D42),
    leafink: Color(0xFF3F8E4A),
    h1: Color(0xFFCDEFD2),
    h2: Color(0xFF9BDDA6),
    h4: Color(0xFF3F8E4A),
    shA: Color(0x122B2D42), // rgba(43,45,66,.07)
    shB: Color(0x0D2B2D42), // .05
    page0: Color(0xFFF7F9FC),
    page1: Color(0xFFEEF1F6),
    scene0: Color(0xFFFFFFFF),
    scene1: Color(0xFFF2F5F9),
    offbg: Color(0xFFFFE1D9),
    offfg: Color(0xFFB4381B),
    keySh: Color(0x0F2B2D42), // rgba(43,45,66,.06)
  );

  static const night = Dio._(
    dark: true,
    bg: Color(0xFF121522),
    card: Color(0xFF1E2234),
    ink: Color(0xFFE8EAF3),
    mu: Color(0xFF9AA0B8),
    line: Color(0xFF2C3148),
    soft: Color(0xFF2A2F45),
    softsh: Color(0xFF0D0F18),
    track: Color(0xFF2A2F45),
    hot: Color(0xFF232842),
    hotsh: Color(0xFF0D0F18),
    lkbg: Color(0xFF173A2A),
    lkfg: Color(0xFF7BE0A6),
    latfill: Color(0xFF16393A),
    swring: Color(0x73FFFFFF),
    leafink: Color(0xFF7FD68B),
    h1: Color(0xFF24452D),
    h2: Color(0xFF2F6B3B),
    h4: Color(0xFF9BDDA6),
    shA: Color(0x59000000), // rgba(0,0,0,.35)
    shB: Color(0x4D000000), // .3
    page0: Color(0xFF1B1F33),
    page1: Color(0xFF0F1220),
    scene0: Color(0xFF1A1E30),
    scene1: Color(0xFF121522),
    offbg: Color(0xFF4A2219),
    offfg: Color(0xFFFFB4A0),
    keySh: Color(0x0F2B2D42),
  );

  /// Fredoka text (`font: 500 13.5px/1.3 "Fredoka"`).
  TextStyle t(double size, {FontWeight w = FontWeight.w500, Color? c, double? h, double? ls}) => TextStyle(
        fontFamily: 'Fredoka',
        fontSize: size,
        fontWeight: w,
        color: c ?? ink,
        height: h,
        letterSpacing: ls,
        decoration: TextDecoration.none,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  List<BoxShadow> get shadow => [
        BoxShadow(color: shA, blurRadius: 18, offset: const Offset(0, 6)),
        BoxShadow(color: shB, blurRadius: 2, offset: const Offset(0, 1)),
      ];

  static Dio of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<DioScope>()?.dio ?? light;
  static bool offlineOf(BuildContext c) => c.dependOnInheritedWidgetOfExactType<DioScope>()?.offline ?? false;
}

class DioScope extends InheritedWidget {
  const DioScope({super.key, required this.dio, required this.offline, required super.child});
  final Dio dio;
  final bool offline;
  @override
  bool updateShouldNotify(DioScope old) => old.dio != dio || old.offline != offline;
}

// ------------------------------------------------------------------ skin

class DioramaSkin extends Skin {
  const DioramaSkin();

  /// Shared screens (Settings, setup states) read these; the light variant is the
  /// concept's base palette. The shell and pages use the context-aware [Dio] palette.
  static const t = SkinTokens(
    bg: Color(0xFFEEF1F6),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFEEF1F6),
    line: Color(0xFFE3E7EE),
    text: Color(0xFF2B2D42),
    muted: Color(0xFF6C7086),
    faint: Color(0xFFA3A8BA),
    accent: Dio.coral,
    onAccent: Color(0xFFFFFFFF),
    ok: Color(0xFF3FA552),
    warn: Dio.amber,
    bad: Color(0xFFE2502D),
    claude: Dio.claude,
    green: Dio.leaf,
    cpu: Dio.teal,
    gpu: Dio.plum,
    ram: Dio.sky,
    vram: Dio.coral,
    sky: Dio.sky,
    cloud: Color(0xFF8A93A6),
    body: 'Fredoka',
    display: 'Fredoka',
    radius: 20,
    dark: false,
  );

  @override
  SkinId get id => SkinId.diorama;
  @override
  SkinTokens get tokens => t;

  @override
  ToastStyle get toastStyle =>
      const ToastStyle(bg: Color(0xFF2B2D42), fg: Color(0xFFFFFFFF), font: 'Fredoka', radius: 14, size: 13.5, bottom: 58);

  @override
  Widget page(PageId id) => dioramaPage(id);

  @override
  Widget shell(ShellArgs a) => _DioShell(a: a);

  @override
  Color backdrop(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(dioramaModeProvider);
    final dark = mode == DioramaMode.dark ||
        (mode == DioramaMode.auto && MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    return (dark ? Dio.night : Dio.light).bg;
  }

  /// `.card`. Shared setup states draw [t] text colours inside it, so in dark mode the
  /// card stays pale (the dark ink colour) to keep that text readable.
  @override
  Widget card({required Widget child, EdgeInsets? padding, VoidCallback? onTap, String? label}) => Builder(
        builder: (context) {
          final d = Dio.of(context);
          Widget c = Container(
            padding: padding ?? const EdgeInsets.fromLTRB(14, 11, 14, 11),
            decoration: BoxDecoration(
              color: d.dark ? const Color(0xFFE8EAF3) : d.card,
              borderRadius: BorderRadius.circular(20),
              boxShadow: d.shadow,
            ),
            child: label == null
                ? child
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label, style: Dio.light.t(12, c: Dio.light.mu)),
                    const SizedBox(height: 6),
                    Expanded(child: child),
                  ]),
          );
          if (onTap != null) c = Press(onTap: onTap, scale: .985, child: c);
          return c;
        },
      );
}

/// Page titles from the concept's `PAGES`.
String dioTitle(PageId p) => switch (p) {
      PageId.home => 'My desk',
      PageId.claude => 'Claude usage',
      PageId.hotspot => 'Roof hotspot',
      _ => p.label,
    };

const _moon = '<path d="M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5z"/>';

class _DioShell extends ConsumerWidget {
  const _DioShell({required this.a});
  final ShellArgs a;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(dioramaModeProvider);
    final dark = mode == DioramaMode.dark ||
        (mode == DioramaMode.auto && MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    final d = dark ? Dio.night : Dio.light;
    final st = a.conn.status;
    final offline = !a.conn.live && st != LinkStatus.loading && st != LinkStatus.unpaired;
    final s = connSummary(a.conn);

    final top = Padding(
      padding: const EdgeInsets.fromLTRB(16, 9, 16, 2),
      child: Row(children: [
        Text(dioTitle(a.current), style: d.t(19, w: FontWeight.w600, h: 1.3)),
        const Spacer(),
        Press(
          onTap: () {
            ref.read(dioramaModeProvider.notifier).cycle();
            final m = ref.read(dioramaModeProvider);
            toast(context, m == DioramaMode.auto ? 'Theme follows your phone' : '${m.label} theme');
          },
          child: _chip(
            d,
            bg: d.soft,
            fg: d.ink,
            pad: 11,
            icon: dark
                ? SvgPicture.string(
                    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" '
                    'stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round">$_moon</svg>',
                    width: 15,
                    height: 15,
                    theme: SvgTheme(currentColor: d.ink),
                  )
                : DpIcon('sun', size: 15, color: d.ink, stroke: 1.9),
            label: mode.label,
          ),
        ),
        const SizedBox(width: 10),
        Ticker(
          builder: (context, now) => Text(
            a.settings.clock24 ? clock(now, h24: true) : '${clock(now)} ${ampm(now)}',
            style: d.t(15, w: FontWeight.w600, h: 1.3),
          ),
        ),
        const SizedBox(width: 10),
        Press(
          onTap: a.onStatusTap,
          child: _chip(
            d,
            bg: s.ok ? d.lkbg : d.offbg,
            fg: s.ok ? d.lkfg : d.offfg,
            pad: 10,
            icon: DpIcon(s.icon, size: 13, color: s.ok ? d.lkfg : d.offfg, stroke: 2),
            label: s.text,
          ),
        ),
      ]),
    );

    final nav = Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (final (i, p) in a.pages.indexed) ...[
          if (i > 0) const SizedBox(width: 5),
          _HotKey(page: p, active: p == a.current, d: d, onTap: () => a.onSelect(p)),
        ],
      ]),
    );

    return DioScope(
      dio: d,
      offline: offline,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-.4, -.6),
            radius: .9,
            colors: [d.page0, d.page1],
            transform: const _Ellipse(1.2, .9),
          ),
        ),
        child: DefaultTextStyle(
          style: d.t(13.5, h: 1.3),
          child: Column(children: [
            top,
            Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(14, 4, 14, 6), child: a.child)),
            nav,
          ]),
        ),
      ),
    );
  }

  Widget _chip(Dio d, {required Color bg, required Color fg, required double pad, required Widget icon, required String label}) =>
      AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.fromLTRB(pad, 3, pad, 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          icon,
          const SizedBox(width: 5),
          Text(label, style: d.t(12.5, w: FontWeight.w600, c: fg, h: 1.3)),
        ]),
      );
}

/// CSS `radial-gradient(120% 90% at …)`: an ellipse sized from the box, not a circle.
class _Ellipse extends GradientTransform {
  const _Ellipse(this.rx, this.ry);
  final double rx, ry;
  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    // Flutter's radius is relative to the shortest side; stretch x so it spans rx·width.
    final sx = rx * bounds.width / (ry * bounds.shortestSide) * (bounds.shortestSide / bounds.height);
    final c = Alignment(-.4, -.6).withinRect(bounds);
    return Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..scaleByDouble(sx, 1, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
  }
}

/// Hotbar key (`.hot button`): 40×36, 3px "keycap" shadow, coral when current.
class _HotKey extends StatefulWidget {
  const _HotKey({required this.page, required this.active, required this.d, required this.onTap});
  final PageId page;
  final bool active;
  final Dio d;
  final VoidCallback onTap;
  @override
  State<_HotKey> createState() => _HotKeyState();
}

class _HotKeyState extends State<_HotKey> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.d, on = widget.active;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 40,
        height: 36,
        transform: Matrix4.translationValues(0, _down ? 2 : 0, 0),
        decoration: BoxDecoration(
          color: on ? Dio.coral : d.hot,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: on ? Dio.coralSh : d.hotsh, offset: Offset(0, _down ? 1 : 3))],
        ),
        alignment: Alignment.center,
        child: DpIcon(widget.page.icon, size: 18, color: on ? Dio.white : d.ink),
      ),
    );
  }
}
