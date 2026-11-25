import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/conn/controller.dart';
import '../../core/conn/loop.dart';
import '../../core/pages.dart';
import '../../core/settings.dart';
import '../fmt.dart';
import '../icons.dart';
import '../skin.dart';
import '../widgets/common.dart';
import 'ink_pages.dart';

/// Concept 4 — Ink: an e-paper display. Black ink on grey paper, no colour at all; dot,
/// hatch and checker patterns carry the data. An e-reader text menu on the left. Nothing
/// animates except a brief e-ink "flash" (inversion) when the page changes.
class InkSkin extends Skin {
  const InkSkin();

  /// E-ink swaps pages instantly; the shell's inversion flash is the only transition.
  @override
  Duration get pageTransition => Duration.zero;

  static const paper = Color(0xFFE3E4DF);
  static const ink = Color(0xFF151515);
  static const ink2 = Color(0xFF4B4B47);
  static const ink3 = Color(0xFF8A8A84);

  static const t = SkinTokens(
    bg: paper,
    surface: paper,
    surface2: Color(0xFFD3D4CF),
    line: ink,
    text: ink,
    muted: ink2,
    faint: ink3,
    accent: ink,
    onAccent: paper,
    ok: ink,
    warn: ink2,
    bad: ink,
    claude: ink,
    green: ink,
    cpu: ink,
    gpu: ink,
    ram: ink,
    vram: ink,
    sky: ink,
    cloud: ink,
    body: 'Atkinson Hyperlegible',
    display: 'Bricolage Grotesque',
    radius: 12,
    dark: false,
  );

  @override
  SkinId get id => SkinId.ink;
  @override
  SkinTokens get tokens => t;

  @override
  ToastStyle get toastStyle =>
      const ToastStyle(bg: ink, fg: paper, font: 'Atkinson Hyperlegible', radius: 10, size: 13.5);

  @override
  Widget page(PageId id) => inkPage(id);

  /// `.mod`: 2px ink outline on paper.
  @override
  Widget card({required Widget child, EdgeInsets? padding, VoidCallback? onTap, String? label}) {
    Widget c = Container(
      padding: padding ?? const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(
        color: paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ink, width: 2),
      ),
      child: label == null
          ? child
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: t.t(12, w: FontWeight.w700)),
                const SizedBox(height: 6),
                Expanded(child: child),
              ],
            ),
    );
    if (onTap != null) c = Press(onTap: onTap, scale: 1, child: c);
    return c;
  }

  @override
  Widget shell(ShellArgs a) => _InkShell(a);
}

class _InkShell extends StatefulWidget {
  const _InkShell(this.a);
  final ShellArgs a;
  @override
  State<_InkShell> createState() => _InkShellState();
}

class _InkShellState extends State<_InkShell> {
  static const _t = InkSkin.t;
  bool _flash = false;
  Timer? _flashT;

  @override
  void didUpdateWidget(_InkShell old) {
    super.didUpdateWidget(old);
    if (old.a.current != widget.a.current) {
      // E-ink refresh: invert the content for ~110 ms.
      _flashT?.cancel();
      _flash = true;
      _flashT = Timer(const Duration(milliseconds: 110), () {
        if (mounted) setState(() => _flash = false);
      });
    }
  }

  @override
  void dispose() {
    _flashT?.cancel();
    super.dispose();
  }

  static const _invert = ColorFilter.matrix([
    -1, 0, 0, 0, 255, //
    0, -1, 0, 0, 255, //
    0, 0, -1, 0, 255, //
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final a = widget.a;
    Widget view = Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 12), child: a.child);
    if (_flash) {
      view = ColorFiltered(
        colorFilter: _invert,
        child: ColoredBox(color: InkSkin.paper, child: view),
      );
    }
    return ColoredBox(
      color: InkSkin.paper,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 112,
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 10),
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: InkSkin.ink, width: 2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [for (final p in a.pages) _item(p, p == a.current, () => a.onSelect(p))],
                    ),
                  ),
                ),
                _status(a),
              ],
            ),
          ),
          Expanded(child: view),
        ],
      ),
    );
  }

  Widget _item(PageId p, bool on, VoidCallback onTap) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      height: 27,
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(color: on ? InkSkin.ink : null, borderRadius: BorderRadius.circular(7)),
      child: Text(
        p.label,
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: _t.t(13.5, w: FontWeight.w700, c: on ? InkSkin.paper : InkSkin.ink2),
      ),
    ),
  );

  static String _short(ConnState c) => switch (c.status) {
    LinkStatus.connected => c.transport == Transport.usb ? 'USB' : 'Wi-Fi',
    LinkStatus.demo => 'Demo',
    LinkStatus.connecting || LinkStatus.loading => 'Connecting',
    LinkStatus.unpaired => 'Not paired',
    LinkStatus.authFailed => 'Re-pair',
    LinkStatus.protoMismatch => 'Update',
    LinkStatus.offline => 'Offline',
  };

  Widget _status(ShellArgs a) {
    final s = connSummary(a.conn);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: a.onStatusTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 0, 0),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: InkSkin.ink, width: 2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Ticker(
              builder: (context, now) => Text(
                clock(now, h24: a.settings.clock24),
                maxLines: 1,
                style: _t
                    .d(26, w: FontWeight.w800, ls: -.26)
                    .copyWith(
                      fontVariations: const [
                        FontVariation('wght', 800),
                        FontVariation('wdth', 75),
                        FontVariation('opsz', 48),
                      ],
                    ),
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                DpIcon(s.icon, size: 14, color: InkSkin.ink, stroke: 2.2),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    _short(a.conn),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _t.t(12, w: FontWeight.w700, h: 1.35),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
