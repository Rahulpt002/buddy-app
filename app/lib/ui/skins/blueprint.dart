import 'package:flutter/widgets.dart';

import '../../core/conn/controller.dart';
import '../../core/conn/loop.dart';
import '../../core/pages.dart';
import '../../core/settings.dart';
import '../fmt.dart';
import '../icons.dart';
import '../skin.dart';
import '../widgets/common.dart';
import 'blueprint_pages.dart';

/// Concept 7 — Blueprint: every page is a drawing sheet. Graph-paper blue, white line
/// work, dimension lines for progress, a title block for navigation, red markup for
/// anything that needs attention.
class BlueprintSkin extends Skin {
  const BlueprintSkin();

  static const bp = Color(0xFF0F3A66);
  static const ln = Color(0xFFEAF3FF);
  static const ln2 = Color(0x9EEAF3FF); // rgba(234,243,255,.62)
  static const ln3 = Color(0x4DEAF3FF); // rgba(234,243,255,.3)
  static const cy = Color(0xFFA6DCFF);
  static const red = Color(0xFFFF8E7E);
  static const sans = 'Overpass';
  static const mono = 'Overpass Mono';

  static const t = SkinTokens(
    bg: bp,
    surface: Color(0xFF134476),
    surface2: Color(0xFF1A5088),
    line: ln3,
    text: ln,
    muted: ln2,
    faint: Color(0x73EAF3FF),
    accent: cy,
    onAccent: bp,
    ok: cy,
    warn: Color(0xFFFFD58A),
    bad: red,
    claude: Color(0xFFFFB79A),
    green: Color(0xFFA9EBC4),
    cpu: ln,
    gpu: cy,
    ram: ln,
    vram: cy,
    sky: cy,
    cloud: ln,
    body: sans,
    display: sans,
    radius: 0,
  );

  /// Overpass Mono (dimensions, notes, sheet numbers).
  static TextStyle m(double size, {FontWeight w = FontWeight.w500, Color c = ln, double? h, double? ls}) => TextStyle(
    fontFamily: mono,
    fontSize: size,
    fontWeight: w,
    color: c,
    height: h,
    letterSpacing: ls,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  @override
  SkinId get id => SkinId.blueprint;
  @override
  SkinTokens get tokens => t;

  @override
  ToastStyle get toastStyle => const ToastStyle(bg: bp, fg: ln, font: mono, radius: 0, size: 12);

  @override
  Widget page(PageId id) => blueprintPage(id);

  @override
  Widget card({required Widget child, EdgeInsets? padding, VoidCallback? onTap, String? label}) {
    Widget c = Container(
      padding: padding ?? const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(border: Border.all(color: ln, width: 1.5)),
      child: label == null
          ? child
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BpTitle(label),
                Expanded(child: child),
              ],
            ),
    );
    if (onTap != null) c = Press(onTap: onTap, scale: .985, child: c);
    return c;
  }

  static String linkText(ConnState c) => switch (c.status) {
    LinkStatus.connected => c.transport == Transport.usb ? 'USB' : 'Wi‑Fi',
    LinkStatus.demo => 'Demo',
    LinkStatus.connecting || LinkStatus.loading => 'connecting',
    LinkStatus.unpaired => 'not paired',
    LinkStatus.authFailed => 're-pair',
    LinkStatus.protoMismatch => 'update',
    LinkStatus.offline => 'offline',
  };

  @override
  Widget shell(ShellArgs a) => Stack(
    fit: StackFit.expand,
    children: [
      const Positioned.fill(child: CustomPaint(painter: GraphPaper())),
      Padding(padding: const EdgeInsets.all(9), child: a.settings.navStyle == NavStyle.bottom ? _bottom(a) : _side(a)),
    ],
  );

  static const _edge = BorderSide(color: ln, width: 1.5);

  Widget _sheet(Widget child, {bool right = false, bool bottom = true}) => Container(
    decoration: BoxDecoration(
      border: Border(
        left: _edge,
        top: _edge,
        bottom: bottom ? _edge : BorderSide.none,
        right: right ? _edge : BorderSide.none,
      ),
    ),
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    child: child,
  );

  Widget _side(ShellArgs a) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(child: _sheet(a.child)),
      SizedBox(width: 150, child: _TitleBlock(a)),
    ],
  );

  Widget _bottom(ShellArgs a) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(child: _sheet(_fitHeight(a.child, 367), right: true, bottom: false)),
      SizedBox(height: 46, child: _TitleStrip(a)),
    ],
  );
}

/// Lays [child] out at least [designH] tall and scales it down to fit when the
/// space is shorter (bottom-nav layout), so the dense sheets never overflow.
Widget _fitHeight(Widget child, double designH) => LayoutBuilder(
  builder: (context, box) {
    if (!box.maxHeight.isFinite || box.maxHeight >= designH) return child;
    final k = box.maxHeight / designH;
    return FittedBox(
      fit: BoxFit.contain,
      alignment: Alignment.topLeft,
      child: SizedBox(width: box.maxWidth / k, height: designH, child: child),
    );
  },
);

/// Section title with the drafting double underline (`.dt`).
class BpTitle extends StatelessWidget {
  const BpTitle(this.title, {super.key, this.sub, this.color = BlueprintSkin.ln});
  final String title;
  final String? sub;
  final Color color;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 4.5),
      child: CustomPaint(
        painter: _Underline(color),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: BlueprintSkin.sans,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                  height: 1.35,
                ),
              ),
              if (sub != null && sub!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    sub!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BlueprintSkin.m(10, c: BlueprintSkin.ln2),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _Underline extends CustomPainter {
  const _Underline(this.c);
  final Color c;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = c;
    final y = size.height - 9 + 3; // text bottom + 3 px padding
    canvas.drawRect(Rect.fromLTWH(0, y, size.width, 2.5), p);
    canvas.drawRect(Rect.fromLTWH(0, y + 5, size.width, 1), p);
  }

  @override
  bool shouldRepaint(_Underline o) => o.c != c;
}

/// The graph-paper background: 10 px minor and 50 px major grid over blueprint blue.
class GraphPaper extends CustomPainter {
  const GraphPaper();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = BlueprintSkin.bp);
    final minor = Paint()..color = const Color(0x0BFFFFFF);
    final major = Paint()..color = const Color(0x16FFFFFF);
    for (var x = 0.0; x < size.width; x += 10) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 1, size.height), x % 50 == 0 ? major : minor);
    }
    for (var y = 0.0; y < size.height; y += 10) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), y % 50 == 0 ? major : minor);
    }
  }

  @override
  bool shouldRepaint(GraphPaper o) => false;
}

TextStyle _sans(double size, {FontWeight w = FontWeight.w500, Color c = BlueprintSkin.ln, double? h, double? ls}) =>
    TextStyle(fontFamily: BlueprintSkin.sans, fontSize: size, fontWeight: w, color: c, height: h, letterSpacing: ls);

/// Title block: project name, sheet index (navigation), date/time, link status.
class _TitleBlock extends StatelessWidget {
  const _TitleBlock(this.a);
  final ShellArgs a;

  @override
  Widget build(BuildContext context) {
    const ln = BlueprintSkin.ln, ln2 = BlueprintSkin.ln2, bp = BlueprintSkin.bp;
    const rule = Border(bottom: BorderSide(color: ln));
    final s = connSummary(a.conn);
    final linkC = s.ok ? ln : BlueprintSkin.red;
    return Container(
      decoration: BoxDecoration(border: Border.all(color: ln, width: 1.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(9, 5, 9, 5),
            decoration: const BoxDecoration(border: rule),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DeskPanel', style: _sans(15, w: FontWeight.w800, ls: .15, h: 1.35)),
                Text('Sheet index', style: _sans(10, c: ln2, ls: .2, h: 1.35)),
              ],
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 3),
              decoration: const BoxDecoration(border: rule),
              child: Column(
                children: [
                  for (final (i, p) in a.pages.indexed)
                    Flexible(
                      child: Press(
                        onTap: () => a.onSelect(p),
                        scale: 1,
                        child: Container(
                          height: 24,
                          color: p == a.current ? ln : const Color(0x00000000),
                          padding: const EdgeInsets.symmetric(horizontal: 9),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  p.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                  style: _sans(12, w: FontWeight.w600, c: p == a.current ? bp : ln2),
                                ),
                              ),
                              Text('D-${two(i + 1)}', style: BlueprintSkin.m(10, c: p == a.current ? bp : ln2)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(9, 5, 9, 5),
            decoration: const BoxDecoration(border: rule),
            child: Ticker(
              builder: (context, now) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${weekday3(now)} ${month3(now)} ${now.day}',
                    style: BlueprintSkin.m(9.5, c: ln2, ls: .38, h: 1.3),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    clock(now, h24: a.settings.clock24),
                    style: BlueprintSkin.m(24, w: FontWeight.w700, h: 1),
                  ),
                ],
              ),
            ),
          ),
          Press(
            onTap: a.onStatusTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(9, 4, 9, 4),
              child: Row(
                children: [
                  DpIcon(s.icon, size: 14, color: linkC),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Link: ${BlueprintSkin.linkText(a.conn)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _sans(11.5, w: FontWeight.w600, c: linkC),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom-nav variant: the title block laid out as a strip under the sheet.
class _TitleStrip extends StatelessWidget {
  const _TitleStrip(this.a);
  final ShellArgs a;

  @override
  Widget build(BuildContext context) {
    const ln = BlueprintSkin.ln, ln2 = BlueprintSkin.ln2, bp = BlueprintSkin.bp;
    const side = Border(right: BorderSide(color: ln));
    final s = connSummary(a.conn);
    final linkC = s.ok ? ln : BlueprintSkin.red;
    return Container(
      decoration: BoxDecoration(border: Border.all(color: ln, width: 1.5)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9),
            alignment: Alignment.centerLeft,
            decoration: const BoxDecoration(border: side),
            child: Text('DeskPanel', style: _sans(14, w: FontWeight.w800)),
          ),
          for (final (i, p) in a.pages.indexed)
            Expanded(
              child: Press(
                onTap: () => a.onSelect(p),
                scale: 1,
                child: Container(
                  color: p == a.current ? ln : const Color(0x00000000),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      DpIcon(p.icon, size: 15, color: p == a.current ? bp : ln2),
                      Text('D-${two(i + 1)}', style: BlueprintSkin.m(8.5, c: p == a.current ? bp : ln2)),
                    ],
                  ),
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: ln)),
            ),
            alignment: Alignment.center,
            child: Ticker(
              builder: (context, now) => Text(
                clock(now, h24: a.settings.clock24),
                style: BlueprintSkin.m(18, w: FontWeight.w700, h: 1),
              ),
            ),
          ),
          Press(
            onTap: a.onStatusTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: ln)),
              ),
              alignment: Alignment.center,
              child: DpIcon(s.icon, size: 16, color: linkC),
            ),
          ),
        ],
      ),
    );
  }
}
