import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/conn/controller.dart';
import '../../core/mouse_layout.dart';
import '../../core/settings.dart';
import '../icons.dart';
import '../skin.dart';
import '../widgets/common.dart';

Route<void> mouseArrangeRoute() => MaterialPageRoute(builder: (_) => const MouseArrangeScreen());

/// "Phone position": the Mac's displays drawn to scale (like macOS Displays → Arrange) with
/// this phone next to them. Drag the phone to where it really sits; it snaps to the nearest
/// screen edge and the laptop mouse crosses where they touch.
class MouseArrangeScreen extends ConsumerStatefulWidget {
  const MouseArrangeScreen({super.key});
  @override
  ConsumerState<MouseArrangeScreen> createState() => _MouseArrangeScreenState();
}

class _MouseArrangeScreenState extends ConsumerState<MouseArrangeScreen> {
  List<MacDisplay>? _displays;
  String? _error;
  Rect? _phone; // global Mac points
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    final r = await ref.read(agentProvider.notifier).request('mouse.displays');
    if (!mounted) return;
    if (!r.ok) {
      setState(() => _error = r.message ?? 'The laptop did not answer.');
      return;
    }
    final ds = [for (final j in (r.result['displays'] as List? ?? const [])) MacDisplay(j as Map<String, dynamic>)];
    if (ds.isEmpty) {
      setState(() => _error = 'The laptop reported no displays.');
      return;
    }
    final main = ds.firstWhere((d) => d.main, orElse: () => ds.first);
    final size = phoneSizeInPoints(phoneScreenSize() ?? const Size(780, 360), main);
    final saved = ref.read(settingsProvider).mouseRect;
    // Keep a saved spot (resized to scale); otherwise start centred under the main screen.
    final start = saved == null
        ? Rect.fromLTWH(main.rect.center.dx - size.width / 2, main.rect.bottom, size.width, size.height)
        : Rect.fromCenter(
            center: Offset(saved.x + saved.w / 2, saved.y + saved.h / 2), width: size.width, height: size.height);
    setState(() {
      _displays = ds;
      _phone = snapPhone([for (final d in ds) d.rect], start);
    });
    if (saved == null) _save();
  }

  void _save() {
    final p = _phone;
    if (p == null) return;
    ref.read(settingsProvider.notifier).update(
        (s) => s.copyWith(mouseOn: true, mouseRect: PhoneRect(p.left, p.top, p.width, p.height)));
  }

  void _drop() {
    final ds = _displays, p = _phone;
    if (ds == null || p == null) return;
    setState(() {
      _dragging = false;
      _phone = snapPhone([for (final d in ds) d.rect], p);
    });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final s = ref.watch(settingsProvider);
    final ds = _displays, p = _phone;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Press(
                onTap: () => Navigator.of(context).pop(),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.arrow_back, color: t.text, size: 22),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Phone position', style: t.t(20, w: FontWeight.w700)),
                  Text(
                    ds == null || p == null
                        ? 'Drag the phone to where it sits next to your screen'
                        : '${describePlacement([for (final d in ds) d.rect], p)}. '
                            'Drag it to where it really sits; the mouse crosses where they touch.',
                    style: t.t(12.5, c: t.muted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ]),
              ),
              const SizedBox(width: 12),
              Text('Mouse sharing', style: t.t(13, c: t.muted)),
              const SizedBox(width: 6),
              Switch(
                value: s.mouseOn,
                onChanged: (v) => ref.read(settingsProvider.notifier).update((x) => x.copyWith(mouseOn: v)),
              ),
            ]),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: t.line),
                ),
                child: _error != null
                    ? _message(t, _error!, retry: true)
                    : ds == null || p == null
                        ? _message(t, 'Asking the laptop for its screens…')
                        : LayoutBuilder(builder: (context, c) => _canvas(t, c.biggest, ds, p)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _message(SkinTokens t, String text, {bool retry = false}) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(text, textAlign: TextAlign.center, style: t.t(14, c: t.muted)),
          ),
          if (retry) ...[
            const SizedBox(height: 12),
            Press(
              onTap: _load,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: t.accent, borderRadius: BorderRadius.circular(99)),
                child: Text('Try again', style: t.t(13, w: FontWeight.w600, c: t.onAccent)),
              ),
            ),
          ],
        ]),
      );

  Widget _canvas(SkinTokens t, Size box, List<MacDisplay> ds, Rect phone) {
    // World = all displays plus room around them to drag the phone.
    final screens = boundsOf([for (final d in ds) d.rect]);
    // Just enough room to put the phone on any side (and to see where it is now).
    final world = Rect.fromLTRB(screens.left - phone.width * 1.08, screens.top - phone.height * 1.15,
            screens.right + phone.width * 1.08, screens.bottom + phone.height * 1.15)
        .expandToInclude(phone.inflate(8));
    final k = min((box.width - 24) / world.width, (box.height - 24) / world.height);
    final origin = Offset((box.width - world.width * k) / 2, (box.height - world.height * k) / 2);
    Rect toCanvas(Rect r) => Rect.fromLTWH(
        origin.dx + (r.left - world.left) * k, origin.dy + (r.top - world.top) * k, r.width * k, r.height * k);
    Offset toWorld(Offset o) => Offset(world.left + (o.dx - origin.dx) / k, world.top + (o.dy - origin.dy) / k);

    final pc = toCanvas(phone);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Tap anywhere to put the phone there.
      onTapUp: (d) {
        setState(() => _phone = Rect.fromCenter(center: toWorld(d.localPosition), width: phone.width, height: phone.height));
        _drop();
      },
      child: Stack(children: [
        for (final d in ds) _screen(t, toCanvas(d.rect), d),
        Positioned.fromRect(
          rect: pc,
          child: GestureDetector(
            onTap: () {}, // a tap on the phone itself shouldn't move it
            onPanStart: (_) => setState(() => _dragging = true),
            onPanUpdate: (d) => setState(() => _phone = phone.shift(d.delta / k)),
            onPanEnd: (_) => _drop(),
            child: _phoneTile(t, pc.size),
          ),
        ),
      ]),
    );
  }

  Widget _screen(SkinTokens t, Rect r, MacDisplay d) => Positioned.fromRect(
        rect: r,
        child: Container(
          decoration: BoxDecoration(
            color: t.surface2,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: t.muted.withValues(alpha: .6), width: 2),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DpIcon('monitor', size: 26, color: t.muted),
                const SizedBox(height: 4),
                Text(d.builtin ? 'Built-in screen' : (d.main ? 'Main screen' : 'Screen'),
                    style: t.t(14, w: FontWeight.w600)),
                Text('${d.rect.width.round()} × ${d.rect.height.round()}', style: t.t(12, c: t.muted)),
              ]),
            ),
          ),
        ),
      );

  Widget _phoneTile(SkinTokens t, Size size) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: t.accent.withValues(alpha: _dragging ? .55 : .85),
          borderRadius: BorderRadius.circular(min(size.height, size.width) * .12),
          border: Border.all(color: t.accent, width: 2),
          boxShadow: _dragging ? [BoxShadow(color: t.accent.withValues(alpha: .4), blurRadius: 12)] : null,
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              DpIcon('hotspot', size: 18, color: t.onAccent),
              const SizedBox(width: 6),
              Text('This phone', style: t.t(13, w: FontWeight.w700, c: t.onAccent)),
            ]),
          ),
        ),
      );
}
