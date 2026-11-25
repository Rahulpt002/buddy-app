import 'package:flutter/widgets.dart';

import '../../core/conn/controller.dart';
import '../../core/conn/loop.dart';
import '../../core/pages.dart';
import '../../core/settings.dart';
import '../fmt.dart';
import '../skin.dart';
import '../widgets/common.dart';
import 'cockpit_pages.dart';

/// Concept 6 — Cockpit: a glass-cockpit multi-function display. Bezel soft-keys along the
/// top and bottom edges, dials with caution zones, avionics colour rules
/// (white = scales, green = normal, cyan = selected, magenta = target/next, amber = caution).
class CockpitSkin extends Skin {
  const CockpitSkin();

  static const bg = Color(0xFF03060A);
  static const fr = Color(0xFF263140);
  static const fr2 = Color(0xFF1A222D);
  static const w = Color(0xFFEEF2F5);
  static const gy = Color(0xFF74808E);
  static const g = Color(0xFF3BE27A);
  static const c = Color(0xFF37D6FF);
  static const m = Color(0xFFFF5BE0);
  static const a = Color(0xFFFFB020);
  static const r = Color(0xFFFF4444);

  /// Frame-title plate colour (masks the frame border behind titles).
  static const plate = Color(0xFF050A10);

  static const sans = 'B612';
  static const mono = 'B612 Mono';

  static const t = SkinTokens(
    bg: bg,
    surface: Color(0xFF070D14),
    surface2: Color(0xFF0C1520),
    line: fr,
    text: w,
    muted: gy,
    faint: Color(0xFF4C5866),
    accent: c,
    onAccent: bg,
    ok: g,
    warn: a,
    bad: r,
    claude: m,
    green: g,
    cpu: c,
    gpu: g,
    ram: m,
    vram: a,
    sky: c,
    cloud: w,
    body: sans,
    display: mono,
    radius: 4,
  );

  @override
  SkinId get id => SkinId.cockpit;
  @override
  SkinTokens get tokens => t;

  @override
  ToastStyle get toastStyle => const ToastStyle(bg: Color(0xFF03101A), fg: c, font: sans, radius: 3, size: 11.5);

  @override
  Widget page(PageId id) => cockpitPage(id);

  /// `.fr` frame with its title plate on the border.
  @override
  Widget card({required Widget child, EdgeInsets? padding, VoidCallback? onTap, String? label}) {
    Widget body = Container(
      padding: padding ?? const EdgeInsets.fromLTRB(10, 14, 10, 8),
      decoration: BoxDecoration(border: Border.all(color: fr), borderRadius: BorderRadius.circular(4)),
      child: child,
    );
    if (label != null) {
      body = Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(child: body),
        Positioned(
          top: -7,
          left: 8,
          child: Container(
            color: plate,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Text(label.toUpperCase(),
                style: const TextStyle(
                    fontFamily: sans, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1, color: gy, height: 1.3)),
          ),
        ),
      ]);
    }
    if (onTap != null) body = Press(onTap: onTap, scale: .99, child: body);
    return body;
  }

  @override
  Widget shell(ShellArgs s) {
    final n = s.pages.length;
    final topN = (n + 1) ~/ 2;
    final top = s.pages.take(topN).toList();
    final bot = s.pages.skip(topN).toList();
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          colors: [Color(0xFF08101A), bg],
          radius: 1,
          transform: _Stretch(1190 / 412),
        ),
      ),
      child: Column(children: [
        SizedBox(height: 30, child: _keys(s, top, true)),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0x9903060A),
              border: Border.all(color: fr),
              borderRadius: BorderRadius.circular(6),
            ),
            child: s.child,
          ),
        ),
        SizedBox(height: 30, child: _keys(s, bot, false, stat: true)),
      ]),
    );
  }

  static String _keyLabel(PageId p) => switch (p) {
        PageId.shortcuts => 'KEYS',
        PageId.github => 'GITHUB',
        _ => p.label.toUpperCase(),
      };

  Widget _keys(ShellArgs s, List<PageId> pages, bool top, {bool stat = false}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final (i, p) in pages.indexed) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
                flex: 10,
                child: _SoftKey(label: _keyLabel(p), top: top, on: p == s.current, onTap: () => s.onSelect(p))),
          ],
          if (stat) ...[
            if (pages.isNotEmpty) const SizedBox(width: 4),
            Expanded(flex: 16, child: _Stat(s)),
          ],
        ]),
      );
}

/// Scales a radial gradient horizontally about the centre (CSS `radial-gradient(130% 100%)`).
class _Stretch extends GradientTransform {
  const _Stretch(this.sx);
  final double sx;
  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final cx = bounds.center.dx, cy = bounds.center.dy;
    return Matrix4.identity()
      ..translateByDouble(cx, cy, 0, 1)
      ..scaleByDouble(sx, 1, 1, 1)
      ..translateByDouble(-cx, -cy, 0, 1);
  }
}

/// Bezel soft-key (`.sk`): label with a short tick on the screen edge; the current page
/// gets a cyan box and cyan tick.
class _SoftKey extends StatelessWidget {
  const _SoftKey({required this.label, required this.top, required this.on, required this.onTap});
  final String label;
  final bool top, on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(children: [
          Positioned.fill(
            child: Padding(
              padding: on ? const EdgeInsets.symmetric(vertical: 5) : EdgeInsets.zero,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: on ? CockpitSkin.c : const Color(0x0037D6FF), width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    softWrap: false,
                    style: TextStyle(
                        fontFamily: CockpitSkin.sans,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .88,
                        height: 1,
                        color: on ? CockpitSkin.c : CockpitSkin.w)),
              ),
            ),
          ),
          Positioned(
            top: top ? 0 : null,
            bottom: top ? null : 0,
            left: 0,
            right: 0,
            child: Center(child: Container(width: 16, height: 2, color: on ? CockpitSkin.c : CockpitSkin.gy)),
          ),
        ]),
      );
}

/// Bottom-right status: clock + "LINK WI-FI". Tapping it opens Settings.
class _Stat extends StatelessWidget {
  const _Stat(this.s);
  final ShellArgs s;

  static String link(ConnState c) => switch (c.status) {
        LinkStatus.connected => c.transport == Transport.usb ? 'USB' : 'WI-FI',
        LinkStatus.demo => 'DEMO',
        LinkStatus.connecting || LinkStatus.loading => 'WAIT',
        LinkStatus.unpaired => 'UNPAIRED',
        LinkStatus.authFailed => 'RE-PAIR',
        LinkStatus.protoMismatch => 'UPDATE',
        LinkStatus.offline => 'OFF',
      };

  @override
  Widget build(BuildContext context) {
    final ok = connSummary(s.conn).ok;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: s.onStatusTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Ticker(
            builder: (context, now) => Text(clock(now, h24: s.settings.clock24),
                style: const TextStyle(
                    fontFamily: CockpitSkin.mono, fontSize: 15, fontWeight: FontWeight.w700, color: CockpitSkin.w, height: 1, letterSpacing: 0)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text('LINK ${link(s.conn)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: CockpitSkin.sans,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .88,
                    height: 1,
                    color: ok ? CockpitSkin.g : CockpitSkin.a)),
          ),
        ]),
      ),
    );
  }
}
