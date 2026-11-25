import 'package:flutter/widgets.dart';

import '../../core/pages.dart';
import '../../core/settings.dart';
import '../fmt.dart';
import '../icons.dart';
import '../skin.dart';
import '../widgets/common.dart';
import 'mosaic_pages.dart';

/// Concept 5 — Mosaic: every page owns a colour. Solid tiles on true black, condensed
/// numbers against extra-wide headings (Archivo wdth 62..125). Rail of colour dots.
class MosaicSkin extends Skin {
  const MosaicSkin();

  static const t = SkinTokens(
    bg: Color(0xFF000000),
    surface: Color(0xFF161618),
    surface2: Color(0xFF222225),
    line: Color(0x1AFFFFFF),
    text: Color(0xFFF4F4EF),
    muted: Color(0x9EF4F4EF), // rgba(244,244,239,.62)
    faint: Color(0x66F4F4EF),
    accent: Color(0xFFF2F2EE),
    onAccent: Color(0xFF0D0D0F),
    ok: Color(0xFF3DD68C),
    warn: Color(0xFFFFD449),
    bad: Color(0xFFFF5A5F),
    claude: Color(0xFFFF6A2B),
    green: Color(0xFF3DD68C),
    cpu: Color(0xFF3D5AFE),
    gpu: Color(0xFF8B5CF6),
    ram: Color(0xFFB8A6FF),
    vram: Color(0xFFFF80B5),
    sky: Color(0xFF6CCBFF),
    cloud: Color(0xFF6CCBFF),
    body: 'Archivo',
    display: 'Archivo',
    radius: 22,
  );

  static const dark = Color(0xFF0D0D0F);

  /// `--c-<page>`: the colour each page owns.
  static Color pageColor(PageId p) => switch (p) {
        PageId.home => const Color(0xFFF2F2EE),
        PageId.system => const Color(0xFF3D5AFE),
        PageId.claude => const Color(0xFFFF6A2B),
        PageId.calendar => const Color(0xFFB8A6FF),
        PageId.weather => const Color(0xFF6CCBFF),
        PageId.music => const Color(0xFFFF80B5),
        PageId.hotspot => const Color(0xFFFFD449),
        PageId.timer => const Color(0xFFFF5A5F),
        PageId.slack => const Color(0xFF8F3A91), // Slack aubergine, lifted to read on black
        PageId.github => const Color(0xFF3DD68C),
        PageId.shortcuts => const Color(0xFFD9D9D4),
      };

  /// `--on`: ink on a page-coloured tile (white on the two dark colours).
  static Color onColor(PageId p) =>
      p == PageId.system || p == PageId.slack ? const Color(0xFFFFFFFF) : dark;

  @override
  SkinId get id => SkinId.mosaic;
  @override
  SkinTokens get tokens => t;

  @override
  ToastStyle get toastStyle => const ToastStyle(bg: Color(0xFFF4F4EF), fg: dark, font: 'Archivo', size: 13.5);

  @override
  Widget page(PageId id) => mosaicPage(id);

  @override
  Widget card({required Widget child, EdgeInsets? padding, VoidCallback? onTap, String? label}) {
    Widget c = Container(
      padding: padding ?? const EdgeInsets.fromLTRB(16, 13, 16, 13),
      decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(22)),
      child: label == null
          ? child
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: t.t(12.5, w: FontWeight.w600, c: t.muted)),
              const SizedBox(height: 8),
              Expanded(child: child),
            ]),
    );
    if (onTap != null) c = Press(onTap: onTap, scale: .98, child: c);
    return c;
  }

  @override
  Widget shell(ShellArgs a) => ColoredBox(
        color: t.bg,
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(width: 50, child: _Rail(a)),
          Expanded(child: Padding(padding: const EdgeInsets.all(8), child: a.child)),
        ]),
      );
}

class _Rail extends StatelessWidget {
  const _Rail(this.a);
  final ShellArgs a;

  @override
  Widget build(BuildContext context) {
    const t = MosaicSkin.t;
    final s = connSummary(a.conn);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 10, 0, 8),
      child: Column(children: [
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topCenter,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (final (i, p) in a.pages.indexed) ...[
                  if (i > 0) const SizedBox(height: 5),
                  _Dot(page: p, active: p == a.current, onTap: () => a.onSelect(p)),
                ],
              ]),
            ),
          ),
        ),
        Press(
          onTap: a.onStatusTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Ticker(
                builder: (context, now) => Text(clock(now, h24: a.settings.clock24),
                    style: TextStyle(
                        fontFamily: 'Archivo',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: t.muted,
                        height: 1.3,
                        fontFeatures: const [FontFeature.tabularFigures()])),
              ),
              const SizedBox(height: 4),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: s.ok ? MosaicSkin.pageColor(PageId.github) : MosaicSkin.pageColor(PageId.timer),
                ),
              ),
              const SizedBox(height: 4),
              DpIcon(s.icon, size: 14, color: t.muted),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.page, required this.active, required this.onTap});
  final PageId page;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dc = MosaicSkin.pageColor(page);
    return Press(
      onTap: onTap,
      child: AnimatedScale(
        scale: active ? 1.12 : 1,
        duration: const Duration(milliseconds: 150),
        child: AnimatedOpacity(
          opacity: active ? 1 : .5,
          duration: const Duration(milliseconds: 150),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: dc,
              borderRadius: BorderRadius.circular(active ? 9 : 13),
              boxShadow: active
                  ? [BoxShadow(color: dc, spreadRadius: 3.5), const BoxShadow(color: Color(0xFF000000), spreadRadius: 2)]
                  : null,
            ),
            alignment: Alignment.center,
            child: DpIcon(page.icon, size: 13, stroke: 2.3, color: MosaicSkin.onColor(page)),
          ),
        ),
      ),
    );
  }
}
