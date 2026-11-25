import 'package:flutter/widgets.dart';

import '../../core/conn/controller.dart';
import '../../core/conn/loop.dart';
import '../../core/pages.dart';
import '../../core/settings.dart';
import '../fmt.dart';
import '../icons.dart';
import '../skin.dart';
import 'panel_pages.dart';
import '../widgets/common.dart';

/// Concept 3 — Panel: the phone as bench hardware. Aluminium face, recessed LCD
/// windows, physical keys with LED indicators.
class PanelSkin extends Skin {
  const PanelSkin();

  // Face
  static const face1 = Color(0xFFD9DCDF), face2 = Color(0xFFC5C8CC);
  static const ink = Color(0xFF1C1E21), lab = Color(0xFF50555C);
  // LCD windows
  static const win = Color(0xFF111315), wline = Color(0xFF24282C);
  static const wink = Color(0xFFE7ECE5), wdim = Color(0xFF737B76), off = Color(0xFF252A2E);
  // Signals
  static const sig = Color(0xFFFF5A1F), g = Color(0xFF3BE07A), a = Color(0xFFFFB21E);
  static const r = Color(0xFFFF4433), b = Color(0xFF52B9FF), tq = Color(0xFF3FE0CB);
  static const v = Color(0xFFB992FF), pk = Color(0xFFFF7DB8);

  static const t = SkinTokens(
    bg: face1,
    surface: Color(0xFFE4E6E9),
    surface2: Color(0xFFF1F2F4),
    line: Color(0x22000000),
    text: ink,
    muted: lab,
    faint: Color(0xFF8A9097),
    accent: sig,
    onAccent: Color(0xFFFFFFFF),
    ok: g,
    warn: a,
    bad: r,
    claude: sig,
    green: g,
    cpu: b,
    gpu: tq,
    ram: v,
    vram: pk,
    sky: b,
    cloud: wink,
    body: 'Barlow',
    display: 'Barlow Condensed',
    radius: 8,
    dark: false,
  );

  static String keyLabel(PageId p) => p == PageId.shortcuts ? 'Keys' : p.label;

  @override
  SkinId get id => SkinId.panel;
  @override
  SkinTokens get tokens => t;

  @override
  Widget page(PageId id) => panelPage(id);

  /// Recessed LCD window.
  static Widget window({required Widget child, EdgeInsets? padding}) => Container(
        padding: padding ?? const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: win,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF000000)),
          boxShadow: const [BoxShadow(color: Color(0xCCFFFFFF), offset: Offset(0, 1))],
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: const LinearGradient(
            begin: Alignment(-.4, -1),
            end: Alignment(.4, 1),
            colors: [Color(0x12FFFFFF), Color(0x00FFFFFF)],
            stops: [0, .38],
          ),
        ),
        child: DefaultTextStyle(
          style: t.t(12.5, c: wink),
          child: child,
        ),
      );

  @override
  Widget card({required Widget child, EdgeInsets? padding, VoidCallback? onTap, String? label}) {
    Widget c = label == null
        ? window(child: child, padding: padding)
        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.only(left: 3, bottom: 4),
              child: Text(label, style: t.t(11, w: FontWeight.w600, c: lab)),
            ),
            Expanded(child: window(child: child, padding: padding)),
          ]);
    if (onTap != null) c = Press(onTap: onTap, scale: .99, child: c);
    return c;
  }

  @override
  Widget shell(ShellArgs a) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [face1, face2]),
        ),
        child: Stack(fit: StackFit.expand, children: [
          const CustomPaint(painter: _Brushed()),
          Column(children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0x21000000))),
                boxShadow: [BoxShadow(color: Color(0x8CFFFFFF), offset: Offset(0, 1))],
              ),
              child: Row(children: [
                Expanded(
                  child: Row(children: [
                    for (final p in a.pages) ...[
                      Expanded(child: _Key(page: p, active: p == a.current, onTap: () => a.onSelect(p))),
                      if (p != a.pages.last) const SizedBox(width: 5),
                    ],
                  ]),
                ),
                const SizedBox(width: 10),
                _stat(a),
              ]),
            ),
            Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 12), child: a.child)),
          ]),
        ]),
      );

  Widget _stat(ShellArgs a) {
    final s = connSummary(a.conn);
    final led = s.ok ? g : r;
    final transport = switch (a.conn.status) {
      LinkStatus.connected => a.conn.transport == Transport.usb ? 'USB' : 'Wi-Fi',
      LinkStatus.demo => 'Demo',
      _ => 'Offline',
    };
    return Press(
      onTap: a.onStatusTap,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: win,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(color: Color(0xBFFFFFFF), offset: Offset(0, 1))],
        ),
        child: Row(children: [
          Ticker(
            builder: (_, now) => Text(clock(now, h24: a.settings.clock24),
                style: t.d(24, c: PanelSkin.a).copyWith(shadows: const [
                  Shadow(color: Color(0x59FFB21E), blurRadius: 12),
                ])),
          ),
          const SizedBox(width: 12),
          Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            _ledRow('Laptop', led),
            const SizedBox(height: 3),
            _ledRow(transport, led),
          ]),
        ]),
      ),
    );
  }

  static Widget led(Color c, {double size = 6}) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            shape: BoxShape.circle, color: c, boxShadow: [BoxShadow(color: c, blurRadius: 6)]),
      );

  Widget _ledRow(String text, Color c) => Row(children: [
        led(c),
        const SizedBox(width: 5),
        Text(text, style: t.t(10, w: FontWeight.w600, c: wdim, h: 1)),
      ]);
}

class _Key extends StatefulWidget {
  const _Key({required this.page, required this.active, required this.onTap});
  final PageId page;
  final bool active;
  final VoidCallback onTap;
  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final pressed = widget.active || _down;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        height: 42,
        transform: Matrix4.translationValues(0, pressed ? 2 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: pressed
                ? const [Color(0xFFD6D9DC), Color(0xFFE3E5E8)]
                : const [Color(0xFFF1F2F4), Color(0xFFDCDFE2)],
          ),
          border: pressed ? const Border(top: BorderSide(color: Color(0x33000000), width: 1.5)) : null,
          boxShadow: pressed
              ? const []
              : const [
                  BoxShadow(color: Color(0xFF9DA2A8), offset: Offset(0, 2)),
                  BoxShadow(color: Color(0x2E000000), offset: Offset(0, 3), blurRadius: 5),
                ],
        ),
        child: Stack(children: [
          Positioned(
            top: 5,
            right: 6,
            child: widget.active
                ? PanelSkin.led(PanelSkin.sig, size: 5)
                : Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFB3B7BC)),
                  ),
          ),
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DpIcon(widget.page.icon, size: 16, stroke: 1.7, color: PanelSkin.ink),
              const SizedBox(height: 2),
              Text(PanelSkin.keyLabel(widget.page),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: PanelSkin.t.t(10,
                      w: FontWeight.w600, c: widget.active ? PanelSkin.ink : PanelSkin.lab, h: 1)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Subtle brushed-aluminium striping.
class _Brushed extends CustomPainter {
  const _Brushed();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0x09FFFFFF);
    for (double x = 0; x < size.width; x += 3) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 1, size.height), p);
    }
    final glow = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0, -1.2),
        radius: 1.0,
        colors: [Color(0x40FFFFFF), Color(0x00FFFFFF)],
        stops: [0, .6],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, glow);
  }

  @override
  bool shouldRepaint(_Brushed old) => false;
}
