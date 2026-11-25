import 'package:flutter/widgets.dart';

import '../../core/pages.dart';
import '../../core/settings.dart';
import '../icons.dart';
import '../skin.dart';
import 'slate_pages.dart';
import '../widgets/common.dart';

/// Concept 1 — Slate: the reference UI, tightened. Icon rail (or bottom bar), cards.
class SlateSkin extends Skin {
  const SlateSkin();

  static const t = SkinTokens(
    bg: Color(0xFF0D1014),
    surface: Color(0xFF151A20),
    surface2: Color(0xFF1D232B),
    line: Color(0xFF232A33),
    text: Color(0xFFE9EDF2),
    muted: Color(0xFF8D97A5),
    faint: Color(0xFF5C6673),
    accent: Color(0xFFF2A93B),
    onAccent: Color(0xFF1B1408),
    ok: Color(0xFF3DD68C),
    warn: Color(0xFFF2A93B),
    bad: Color(0xFFF26060),
    claude: Color(0xFFE5835D),
    green: Color(0xFF3FB950),
    cpu: Color(0xFF4EA1FF),
    gpu: Color(0xFF2CC7B0),
    ram: Color(0xFFA78BFA),
    vram: Color(0xFFF472B6),
    sky: Color(0xFF6CB4FF),
    cloud: Color(0xFFB9C0F2),
    body: 'Inter',
    display: 'Inter',
    radius: 14,
  );
  static const railBg = Color(0xFF0A0D10);
  static const iconIdle = Color(0xFFC7CDD6);

  @override
  SkinId get id => SkinId.slate;
  @override
  SkinTokens get tokens => t;

  @override
  Widget page(PageId id) => slatePage(id);

  @override
  Widget card({required Widget child, EdgeInsets? padding, VoidCallback? onTap, String? label}) {
    Widget c = Container(
      padding: padding ?? const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(t.radius),
        border: Border.all(color: t.line),
      ),
      child: label == null
          ? child
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label.toUpperCase(), style: t.label),
              const SizedBox(height: 8),
              Expanded(child: child),
            ]),
    );
    if (onTap != null) c = Press(onTap: onTap, scale: .985, child: c);
    return c;
  }

  @override
  Widget shell(ShellArgs a) => a.settings.navStyle == NavStyle.bottom ? _bottom(a) : _rail(a);

  Widget _icon(PageId p, bool active, double size) => DpIcon(p.icon,
      size: size,
      color: p == PageId.claude ? t.claude : (active ? const Color(0xFFFFFFFF) : iconIdle));

  Widget _status(ShellArgs a, {required Axis axis}) {
    final s = connSummary(a.conn);
    final c = s.ok ? t.ok : t.bad;
    final kids = [DpIcon('monitor', size: 15, color: c), DpIcon(s.icon, size: 15, color: c)];
    return Press(
      onTap: a.onStatusTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: axis == Axis.vertical
            ? Column(mainAxisSize: MainAxisSize.min, children: [kids[0], const SizedBox(height: 3), kids[1]])
            : Row(mainAxisSize: MainAxisSize.min, children: [kids[0], const SizedBox(width: 6), kids[1]]),
      ),
    );
  }

  Widget _rail(ShellArgs a) => Row(children: [
        Container(
          width: 58,
          decoration: const BoxDecoration(
            color: railBg,
            border: Border(right: BorderSide(color: Color(0xFF232A33))),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(children: [
            for (final p in a.pages)
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 44, minHeight: 26),
                  child: Press(
                    onTap: () => a.onSelect(p),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 40,
                      margin: const EdgeInsets.symmetric(vertical: 1),
                      decoration: BoxDecoration(
                        color: p == a.current ? t.surface2 : const Color(0x00000000),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: _icon(p, p == a.current, 19),
                    ),
                  ),
                ),
              ),
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.only(top: 6),
              width: 36,
              decoration: BoxDecoration(border: Border(top: BorderSide(color: t.line))),
              child: _status(a, axis: Axis.vertical),
            ),
          ]),
        ),
        Expanded(child: Padding(padding: const EdgeInsets.all(12), child: a.child)),
      ]);

  Widget _bottom(ShellArgs a) => Column(children: [
        Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 10), child: a.child)),
        Container(
          height: 56,
          decoration: BoxDecoration(color: railBg, border: Border(top: BorderSide(color: t.line))),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(children: [
            for (final p in a.pages)
              Expanded(
                child: Press(
                  onTap: () => a.onSelect(p),
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 52,
                      height: 42,
                      decoration: BoxDecoration(
                        color: p == a.current ? t.surface2 : const Color(0x00000000),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: _icon(p, p == a.current, 21),
                    ),
                  ),
                ),
              ),
            _status(a, axis: Axis.vertical),
          ]),
        ),
      ]);
}
