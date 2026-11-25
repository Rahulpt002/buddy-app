import 'dart:ui' show PointMode;

import 'package:flutter/widgets.dart';

import '../../core/conn/controller.dart';
import '../../core/conn/loop.dart';
import '../../core/pages.dart';
import '../../core/settings.dart';
import '../fmt.dart';
import '../icons.dart';
import '../skin.dart';
import '../widgets/common.dart';
import 'sketch_pages.dart';

/// Concept 12 — Sketch: a whiteboard you drew yourself. Wobbly double-stroked boxes,
/// hachure fills, sticky notes, hand-drawn arrows; a floating tool island for navigation.
class SketchSkin extends Skin {
  const SketchSkin();

  static const ink = Color(0xFF1E1E1E);
  static const mut = Color(0xFF6B6B6B);
  static const sel = Color(0xFFE0DFFF);
  static const selInk = Color(0xFF4A47B1);

  static const t = SkinTokens(
    bg: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF1F3F5),
    line: Color(0xFFDEE2E6),
    text: ink,
    muted: mut,
    faint: Color(0xFFADB5BD),
    accent: Color(0xFF6741D9),
    onAccent: Color(0xFFFFFFFF),
    ok: Color(0xFF2F9E44),
    warn: Color(0xFFE8590C),
    bad: Color(0xFFE03131),
    claude: Color(0xFF6741D9),
    green: Color(0xFF2F9E44),
    cpu: Color(0xFF1971C2),
    gpu: Color(0xFF2F9E44),
    ram: Color(0xFF6741D9),
    vram: Color(0xFFE8590C),
    sky: Color(0xFF1971C2),
    cloud: Color(0xFF1971C2),
    body: 'Shantell Sans',
    display: 'Shantell Sans',
    radius: 6,
    dark: false,
  );

  @override
  SkinId get id => SkinId.sketch;
  @override
  SkinTokens get tokens => t;

  /// Sticky-note toast.
  @override
  ToastStyle get toastStyle =>
      const ToastStyle(bg: Color(0xFFFFEC99), fg: ink, font: 'Shantell Sans', radius: 8, size: 14);

  @override
  Widget page(PageId id) => sketchPage(id);

  @override
  Widget card({required Widget child, EdgeInsets? padding, VoidCallback? onTap, String? label}) => SketchBox(
    seed: 'card${label ?? ''}',
    padding: padding ?? const EdgeInsets.fromLTRB(14, 12, 14, 12),
    onTap: onTap,
    child: label == null
        ? child
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toLowerCase(), style: t.t(13, c: mut)),
              const SizedBox(height: 6),
              Expanded(child: child),
            ],
          ),
  );

  /// The concept's page titles (lower-cased in the top bar).
  static String title(PageId p) => switch (p) {
    PageId.claude => 'claude usage',
    PageId.hotspot => 'roof hotspot',
    _ => p.label.toLowerCase(),
  };

  @override
  Widget shell(ShellArgs a) => DecoratedBox(
    decoration: const BoxDecoration(color: Color(0xFFFFFFFF)),
    child: CustomPaint(
      painter: const _DotGrid(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title(a.current),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: t
                        .t(22, w: FontWeight.w700, h: 1.2)
                        .copyWith(
                          fontVariations: const [
                            FontVariation('wght', 700),
                            FontVariation('INFM', 100),
                            FontVariation('BNCE', 20),
                          ],
                        ),
                  ),
                ),
                const SizedBox(width: 12),
                _island(a),
                const SizedBox(width: 12),
                Expanded(
                  child: Align(alignment: Alignment.centerRight, child: _status(a)),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 12), child: a.child),
          ),
        ],
      ),
    ),
  );

  Widget _island(ShellArgs a) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFFFF),
      borderRadius: BorderRadius.circular(10),
      boxShadow: const [
        BoxShadow(color: Color(0xFFE9ECEF), spreadRadius: 1),
        BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2)),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, p) in a.pages.indexed) ...[
          if (i > 0) const SizedBox(width: 2),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => a.onSelect(p),
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: p == a.current ? sel : null, borderRadius: BorderRadius.circular(7)),
              child: DpIcon(p.icon, size: 16, stroke: 1.9, color: p == a.current ? selInk : const Color(0xFF343A40)),
            ),
          ),
        ],
      ],
    ),
  );

  static String _short(ConnState c) => switch (c.status) {
    LinkStatus.connected => c.transport == Transport.usb ? 'USB' : 'Wi-Fi',
    LinkStatus.demo => 'Demo',
    _ => connSummary(c).text,
  };

  Widget _status(ShellArgs a) {
    final s = connSummary(a.conn);
    final c = s.ok ? const Color(0xFF2F9E44) : const Color(0xFFE03131);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Ticker(
          builder: (context, now) => Text(
            clock(now, h24: a.settings.clock24),
            style: t.t(15, w: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 10),
        Press(
          onTap: a.onStatusTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DpIcon(s.icon, size: 13, color: c, stroke: 1.9),
                const SizedBox(width: 5),
                Text(
                  _short(a.conn),
                  style: t.t(13, w: FontWeight.w500, c: c),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Whiteboard dot grid: #DEE2E6 dots every 22 px.
class _DotGrid extends CustomPainter {
  const _DotGrid();
  @override
  void paint(Canvas canvas, Size size) {
    final pts = <Offset>[
      for (var y = 11.0; y < size.height; y += 22)
        for (var x = 11.0; x < size.width; x += 22) Offset(x, y),
    ];
    canvas.drawPoints(
      PointMode.points,
      pts,
      Paint()
        ..color = const Color(0xFFDEE2E6)
        ..strokeWidth = 2.1
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_DotGrid o) => false;
}
