import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart' as sched;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/pages.dart';
import '../../core/settings.dart';
import '../fmt.dart';
import '../icons.dart';
import '../pages/kit.dart';
import '../skin.dart';
import '../widgets/aurora.dart' show ArtPalette;
import '../widgets/common.dart';
import 'liquid_kit.dart';
import 'liquid_pages.dart';

/// Concept 16 — Liquid: a Liquid Glass style. Everything floats as translucent glass over a
/// living wallpaper that takes its colour from the page (on Music, from the album art).
/// Specular rims, a floating tab bar with a droplet that slides between tabs, Control
/// Center style shortcuts, and a Clear / Tinted glass switch in the top bar.
class LiquidSkin extends Skin {
  const LiquidSkin();

  static const t = SkinTokens(
    bg: Color(0xFF1B1640), // Home wall base
    surface: Color(0x1AFFFFFF),
    surface2: Color(0x2EFFFFFF),
    line: lqSep,
    text: lqTx,
    muted: lqMu,
    faint: lqFa,
    accent: lqTx,
    onAccent: lqInk,
    ok: lqGreen,
    warn: lqGold,
    bad: lqRed,
    claude: Color(0xFFFF8A5B),
    green: lqMint,
    cpu: lqTx,
    gpu: lqCyan,
    ram: lqTx,
    vram: lqCyan,
    sky: lqCyan,
    cloud: Color(0xB8FFFFFF),
    body: 'Inter',
    display: 'Inter',
    radius: 26,
  );

  /// Wallpaper colours per page (concept `WALL`): three blobs and the base. Hotspot and
  /// Slack aren't in the concept: warm amber (signal and heat) and Slack's aubergine.
  static const walls = <PageId, List<Color>>{
    PageId.home: [Color(0xFF5B6CFF), Color(0xFFFF6FB5), Color(0xFF2FD3C5), Color(0xFF1B1640)],
    PageId.system: [Color(0xFF1C8CA8), Color(0xFF3D63FF), Color(0xFF0F5F6E), Color(0xFF0B1830)],
    PageId.claude: [Color(0xFFFF8A5B), Color(0xFFD9466F), Color(0xFF8E3B8C), Color(0xFF2A1230)],
    PageId.calendar: [Color(0xFF7C5CFF), Color(0xFFFF7AA8), Color(0xFF4B7BFF), Color(0xFF1C1846)],
    PageId.weather: [Color(0xFF6F8DBA), Color(0xFFA9BFDC), Color(0xFF4C6A9A), Color(0xFF22324F)],
    PageId.music: [Color(0xFF6A3FD1), Color(0xFF2A1A6E), Color(0xFFC27BFF), Color(0xFF140C30)],
    PageId.hotspot: [Color(0xFFFFB547), Color(0xFFFF6B3D), Color(0xFFC9822E), Color(0xFF2E1E10)],
    PageId.timer: [Color(0xFFFF5F6D), Color(0xFFFFC371), Color(0xFFC2477F), Color(0xFF2B1426)],
    PageId.slack: [Color(0xFF7A2A7E), Color(0xFFE01E5A), Color(0xFF36C5F0), Color(0xFF1A0B1E)],
    PageId.github: [Color(0xFF2EA043), Color(0xFF1F6FEB), Color(0xFF0E7A62), Color(0xFF0B1A28)],
    PageId.shortcuts: [Color(0xFF4B5170), Color(0xFF6B5BFF), Color(0xFF2E7A8C), Color(0xFF12131C)],
  };

  /// Page titles and subtitles (concept `PAGES` / `SUB`).
  static String title(PageId p) => p == PageId.shortcuts ? 'Controls' : p.label;

  @override
  SkinId get id => SkinId.liquid;
  @override
  SkinTokens get tokens => t;

  @override
  Duration get pageTransition => const Duration(milliseconds: 260);

  @override
  ToastStyle get toastStyle =>
      const ToastStyle(bg: Color(0xE61C1E2E), fg: lqTx, font: 'Inter', size: 13.5, bottom: 72);

  @override
  Widget page(PageId id) => liquidPage(id);

  @override
  Widget card({required Widget child, EdgeInsets? padding, VoidCallback? onTap, String? label}) => LqCard(
        onTap: onTap,
        padding: padding ?? const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: label == null
            ? child
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                lqLab(label),
                const SizedBox(height: 8),
                Expanded(child: child),
              ]),
      );

  @override
  Widget shell(ShellArgs a) => _LiquidShell(a: a);
}

// ------------------------------------------------------------------ shell

class _LiquidShell extends ConsumerWidget {
  const _LiquidShell({required this.a});
  final ShellArgs a;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tinted = ref.watch(lqGlassModeProvider) == LqGlassMode.tinted;
    final offline = !a.conn.live;
    final base = LiquidSkin.walls[a.current] ?? LiquidSkin.walls[PageId.home]!;
    Widget wall(List<Color> c) => LqWall(colors: c, gray: offline, shade: tinted ? .22 : .12);
    return LqGlassTint(
      tinted: tinted,
      child: Stack(fit: StackFit.expand, children: [
        // Music: the wallpaper takes the album art's colours.
        if (a.current == PageId.music)
          _MusicWall(fallback: base, builder: wall)
        else
          wall(base),
        Column(children: [
          _TopBar(a: a),
          Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 72), child: a.child)),
        ]),
        Positioned(left: 0, right: 0, bottom: 10, child: Center(child: _TabBar(a: a))),
      ]),
    );
  }
}

/// Music's wallpaper: three of the art's colours, the first darkened as the base.
class _MusicWall extends ConsumerWidget {
  const _MusicWall({required this.fallback, required this.builder});
  final List<Color> fallback;
  final Widget Function(List<Color>) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = topicData<MediaData>(ref, 'media');
    final art = topicData<MediaArt>(ref, 'media.art');
    final b64 = art != null && art.artId == m?.artId ? art.b64 : null;
    if (b64 == null) return builder(fallback);
    return ArtPalette(
      b64: b64,
      builder: (context, p) {
        HSVColor h(Color c) => HSVColor.fromColor(c);
        final soft = [for (final c in p.take(3)) h(c).withValue(.82).withSaturation(h(c).saturation * .9).toColor()];
        while (soft.length < 3) {
          soft.add(fallback[soft.length]);
        }
        return builder([...soft, h(p.first).withValue(.16).withSaturation(.7).toColor()]);
      },
    );
  }
}

/// Top bar: big title + subtitle, then the Clear / Tinted switch and the clock pill.
class _TopBar extends ConsumerWidget {
  const _TopBar({required this.a});
  final ShellArgs a;

  String _sub(WidgetRef ref, DateTime now) => switch (a.current) {
        PageId.home => longDate(now),
        PageId.system => 'Laptop, live',
        PageId.claude => 'Plan limits',
        PageId.calendar => 'Today and this week',
        PageId.weather => ref.watch(weatherProvider)?.place ?? 'No location set',
        PageId.music => topicData<MediaData>(ref, 'media')?.source ?? 'Your laptop',
        PageId.hotspot => topicData<HotspotData>(ref, 'hotspot')?.name ?? 'Roof phone',
        PageId.timer => 'Focus and breaks',
        PageId.slack => topicData<SlackData>(ref, 'slack')?.team ?? 'Messages',
        PageId.github => 'Last 12 months',
        PageId.shortcuts => 'Your laptop',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tinted = ref.watch(lqGlassModeProvider) == LqGlassMode.tinted;
    final ok = connSummary(a.conn).ok;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 14, 6),
      child: Ticker(
        builder: (context, now) => Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text(LiquidSkin.title(a.current), style: lqT(26, w: FontWeight.w700, ls: -.02)),
              const SizedBox(width: 10),
              Flexible(
                child: Text(_sub(ref, now),
                    style: lqT(12.5, c: lqMu), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          LqPill(
            onTap: () {
              ref.read(lqGlassModeProvider.notifier).toggle();
              toast(context, tinted ? 'Clear glass' : 'Tinted glass, easier to read');
            },
            children: [DpIcon('drop', size: 16, color: lqTx), Text(tinted ? 'Tinted' : 'Clear')],
          ),
          const SizedBox(width: 8),
          LqPill(onTap: a.onStatusTap, children: [lqDot(ok: ok), Text(clock(now, h24: a.settings.clock24))]),
        ]),
      ),
    );
  }
}

/// The floating tab bar: a glass capsule of icons with a glass droplet that springs from
/// the old tab to the new one, and a round connection button beside it.
class _TabBar extends StatelessWidget {
  const _TabBar({required this.a});
  final ShellArgs a;
  static const _w = 42.0, _h = 38.0;

  @override
  Widget build(BuildContext context) {
    final idx = a.pages.indexOf(a.current);
    final s = connSummary(a.conn);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      LqGlass(
        radius: 99,
        padding: const EdgeInsets.all(5),
        child: SizedBox(
          width: a.pages.length * _w,
          height: _h,
          child: Stack(children: [
            if (idx >= 0)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 500),
                curve: const Cubic(.3, 1.45, .45, 1), // the droplet overshoots a little, like water
                left: idx * _w,
                top: 0,
                width: _w,
                height: _h,
                child: const LqGlass(radius: 99, fill: Color(0x42FFFFFF), shadow: false, child: SizedBox.expand()),
              ),
            Row(children: [
              for (final p in a.pages)
                Press(
                  onTap: () => a.onSelect(p),
                  scale: 1.12,
                  child: SizedBox(
                    width: _w,
                    height: _h,
                    child: Center(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: p == a.current ? 1 : .85,
                        child: DpIcon(p.icon, size: 18, color: lqTx, stroke: p == a.current ? 2.1 : 1.8),
                      ),
                    ),
                  ),
                ),
            ]),
          ]),
        ),
      ),
      const SizedBox(width: 8),
      Press(
        onTap: a.onStatusTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: LqGlass(radius: 99, child: Center(child: DpIcon(s.icon, size: 18, color: s.ok ? lqTx : lqRed))),
        ),
      ),
    ]);
  }
}

// ------------------------------------------------------------------ wallpaper

/// The living wallpaper (shaders/liquid_wall.frag): three huge soft blobs drifting slowly
/// over a dark base. Eases to new colours over 1 s when the page (or song) changes;
/// greyed out while the laptop is offline. Updates every frame while on screen.
class LqWall extends StatefulWidget {
  const LqWall({super.key, required this.colors, this.gray = false, this.shade = .12});
  final List<Color> colors; // c1, c2, c3, base
  final bool gray;
  final double shade;
  @override
  State<LqWall> createState() => _LqWallState();
}

Future<ui.FragmentProgram?>? _wallProgram;

class _LqWallState extends State<LqWall> with SingleTickerProviderStateMixin {
  late final sched.Ticker _ticker;
  final _t = ValueNotifier<double>(0);
  ui.FragmentShader? _shader;
  late List<Color> _from = widget.colors, _to = widget.colors;
  double _changedAt = -10;
  late double _gray = widget.gray ? 1 : 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((e) {
      _t.value = e.inMicroseconds / 1e6;
      final target = widget.gray ? 1.0 : 0.0;
      _gray += (target - _gray) * .08;
    })
      ..start();
    (_wallProgram ??= ui.FragmentProgram.fromAsset('shaders/liquid_wall.frag')
            .then<ui.FragmentProgram?>((p) => p)
            .catchError((Object _) => null))
        .then((p) {
      if (p != null && mounted) setState(() => _shader = p.fragmentShader());
    });
  }

  List<Color> _current() {
    final f = Curves.ease.transform(((_t.value - _changedAt) / 1.0).clamp(0.0, 1.0));
    return [for (var i = 0; i < 4; i++) Color.lerp(_from[i], _to[i], f)!];
  }

  @override
  void didUpdateWidget(LqWall old) {
    super.didUpdateWidget(old);
    if (![for (var i = 0; i < 4; i++) old.colors[i] == widget.colors[i]].every((x) => x)) {
      _from = _current();
      _to = widget.colors;
      _changedAt = _t.value;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _t.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(painter: _WallPainter(this), isComplex: true, willChange: true, child: const SizedBox.expand()),
      );
}

class _WallPainter extends CustomPainter {
  _WallPainter(this.s) : super(repaint: s._t);
  final _LqWallState s;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final c = s._current();
    final full = Offset.zero & size;
    final sh = s._shader;
    if (sh != null) {
      var i = 0;
      sh
        ..setFloat(i++, size.width)
        ..setFloat(i++, size.height)
        ..setFloat(i++, s._t.value);
      for (final col in c) {
        sh
          ..setFloat(i++, col.r)
          ..setFloat(i++, col.g)
          ..setFloat(i++, col.b)
          ..setFloat(i++, 1);
      }
      sh
        ..setFloat(i++, s.widget.shade)
        ..setFloat(i++, s._gray);
      canvas.drawRect(full, Paint()..shader = sh);
      return;
    }
    // No shaders here (some tests): three static soft blobs.
    canvas.drawRect(full, Paint()..color = c[3]);
    void blob(Offset center, Size r, Color col) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(1, r.height / r.width);
      canvas.drawCircle(
          Offset.zero,
          r.width * 1.2,
          Paint()
            ..shader = RadialGradient(colors: [col.withValues(alpha: .95), col.withValues(alpha: 0)], stops: const [.45, 1])
                .createShader(Rect.fromCircle(center: Offset.zero, radius: r.width * 1.2)));
      canvas.restore();
    }

    final w = size.width, h = size.height;
    blob(Offset(w * .19, h * .30), Size(w * .31, h * .60), c[0]);
    blob(Offset(w * .865, h * .45), Size(w * .275, h * .55), c[1]);
    blob(Offset(w * .53, h * 1.0), Size(w * .25, h * .45), c[2]);
    canvas.drawRect(full, Paint()..color = Color.fromRGBO(8, 10, 20, s.widget.shade));
  }

  @override
  bool shouldRepaint(_WallPainter old) => true;
}
