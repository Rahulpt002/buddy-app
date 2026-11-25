import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/conn/controller.dart';
import '../../core/pages.dart';
import '../../core/settings.dart';
import '../fmt.dart';
import '../icons.dart';
import '../pages/kit.dart';
import '../skin.dart';
import '../widgets/common.dart';
import 'departures_pages.dart';

/// Concept 10 — Departures: a split-flap board. Every value sits on flaps that flip when
/// it changes; bars are rows of coloured chips; 24-hour times; board yellow headings.
class DeparturesSkin extends Skin {
  const DeparturesSkin();

  static const caseC = Color(0xFF1A1B1D);
  static const flapT = Color(0xFF2E2F33);
  static const flapB = Color(0xFF262729);
  static const wh = Color(0xFFF2EEE5);
  static const yl = Color(0xFFF5C542);
  static const gr = Color(0xFF5BD47E);
  static const rd = Color(0xFFF25A4C);
  static const bl = Color(0xFF5AA8F0);
  static const off = Color(0xFF303135);

  static const t = SkinTokens(
    bg: caseC,
    surface: Color(0xFF232427),
    surface2: flapT,
    line: off,
    text: wh,
    muted: Color(0xFFA8A398),
    faint: Color(0xFF6E6A62),
    accent: yl,
    onAccent: caseC,
    ok: gr,
    warn: yl,
    bad: rd,
    claude: yl,
    green: gr,
    cpu: gr,
    gpu: gr,
    ram: gr,
    vram: gr,
    sky: bl,
    cloud: wh,
    body: 'Oswald',
    display: 'Oswald',
    radius: 6,
  );

  @override
  SkinId get id => SkinId.departures;
  @override
  SkinTokens get tokens => t;

  @override
  ToastStyle get toastStyle => const ToastStyle(bg: yl, fg: caseC, font: 'Oswald', radius: 4, size: 13);

  @override
  Widget page(PageId id) => departuresPage(id);

  @override
  Widget card({required Widget child, EdgeInsets? padding, VoidCallback? onTap, String? label}) {
    Widget c = Container(
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF222326),
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [BoxShadow(color: Color(0xFF0B0B0C), offset: Offset(0, 2))],
      ),
      child: label == null
          ? child
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label.toUpperCase(), style: depText(11, c: yl, ls: 1.54)),
              const SizedBox(height: 8),
              Expanded(child: child),
            ]),
    );
    if (onTap != null) c = Press(onTap: onTap, child: c);
    return c;
  }

  @override
  Widget shell(ShellArgs a) => _Shell(a);
}

/// Oswald text in the board's metrics (CSS line boxes: even leading).
TextStyle depText(double size, {Color? c, FontWeight w = FontWeight.w500, double ls = 0, double h = 1.3}) => TextStyle(
      fontFamily: 'Oswald',
      fontSize: size,
      fontWeight: w,
      fontVariations: [FontVariation('wght', w.value.toDouble())],
      color: c ?? DeparturesSkin.wh,
      letterSpacing: ls,
      height: h,
      leadingDistribution: TextLeadingDistribution.even,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

String _navLabel(PageId p) => p == PageId.shortcuts ? 'Keys' : p.label;

class _Shell extends ConsumerWidget {
  const _Shell(this.a);
  final ShellArgs a;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const y = DeparturesSkin.yl;
    final s = connSummary(a.conn);
    final connLabel = s.ok
        ? (a.conn.status == LinkStatus.demo ? 'Demo' : (s.icon == 'usb' ? 'USB' : 'Wi-Fi'))
        : switch (a.conn.status) {
            LinkStatus.offline => 'Offline',
            LinkStatus.unpaired => 'Not paired',
            LinkStatus.authFailed => 'Re-pair',
            LinkStatus.protoMismatch => 'Update',
            _ => 'Linking',
          };
    final cc = s.ok ? DeparturesSkin.gr : DeparturesSkin.rd;
    final tab = ref.watch(systemTabProvider);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF222326), DeparturesSkin.caseC],
          stops: [0, .9],
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Header: page name on medium flaps, tabs, link status, clock.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(children: [
            DepFlaps(_navLabel(a.current), 10, size: FlapSize.med, color: y, mount: false),
            const Spacer(),
            if (a.current == PageId.system) ...[
              DepBtn(label: 'Laptop', pressed: tab == 0, onTap: () => ref.read(systemTabProvider.notifier).set(0)),
              const SizedBox(width: 6),
              DepBtn(label: 'Internet', pressed: tab == 1, onTap: () => ref.read(systemTabProvider.notifier).set(1)),
              const SizedBox(width: 12),
            ],
            Press(
              onTap: a.onStatusTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cc,
                      boxShadow: [BoxShadow(color: cc, blurRadius: 6)],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(connLabel.toUpperCase(), style: depText(11, c: cc, ls: 1.32)),
                ]),
              ),
            ),
            const SizedBox(width: 12),
            Ticker(
              builder: (context, now) =>
                  DepFlaps('${two(now.hour)}:${two(now.minute)}', 5, size: FlapSize.med, mount: false),
            ),
          ]),
        ),
        Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 6), child: a.child)),
        // Bottom nav: a row of yellow board labels.
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          child: Row(children: [
            for (final (i, p) in a.pages.indexed) ...[
              if (i > 0) const SizedBox(width: 2),
              Expanded(
                child: Press(
                  onTap: () => a.onSelect(p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: p == a.current ? y : const Color(0x00000000),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(_navLabel(p).toUpperCase(),
                          maxLines: 1,
                          style: depText(11.5, c: p == a.current ? DeparturesSkin.caseC : y, ls: .92, h: 1)),
                    ),
                  ),
                ),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ flaps

/// `.fl.sm` / `.fl` / `.fl.med` / `.fl.big` cell metrics.
enum FlapSize {
  sm(12, 19, 14, 1.5, 3),
  md(17, 26, 19, 2, 3),
  med(30, 44, 34, 3, 3),
  big(92, 138, 110, 6, 6);

  const FlapSize(this.w, this.h, this.fs, this.gap, this.radius);
  final double w, h, fs, gap, radius;

  /// Width of [n] cells including gaps.
  double span(int n) => n * w + (n - 1) * gap;
}

/// Delay (ms) before the flaps under it play their entry flip; set per board row so a
/// new page cascades down the board.
class DepRowDelay extends InheritedWidget {
  const DepRowDelay({super.key, required this.ms, required super.child});
  final int ms;
  @override
  bool updateShouldNotify(DepRowDelay old) => old.ms != ms;
}

/// Fits [text] to [n] upper-case cells (truncated, padded left or right).
/// Emoji (and their joiners / skin tones) have no flap: they'd split into broken halves.
final _noFlap = RegExp(r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE0F}\u{200D}]', unicode: true);

String depFit(String text, int n, {bool right = false}) {
  var s = text.toUpperCase();
  if (_noFlap.hasMatch(s)) s = s.replaceAll(_noFlap, '').replaceAll(RegExp(r'  +'), ' ').trim();
  if (s.length > n) s = s.substring(0, n);
  return right ? s.padLeft(n) : s.padRight(n);
}

/// A run of [n] split-flap cells showing [text]. Each cell flips when its character
/// changes (staggered 28 ms per cell, like the concept).
class DepFlaps extends StatelessWidget {
  const DepFlaps(this.text, this.n,
      {super.key, this.color, this.size = FlapSize.md, this.right = false, this.mount = true});
  final String text;
  final int n;
  final Color? color;
  final FlapSize size;
  final bool right;

  /// Play the entry flip when first shown (page change cascade).
  final bool mount;

  @override
  Widget build(BuildContext context) {
    final s = depFit(text, n, right: right);
    final base = mount ? (context.getInheritedWidgetOfExactType<DepRowDelay>()?.ms ?? 0) : -1;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < n; i++) ...[
        if (i > 0) SizedBox(width: size.gap),
        DepCell(s[i], color: color ?? DeparturesSkin.wh, size: size, index: i, mountDelay: base < 0 ? -1 : base + i * 14),
      ],
    ]);
  }
}

/// One flap. Static when idle (no animation listeners); a 340 ms rotateX flip when the
/// character changes.
class DepCell extends StatefulWidget {
  const DepCell(this.ch, {super.key, required this.color, required this.size, this.index = 0, this.mountDelay = -1});
  final String ch;
  final Color color;
  final FlapSize size;
  final int index;

  /// ms before the entry flip; -1 = none.
  final int mountDelay;

  @override
  State<DepCell> createState() => _DepCellState();
}

class _DepCellState extends State<DepCell> with SingleTickerProviderStateMixin {
  AnimationController? _c;
  int _delay = 0;
  static const _flipMs = 340;

  @override
  void initState() {
    super.initState();
    if (widget.mountDelay >= 0 && widget.ch != ' ') _flip(widget.mountDelay);
  }

  @override
  void didUpdateWidget(DepCell old) {
    super.didUpdateWidget(old);
    if (old.ch != widget.ch) _flip(widget.index * 28);
  }

  void _flip(int delay) {
    _delay = delay;
    final c = _c ??= AnimationController(vsync: this);
    c.duration = Duration(milliseconds: _flipMs + delay);
    c.forward(from: 0);
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sz = widget.size;
    final face = RepaintBoundary(
      child: CustomPaint(
        painter: _FlapPainter(sz.radius),
        foregroundPainter: const _MidLine(),
        child: SizedBox(
          width: sz.w,
          height: sz.h,
          child: Center(
            child: Text(widget.ch,
                textAlign: TextAlign.center,
                style: depText(sz.fs, c: widget.color, h: 1).copyWith(letterSpacing: 0)),
          ),
        ),
      ),
    );
    final c = _c;
    if (c == null) return face;
    return AnimatedBuilder(
      animation: c,
      child: face,
      builder: (context, child) {
        if (!c.isAnimating) return child!;
        final ms = c.value * (_flipMs + _delay) - _delay;
        if (ms <= 0) return child!;
        final p = (ms / _flipMs).clamp(0.0, 1.0);
        double ang, dim;
        if (p < .48) {
          final q = Curves.easeInOut.transform(p / .48);
          ang = -88 * q;
          dim = .4 * q;
        } else if (p < .52) {
          ang = 88;
          dim = .4;
        } else {
          final q = Curves.easeInOut.transform((p - .52) / .48);
          ang = 88 * (1 - q);
          dim = .4 * (1 - q);
        }
        // A vertical squash (cos of the fold angle) instead of a 3D perspective turn: same
        // look at flap size, but an affine transform needs no offscreen pass per cell.
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.diagonal3Values(1, math.max(.02, math.cos(ang * math.pi / 180)), 1),
          child: Stack(children: [
            child!,
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color.fromRGBO(0, 0, 0, dim),
                  borderRadius: BorderRadius.circular(sz.radius),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _FlapPainter extends CustomPainter {
  const _FlapPainter(this.r);
  final double r;

  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(r));
    // Drop shadow as a plain offset shape: a blur here costs an offscreen texture per
    // flipping cell on Impeller, which exhausted GPU memory on the A015.
    canvas.drawRRect(rr.shift(const Offset(0, 1)), Paint()..color = const Color(0x99000000));
    canvas.save();
    canvas.clipRRect(rr);
    final h2 = size.height / 2;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, h2), Paint()..color = DeparturesSkin.flapT);
    canvas.drawRect(Rect.fromLTWH(0, h2, size.width, h2), Paint()..color = DeparturesSkin.flapB);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 1), Paint()..color = const Color(0x12FFFFFF));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FlapPainter o) => o.r != r;
}

/// The split line across the middle of a flap, drawn over the glyph.
class _MidLine extends CustomPainter {
  const _MidLine();
  @override
  void paint(Canvas canvas, Size size) => canvas.drawRect(
      Rect.fromLTWH(0, size.height / 2 - .5, size.width, 1), Paint()..color = const Color(0xB3000000));
  @override
  bool shouldRepaint(_MidLine o) => false;
}

/// `.btn`: a flap-faced button; yellow while pressed or selected.
class DepBtn extends StatefulWidget {
  const DepBtn({super.key, this.label, this.icon, this.onTap, this.pressed = false, this.height = 30, this.hPad = 12, this.bg, this.fg});
  final String? label, icon;
  final VoidCallback? onTap;
  final bool pressed;
  final double height, hPad;
  final Color? bg, fg;

  @override
  State<DepBtn> createState() => _DepBtnState();
}

class _DepBtnState extends State<DepBtn> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final on = _down || widget.pressed;
    final fg = on ? DeparturesSkin.caseC : (widget.fg ?? DeparturesSkin.wh);
    final enabled = widget.onTap != null;
    Widget body = AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      height: widget.height,
      padding: EdgeInsets.symmetric(horizontal: widget.hPad),
      transform: Matrix4.translationValues(0, _down ? 1 : 0, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: on ? DeparturesSkin.yl : widget.bg,
        gradient: on || widget.bg != null
            ? null
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [DeparturesSkin.flapT, DeparturesSkin.flapT, DeparturesSkin.flapB, DeparturesSkin.flapB],
                stops: [0, .5, .5, 1],
              ),
        boxShadow: on ? null : const [BoxShadow(color: Color(0xFF0B0B0C), offset: Offset(0, 2))],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
        if (widget.icon != null) DpIcon(widget.icon!, size: 16, color: fg),
        if (widget.icon != null && widget.label != null) const SizedBox(width: 6),
        if (widget.label != null) Text(widget.label!.toUpperCase(), style: depText(13, c: fg, ls: 1.3, h: 1)),
      ]),
    );
    if (!enabled) return Opacity(opacity: .55, child: body);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: body,
    );
  }
}
