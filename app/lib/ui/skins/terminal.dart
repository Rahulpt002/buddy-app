import 'package:flutter/widgets.dart';

import '../../core/conn/controller.dart';
import '../../core/conn/loop.dart';
import '../../core/pages.dart';
import '../../core/settings.dart';
import '../fmt.dart';
import '../skin.dart';
import '../widgets/common.dart';
import 'terminal_pages.dart';

/// Concept 8 — Terminal: a tmux session on the desk. btop panes, ping output, a
/// ccusage-style table, wttr.in weather, cmus. Pages are tmux windows along the bottom.
/// One monospace face (JetBrains Mono), warm terminal palette.
class TerminalSkin extends Skin {
  const TerminalSkin();

  static const bg = Color(0xFF1F1B16);
  static const bg2 = Color(0xFF2B251E);
  static const fg = Color(0xFFEADFCB);
  static const dim = Color(0xFF8C8170);
  static const box = Color(0xFF4D4437);
  static const or = Color(0xFFF0A04B);
  static const yl = Color(0xFFE8C86A);
  static const gr = Color(0xFF9CC27A);
  static const tl = Color(0xFF6FC1B1);
  static const bl = Color(0xFF82A9DB);
  static const rs = Color(0xFFE57A86);
  static const pu = Color(0xFFBC9EDB);

  static const font = 'JetBrains Mono';

  /// Monospace without programming ligatures ("->", "==" must stay as typed).
  static const features = [
    FontFeature.disable('liga'),
    FontFeature.disable('calt'),
    FontFeature.tabularFigures(),
  ];

  static const t = SkinTokens(
    bg: bg,
    surface: bg2,
    surface2: Color(0xFF362F26),
    line: box,
    text: fg,
    muted: dim,
    faint: Color(0xFF6A6052),
    accent: or,
    onAccent: bg,
    ok: gr,
    warn: yl,
    bad: rs,
    claude: or,
    green: gr,
    cpu: gr,
    gpu: yl,
    ram: pu,
    vram: pu,
    sky: bl,
    cloud: fg,
    body: font,
    display: font,
    radius: 7,
  );

  static TextStyle s({double size = 12.5, Color c = fg, bool b = false, double h = 1.5}) => TextStyle(
      fontFamily: font,
      fontSize: size,
      fontWeight: b ? FontWeight.w700 : FontWeight.w400,
      color: c,
      height: h,
      letterSpacing: 0,
      wordSpacing: 0,
      fontFeatures: features);

  @override
  SkinId get id => SkinId.terminal;
  @override
  SkinTokens get tokens => t;

  @override
  ToastStyle get toastStyle => const ToastStyle(bg: yl, fg: bg, font: font, radius: 3, size: 12.5);

  @override
  Widget page(PageId id) => terminalPage(id);

  /// A btop-style pane (rounded box, title cut into the top border).
  @override
  Widget card({required Widget child, EdgeInsets? padding, VoidCallback? onTap, String? label}) {
    Widget c = Stack(clipBehavior: Clip.none, fit: StackFit.passthrough, children: [
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(border: Border.all(color: box), borderRadius: BorderRadius.circular(7)),
        ),
      ),
      Padding(padding: padding ?? const EdgeInsets.fromLTRB(11, 11, 11, 7), child: child),
      if (label != null)
        Positioned(
          top: -10,
          left: 10,
          child: Container(
            color: bg,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Text(label.toLowerCase(), style: s(c: or, b: true)),
          ),
        ),
    ]);
    if (onTap != null) c = Press(onTap: onTap, scale: .99, child: c);
    return c;
  }

  @override
  Widget shell(ShellArgs a) => ColoredBox(
        color: bg,
        child: Column(children: [
          Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(10, 8, 10, 6), child: a.child)),
          SizedBox(height: 22, child: _Tmux(a)),
        ]),
      );
}

/// tmux status line: session, window list (tap to switch), link state and clock.
class _Tmux extends StatelessWidget {
  const _Tmux(this.a);
  final ShellArgs a;

  static TextStyle _st({Color c = TerminalSkin.dim, bool b = false}) =>
      TerminalSkin.s(size: 11.5, c: c, b: b, h: 1.2);

  static String name(PageId p) => p == PageId.shortcuts ? 'keys' : p.name;

  static String link(ConnState c) => switch (c.status) {
        LinkStatus.connected => c.transport == Transport.usb ? 'USB' : 'Wi-Fi',
        LinkStatus.demo => 'demo',
        LinkStatus.connecting || LinkStatus.loading => 'connecting',
        LinkStatus.unpaired => 'unpaired',
        LinkStatus.authFailed => 're-pair',
        LinkStatus.protoMismatch => 'update',
        LinkStatus.offline => 'offline',
      };

  @override
  Widget build(BuildContext context) {
    final ok = connSummary(a.conn).ok;
    return ColoredBox(
      color: TerminalSkin.bg2,
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          color: TerminalSkin.gr,
          padding: const EdgeInsets.symmetric(horizontal: 7),
          alignment: Alignment.center,
          child: Text('desk', style: _st(c: TerminalSkin.bg, b: true)),
        ),
        Expanded(
          child: ClipRect(
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final (i, p) in a.pages.indexed)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => a.onSelect(p),
                    child: Container(
                      color: p == a.current ? TerminalSkin.or : null,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      child: Text('$i:${name(p)}${p == a.current ? '*' : ''}',
                          softWrap: false,
                          style: p == a.current ? _st(c: TerminalSkin.bg, b: true) : _st()),
                    ),
                  ),
              ]),
            ),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: a.onStatusTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9),
            alignment: Alignment.center,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              ok
                  ? Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(color: TerminalSkin.gr, shape: BoxShape.circle),
                    )
                  : Text('x', style: _st(c: TerminalSkin.rs)),
              const SizedBox(width: 6),
              Text(link(a.conn), style: _st(c: ok ? TerminalSkin.gr : TerminalSkin.rs)),
            ]),
          ),
        ),
        Container(
          color: TerminalSkin.bl,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          alignment: Alignment.center,
          child: Ticker(
            builder: (context, now) =>
                Text(clock(now, h24: a.settings.clock24), style: _st(c: TerminalSkin.bg, b: true)),
          ),
        ),
      ]),
    );
  }
}
