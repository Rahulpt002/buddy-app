// Concept 8 — Terminal pages. Sizes follow deskpanel-concept-8-terminal.html (CSS px = logical px).
// Everything is JetBrains Mono 12.5px / 1.5 (7.5 × 18.75 px cells); text that the concept lays
// out on the character grid (meters, ping lines, agenda, progress bar) is built from padded
// strings so it stays on that grid.
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/conn/controller.dart';
import '../../core/pages.dart';
import '../../core/settings.dart';
import '../fmt.dart';
import '../pages/kit.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import 'terminal.dart';

const _bg = TerminalSkin.bg;
const _bg2 = TerminalSkin.bg2;
const _fg = TerminalSkin.fg;
const _dim = TerminalSkin.dim;
const _box = TerminalSkin.box;
const _or = TerminalSkin.or;
const _yl = TerminalSkin.yl;
const _gr = TerminalSkin.gr;
const _tl = TerminalSkin.tl;
const _bl = TerminalSkin.bl;
const _rs = TerminalSkin.rs;
const _pu = TerminalSkin.pu;

const _lh = 18.75; // 12.5px × 1.5
const _rowGap = 12.0, _colGap = 10.0;

Widget terminalPage(PageId id) => switch (id) {
  PageId.home => const _Home(),
  PageId.system => const _System(),
  PageId.claude => const _Claude(),
  PageId.calendar => const _Calendar(),
  PageId.weather => const _Weather(),
  PageId.music => const _Music(),
  PageId.hotspot => const _Hotspot(),
  PageId.timer => const _Timer(),
  PageId.slack => const _Slack(),
  PageId.github => const _Github(),
  PageId.shortcuts => const _Shortcuts(),
};

// ------------------------------------------------------------------ type

TextStyle _ts({double size = 12.5, Color c = _fg, bool b = false, double h = 1.5}) =>
    TerminalSkin.s(size: size, c: c, b: b, h: h);

TextSpan _s(String t, [Color c = _fg, bool b = false, double? size]) => TextSpan(
  text: t,
  style: _ts(c: c, b: b, size: size ?? 12.5),
);

/// One terminal line (no wrap; ellipsis like `.ln`).
Widget _ln(List<InlineSpan> spans, {TextAlign align = TextAlign.left, TextOverflow overflow = TextOverflow.ellipsis}) =>
    Text.rich(
      TextSpan(children: spans, style: _ts()),
      maxLines: 1,
      softWrap: false,
      overflow: overflow,
      textAlign: align,
    );

Widget _t(String s, {Color c = _fg, bool b = false, double size = 12.5}) => Text(
  s,
  style: _ts(c: c, b: b, size: size),
  maxLines: 1,
  softWrap: false,
  overflow: TextOverflow.ellipsis,
);

final _cwCache = <double, double>{};

/// Advance width of one character cell.
double _cw([double size = 12.5]) => _cwCache.putIfAbsent(size, () {
  final tp = TextPainter(
    text: TextSpan(
      text: '0' * 20,
      style: _ts(size: size),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  return tp.width / 20;
});

/// Largest n (≤ [n0]) whose spans fit in [maxW] on one line.
int _fitN(double maxW, int n0, List<InlineSpan> Function(int n) build, {int min = 6}) {
  var n = n0;
  while (n > min) {
    final tp = TextPainter(
      text: TextSpan(children: build(n), style: _ts()),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    if (tp.width <= maxW + .5) break;
    n--;
  }
  return n;
}

String _inText(CalEvent e, DateTime now) {
  if (!e.start.isAfter(now)) return 'now';
  final d = e.start.difference(now);
  return d.inMinutes < 1 ? 'starting now' : 'in ${dur(d)}';
}

/// Lower-cases the first letter ("Not set up" → "not set up").
String _lc(String s) => s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

String _ms(Duration d) {
  final s = d.inSeconds;
  return s >= 3600 ? '${s ~/ 3600}:${two(s ~/ 60 % 60)}:${two(s % 60)}' : '${s ~/ 60}:${two(s % 60)}';
}

void _text(Canvas cv, String s, TextStyle st, double x, double baseline) {
  final tp = TextPainter(
    text: TextSpan(text: s, style: st),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(cv, Offset(x, baseline - tp.computeDistanceToActualBaseline(TextBaseline.alphabetic)));
}

// ------------------------------------------------------------------ chrome

/// Blinking block cursor after the prompt.
class _Cursor extends StatefulWidget {
  const _Cursor();
  @override
  State<_Cursor> createState() => _CursorState();
}

class _CursorState extends State<_Cursor> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) => Opacity(
      opacity: _c.value < .5 ? 0 : 1,
      child: Container(width: 7.5, height: 13, margin: const EdgeInsets.only(left: 4, top: 2), color: _fg),
    ),
  );
}

/// `~ $ cmd█` prompt line with optional right-hand controls, then the page body.
Widget _page(String cmd, Widget body, {Widget? right}) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    SizedBox(
      height: 22.75,
      child: Row(
        children: [
          Flexible(child: _ln([_s('~', _gr, true), _s(' '), _s(r'$', _bl), _s(' $cmd', _dim)])),
          const _Cursor(),
          const Spacer(),
          ?right,
        ],
      ),
    ),
    const SizedBox(height: 8),
    Expanded(child: body),
  ],
);

/// btop pane: rounded box, numbered title cut into the top border, optional right title.
Widget _pane(
  String title,
  Widget child, {
  int? n,
  Color c = _or,
  String? tr,
  EdgeInsets pad = const EdgeInsets.fromLTRB(10, 10, 10, 6),
}) {
  Widget plate(Widget w) => Container(color: _bg, padding: const EdgeInsets.symmetric(horizontal: 5), child: w);
  return Stack(
    clipBehavior: Clip.none,
    fit: StackFit.passthrough,
    children: [
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: _box),
            borderRadius: BorderRadius.circular(7),
          ),
        ),
      ),
      Padding(padding: pad + const EdgeInsets.all(1), child: child),
      Positioned(
        top: -10,
        left: 10,
        child: plate(
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (n != null)
                Padding(
                  padding: const EdgeInsets.only(top: 1, right: 1),
                  child: Text('$n', style: _ts(size: 8.75, c: _dim, h: 1.2)),
                ),
              Text(title, style: _ts(c: c, b: true)),
            ],
          ),
        ),
      ),
      if (tr != null)
        Positioned(
          top: -10,
          right: 10,
          child: plate(Text(tr, style: _ts(c: _dim))),
        ),
    ],
  );
}

/// `[ label ]` bracket button; orange fill while pressed or when [on].
class _Btn extends StatefulWidget {
  const _Btn(this.label, {this.onTap, this.hot = false, this.on = false});
  final String label;
  final VoidCallback? onTap;
  final bool hot, on;
  @override
  State<_Btn> createState() => _BtnState();
}

class _BtnState extends State<_Btn> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final w = widget;
    final filled = w.on || _down;
    final edge = filled ? _bg : _dim;
    final body = Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      decoration: BoxDecoration(color: filled ? _or : null, borderRadius: BorderRadius.circular(3)),
      child: _ln([
        _s('[ ', edge),
        _s(w.label, filled ? _bg : (w.hot ? _or : _fg), w.hot || filled),
        _s(' ]', edge),
      ], overflow: TextOverflow.clip),
    );
    if (w.onTap == null) return Opacity(opacity: .55, child: body);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: w.onTap,
      child: body,
    );
  }
}

/// Key/value grid (`.kv`): bold coloured keys in an auto-width column, 12px gap.
Widget _kv(List<(String, List<InlineSpan>, VoidCallback?)> rows, {Color kc = _or}) {
  final kw = rows.map((r) => r.$1.length).fold(0, math.max) * _cw() + 12;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final (k, v, tap) in rows)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: tap,
          child: Row(
            children: [
              SizedBox(
                width: kw,
                child: _t(k, c: kc, b: true),
              ),
              Expanded(child: _ln(v)),
            ],
          ),
        ),
    ],
  );
}

// ------------------------------------------------------------------ meters & graphs

/// htop-style meter `label [|||||     txt]`, sized to the width in characters.
class _Meter extends StatelessWidget {
  const _Meter(this.label, this.frac, this.txt, {this.color});
  final String label, txt;
  final double frac;

  /// Fixed bar colour; null = heat (green → yellow → rose along the bar).
  final Color? color;

  List<InlineSpan> _spans(int n) {
    final fill = (frac.clamp(0.0, 1.0) * n).round();
    final spans = <InlineSpan>[if (label.isNotEmpty) _s('$label ', _or, true), _s('[', _dim)];
    var run = StringBuffer();
    Color? runC;
    void flush() {
      if (run.isNotEmpty) spans.add(_s(run.toString(), runC ?? _fg));
      run = StringBuffer();
    }

    for (var i = 0; i < n; i++) {
      String ch;
      Color col;
      if (i >= n - txt.length) {
        ch = txt[i - (n - txt.length)];
        col = _fg;
      } else if (i < fill) {
        final f = i / n;
        ch = '|';
        col = color ?? (f < .5 ? _gr : (f < .8 ? _yl : _rs));
      } else {
        ch = ' ';
        col = runC ?? _fg;
      }
      if (col != runC) {
        flush();
        runC = col;
      }
      run.write(ch);
    }
    flush();
    spans.add(_s(']', _dim));
    return spans;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final cols = (c.maxWidth / _cw()).floor();
      final n = _fitN(c.maxWidth, math.max(6, cols - label.length - 3), _spans);
      return _ln(_spans(n), overflow: TextOverflow.clip);
    },
  );
}

/// btop-like block graph: one column per character cell, eighth-block heights, coloured
/// by row band; anchored bottom-left.
class _Blocks extends StatelessWidget {
  const _Blocks(this.vals, {this.lo = 0, required this.hi, this.palette = const [_gr, _yl, _rs]});
  final List<double?> vals;
  final double lo, hi;
  final List<Color> palette;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _BlocksPainter(this, _cw()), size: Size.infinite);
}

class _BlocksPainter extends CustomPainter {
  _BlocksPainter(this.b, this.cw);
  final _Blocks b;
  final double cw;

  @override
  void paint(Canvas canvas, Size size) {
    if (b.vals.isEmpty) return;
    const ch = 15.0;
    final cols = math.max(4, (size.width / cw).floor());
    final rows = math.max(1, (size.height / ch).floor());
    final hh = rows * ch, y0 = size.height - hh;
    final p = Paint()..isAntiAlias = false;
    for (var c = 0; c < cols; c++) {
      final v = b.vals[(c / cols * b.vals.length).floor()];
      if (v == null) continue;
      final e = (((v - b.lo) / (b.hi - b.lo)).clamp(0.0, 1.0) * rows * 8).round();
      for (var r = 0; r < rows; r++) {
        final f = (e - r * 8).clamp(0, 8);
        if (f == 0) break;
        p.color = b.palette[math.min(b.palette.length - 1, (r / rows * b.palette.length).floor())];
        final h = f / 8 * ch;
        canvas.drawRect(Rect.fromLTWH(c * cw, y0 + hh - r * ch - h, cw - 1, h), p);
      }
    }
  }

  @override
  bool shouldRepaint(_BlocksPainter o) => true;
}

/// Figlet-ish 3×5 pixel digits.
const _glyphs = {
  '0': '111101101101111',
  '1': '010110010010111',
  '2': '111001111100111',
  '3': '111001111001111',
  '4': '101101111001001',
  '5': '111100111001111',
  '6': '111100111101111',
  '7': '111001001001001',
  '8': '111101111101111',
  '9': '111101111001111',
  ':': '0101010',
};

class _Fig extends StatelessWidget {
  const _Fig(this.text, this.color, {this.align = Alignment.centerLeft});
  final String text;
  final Color color;
  final Alignment align;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final px = math.min(c.maxHeight / 5, c.maxWidth / (text.length * 4.2)).floorToDouble();
      var w = 0.0;
      for (final ch in text.split('')) {
        w += _glyphs.containsKey(ch) ? ((ch == ':' ? 1 : 3) + 1) * px : 2 * px;
      }
      return Align(
        alignment: align,
        child: SizedBox(
          width: w,
          height: 5 * px,
          child: CustomPaint(painter: _FigPainter(text, color, px)),
        ),
      );
    },
  );
}

class _FigPainter extends CustomPainter {
  _FigPainter(this.text, this.color, this.px);
  final String text;
  final Color color;
  final double px;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    var x = 0.0;
    for (final ch in text.split('')) {
      final g = _glyphs[ch];
      if (g == null) {
        x += 2 * px;
        continue;
      }
      final colon = ch == ':';
      for (var i = 0; i < g.length; i++) {
        if (g[i] != '1') continue;
        final cx = colon ? 0 : i % 3, cy = colon ? i : i ~/ 3;
        if (cy >= 5) continue; // the concept's 5-row viewBox clips the colon's third dot
        canvas.drawRect(Rect.fromLTWH(x + cx * px, cy * px, px - 2, px - 2), p);
      }
      x += ((colon ? 1 : 3) + 1) * px;
    }
  }

  @override
  bool shouldRepaint(_FigPainter o) => o.text != text || o.color != color || o.px != px;
}

/// Low-res "terminal image" of a cover: real art decoded at [n]×[n] and scaled up with
/// nearest-neighbour, else the generated sun-over-hills scene as a pixel grid.
class _Pix extends StatelessWidget {
  const _Pix({required this.title, this.b64});
  final String title;
  final String? b64;
  static const n = 28;

  static final _cache = <String, Uint8List>{};

  @override
  Widget build(BuildContext context) {
    final data = b64;
    final fallback = CustomPaint(
      painter: _PixPainter(hueFor(title), (stableHash('$title#') % 7) + 1, n),
      size: Size.infinite,
    );
    if (data == null || data.isEmpty) return fallback;
    final bytes = _cache.putIfAbsent(
      data.length > 64 ? data.substring(0, 64) + data.length.toString() : data,
      () => base64Decode(data),
    );
    return Image.memory(
      bytes,
      cacheWidth: n,
      cacheHeight: n,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.none,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

class _PixPainter extends CustomPainter {
  _PixPainter(this.hue, this.seed, this.n);
  final double hue;
  final int seed, n;

  Color _hsl(double h, double s, double l) => HSLColor.fromAHSL(1, h % 360, s / 100, l / 100).toColor();

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / n;
    final sx = (30 + (seed * 37) % 40) / 100 * n, sy = (34 + (seed * 13) % 10) / 100 * n, sr = .15 * n;
    final sun = _hsl(44, 96, 82), back = _hsl(hue + 6, 48, 30), front = _hsl(hue, 58, 15);
    final p = Paint()..isAntiAlias = false;
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        final fx = x / n * 100, fy = y / n * 100;
        final h1 = 62 - 6 * math.sin(fx / 100 * 6.28 * .9), h2 = 79 - 5 * math.sin(fx / 100 * 6.28 * .6 + 1);
        var col = _hsl(hue, 58, (20 + fy / 100 * 24).roundToDouble());
        if (math.sqrt(math.pow(x + .5 - sx, 2) + math.pow(y + .5 - sy, 2)) < sr) col = sun;
        if (fy > h1) col = back;
        if (fy > h2) col = front;
        p.color = col;
        canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell + .6, cell + .6), p);
      }
    }
  }

  @override
  bool shouldRepaint(_PixPainter o) => o.hue != hue || o.seed != seed || o.n != n;
}

/// Bordered box around artwork.
Widget _artBox(Widget child, {double pad = 6}) => Container(
  padding: EdgeInsets.all(pad),
  decoration: BoxDecoration(
    border: Border.all(color: _box),
    borderRadius: BorderRadius.circular(7),
  ),
  child: child,
);

// ------------------------------------------------------------------ table rows

/// Table header row (`th`): dim, rule underneath.
Widget _thead(List<Widget> cells) => Container(
  padding: const EdgeInsets.only(bottom: 2),
  decoration: const BoxDecoration(
    border: Border(bottom: BorderSide(color: _box)),
  ),
  child: Row(children: cells),
);

/// Table body row (`td` padding 2px); [sel] = highlighted row.
Widget _trow(List<Widget> cells, {bool sel = false, VoidCallback? onTap, double vpad = 2}) => GestureDetector(
  behavior: HitTestBehavior.opaque,
  onTap: onTap,
  child: Container(
    color: sel ? _bg2 : null,
    padding: EdgeInsets.symmetric(vertical: vpad),
    child: Row(children: cells),
  ),
);

/// A cell [chars] characters wide (+12px column gap unless [last]).
Widget _cell(Widget child, {double? chars, int? flex, bool right = false, bool last = false}) {
  final c = Padding(
    padding: EdgeInsets.only(right: last ? 0 : 12),
    child: Align(alignment: right ? Alignment.centerRight : Alignment.centerLeft, child: child),
  );
  if (flex != null) return Expanded(flex: flex, child: c);
  return SizedBox(width: (chars ?? 1) * _cw() + (last ? 0 : 12), child: c);
}

// ------------------------------------------------------------------ Home

class _Home extends ConsumerWidget {
  const _Home();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final h24 = settings.clock24, f = settings.fahrenheit;
    final s = topicData<SystemData>(ref, 'system');
    final c = topicData<ClaudeData>(ref, 'claude');
    final sl = slackHome(ref);
    final m = topicData<MediaData>(ref, 'media');
    final net = topicData<NetworkData>(ref, 'network');
    final w = ref.watch(weatherProvider);
    final events = ref.watch(calendarEventsProvider);
    void go(PageId to) => PageNav.go(context, to);
    return Ticker(
      builder: (context, now) {
        final n = nextEvent(events, now);
        final g = s?.gpu;
        final slm = sl.latest;
        return _page(
          'deskfetch',
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 310,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => go(PageId.calendar),
                      child: SizedBox(height: 120, child: _Fig(clock(now, h24: h24), _or)),
                    ),
                    const SizedBox(height: 10),
                    _t(longDate(now), c: _dim),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        for (final k in const [_bg2, _rs, _gr, _yl, _bl, _pu, _tl, _fg])
                          Container(width: 26, height: 16, color: k),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 28),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ln([_s('you', _gr, true), _s('@'), _s('deskpanel', _gr, true)]),
                    _ln([_s('---------------', _dim)]),
                    const SizedBox(height: 2),
                    _kv([
                      (
                        'next',
                        n == null ? [_s('nothing else today', _dim)] : [_s('${n.title} '), _s(_inText(n, now), _or)],
                        () => go(PageId.calendar),
                      ),
                      (
                        'cpu',
                        s == null ? [_s('—', _dim)] : [_s('${s.cpu.pct.round()}% '), _s('(${s.cpu.model})', _dim)],
                        () => go(PageId.system),
                      ),
                      (
                        'gpu',
                        g == null || !g.available || g.pct == null
                            ? [_s('n/a', _dim)]
                            : [_s('${g.pct!.round()}% '), if (g.tempC != null) _s('${g.tempC!.round()}°C', _dim)],
                        () => go(PageId.system),
                      ),
                      (
                        'claude',
                        c?.fiveHour == null
                            ? [_s('no data yet', _dim)]
                            : [
                                _s('${limitPct(c!.fiveHour, now).round()}% of 5h '),
                                _s(resetsIn(c.fiveHour, now).toLowerCase(), _dim),
                              ],
                        () => go(PageId.claude),
                      ),
                      (
                        'slack',
                        slm != null
                            ? [
                                _s('${sl.headline} ', _or),
                                _s('<', _dim),
                                _s(slm.sender),
                                _s('> ', _dim),
                                _s(slm.text, _dim),
                              ]
                            : sl.headline == 'All caught up'
                            ? [_s('all caught up '), _s('(${_lc(sl.detail)})', _dim)]
                            : [_s(_lc(sl.detail), _dim)],
                        () => go(PageId.slack),
                      ),
                      (
                        'weather',
                        w == null
                            ? [_s('set a location', _dim)]
                            : [
                                _s('${temp(w.now.tempC, f)}°${f ? 'F' : 'C'} ${w.now.condition.toLowerCase()} '),
                                _s('in ${w.place}', _dim),
                              ],
                        () => go(PageId.weather),
                      ),
                      (
                        'music',
                        m?.title == null
                            ? [_s('nothing playing', _dim)]
                            : [_s(m!.title!), if (m.artist != null) _s(' by ${m.artist}', _dim)],
                        () => go(PageId.music),
                      ),
                      (
                        'uptime',
                        net?.onlineSince == null ? [_s('—', _dim)] : [_s(durLong(now.difference(net!.onlineSince!)))],
                        null,
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _Btn(
                          m?.playing == true ? 'pause' : 'play',
                          hot: true,
                          onTap: m?.title == null ? null : () => act(context, ref, 'media.play_pause'),
                        ),
                        const SizedBox(width: 4),
                        _Btn('next', onTap: m?.title == null ? null : () => act(context, ref, 'media.next')),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------------ System

class _System extends ConsumerWidget {
  const _System();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(systemTabProvider) == 0 ? const _Pc() : const _Internet();
}

Widget _tabs(WidgetRef ref) {
  final tab = ref.watch(systemTabProvider);
  final set = ref.read(systemTabProvider.notifier).set;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _Btn('laptop', on: tab == 0, onTap: () => set(0)),
      const SizedBox(width: 6),
      _Btn('internet', on: tab == 1, onTap: () => set(1)),
    ],
  );
}

/// Download-rate history kept on the phone (the system topic only carries the current rate).
final _netHist = <double>[];
SystemData? _netLast;

void _pushNet(SystemData s) {
  if (identical(s, _netLast)) return;
  _netLast = s;
  _netHist.add(s.downBps);
  if (_netHist.length > 80) _netHist.removeAt(0);
}

class _Pc extends ConsumerWidget {
  const _Pc();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = topicData<SystemData>(ref, 'system')!;
    _pushNet(s);
    final g = s.gpu;
    const gb = 1024 * 1024 * 1024;
    final (down, downU) = rate(s.downBps);
    final (up, upU) = rate(s.upBps);
    final vram = g.available && g.vramUsed != null && (g.vramTotal ?? 0) > 0;
    final hist = [...List<double?>.filled(math.max(0, 80 - _netHist.length), null), ..._netHist];
    final netHi = math.max(1024 * 1024.0, maxOf(_netHist) * 1.25);
    final vl = g.vramLabel.toLowerCase();
    final lw = math.max(4, vl.length);
    return _page(
      'btop',
      right: _tabs(ref),
      Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 135,
            child: _pane(
              'cpu',
              n: 1,
              tr: s.cpu.cores != null ? '${s.cpu.cores}c/${s.cpu.threads ?? s.cpu.cores}t' : null,
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _Blocks(s.cpuHistory, hi: 100)),
                  _Meter('cpu', s.cpu.pct / 100, '${s.cpu.pct.toStringAsFixed(1)}%'),
                  const SizedBox(height: 1),
                  g.available && g.pct != null
                      ? _Meter('gpu', g.pct! / 100, '${g.pct!.toStringAsFixed(1)}%')
                      : _Meter('gpu', 0, 'n/a'),
                  const SizedBox(height: 2),
                  _ln([
                    _s('${s.cpu.model}${g.model != null ? ', ${g.model}' : ''}', _dim),
                    if (g.tempC != null) _s(' at ${g.tempC!.round()}°C', _dim),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(width: _colGap),
          Expanded(
            flex: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _pane(
                    'mem',
                    n: 2,
                    c: _pu,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Meter(
                          'ram'.padRight(lw),
                          s.ramUsed / s.ramTotal,
                          '${(s.ramUsed / gb).toStringAsFixed(1)}/${(s.ramTotal / gb).round()}G',
                          color: _pu,
                        ),
                        _Meter(
                          vl.padRight(lw),
                          vram ? g.vramUsed! / g.vramTotal! : 0,
                          vram ? '${(g.vramUsed! / gb).toStringAsFixed(1)}/${(g.vramTotal! / gb).round()}G' : 'n/a',
                          color: _pu,
                        ),
                        _Meter('disk'.padRight(lw), s.diskPct / 100, '${s.diskPct.round()}%', color: _tl),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: _rowGap),
                _pane(
                  'net',
                  n: 3,
                  c: _tl,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          _ln([_s('down ', _tl), _s('$down $downU', _fg, true)]),
                          const Spacer(),
                          _ln([_s('up ', _bl), _s('$up $upU', _fg, true)]),
                        ],
                      ),
                      SizedBox(
                        height: 48,
                        child: _Blocks(hist, hi: netHi, palette: const [_tl, _bl]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Internet extends ConsumerWidget {
  const _Internet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = topicData<NetworkData>(ref, 'network');
    if (n == null) {
      return _page(
        'ping',
        right: _tabs(ref),
        _pane('ping', n: 1, Center(child: _t('waiting for network data…', c: _dim))),
      );
    }
    final live = ref.watch(agentProvider).live;
    final now = DateTime.now();
    final host = n.latencyTarget.split(':').first;
    final st = n.speedtest;
    final last = st.last, prog = st.progress;
    final dl = st.running ? prog?.downBps : last?.downBps;
    final ul = st.running ? prog?.upBps : last?.upBps;
    final up = live && n.online;
    return _page(
      'ping $host',
      right: _tabs(ref),
      Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 130,
            child: _pane(
              'ping',
              n: 1,
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: ClipRect(child: _PingLines(n, host))),
                  _ln([
                    _s('link ', _dim),
                    _s(up ? 'up' : 'down', up ? _gr : _rs),
                    _s(
                      '${n.onlineSince != null && up ? ' ${durLong(now.difference(n.onlineSince!))}' : ''}'
                      '${n.lastDrop != null ? ', last drop ${ago(now.difference(n.lastDrop!))}' : ''}'
                      ', ${bytes(n.usageToday)} today, ${bytes(n.usageMonth, digits: 0)} this month',
                      _dim,
                    ),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(width: _colGap),
          Expanded(
            flex: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _pane(
                    'latency',
                    n: 2,
                    tr: '0-50 ms',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              n.latencyMs == null ? 'timeout' : '${n.latencyMs!.round()} ms',
                              style: _ts(size: 22, c: n.latencyMs == null ? _rs : _or, b: true, h: 1.3),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ln([
                                _s(
                                  'jitter ${n.jitterMs?.toStringAsFixed(1) ?? '—'} ms, loss ${n.lossPct.round()}%',
                                  _dim,
                                ),
                              ]),
                            ),
                          ],
                        ),
                        Expanded(child: _Blocks(n.latencyHistory, hi: 50)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: _rowGap),
                Expanded(
                  child: _pane(
                    'speedtest',
                    n: 3,
                    c: _tl,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            _t('down ', c: _tl),
                            Text(dl == null ? '—' : mbps(dl), style: _ts(size: 20, b: true, h: 1.3)),
                            const SizedBox(width: 16),
                            _t('up ', c: _bl),
                            Text(ul == null ? '—' : mbps(ul), style: _ts(size: 20, b: true, h: 1.3)),
                            const SizedBox(width: 16),
                            _t('Mbps', c: _dim),
                          ],
                        ),
                        _ln([
                          _s(
                            st.running
                                ? 'Testing now${prog != null ? ', ${prog.phase}' : ''}'
                                : last == null
                                ? 'Never tested'
                                : 'Tested ${ago(now.difference(last.at))}, ping ${last.pingMs.round()} ms',
                            _dim,
                          ),
                        ]),
                        if (st.running) _Meter('', (prog?.pct ?? 0) / 100, '${(prog?.pct ?? 0).round()}%', color: _or),
                        const Spacer(),
                        _Btn(
                          st.running ? 'testing…' : 'run test',
                          hot: true,
                          onTap: st.running
                              ? null
                              : () => act(
                                  context,
                                  ref,
                                  'speedtest.run',
                                  const {},
                                  null,
                                  null,
                                  const Duration(seconds: 90),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// `ping` output: as many recent samples as fit, then the rtt summary.
class _PingLines extends StatelessWidget {
  const _PingLines(this.n, this.host);
  final NetworkData n;
  final String host;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final rows = math.max(3, (c.maxHeight / _lh).floor() - 1);
      final h = n.latencyHistory;
      final tail = h.length > rows ? h.sublist(h.length - rows) : h;
      final seq0 = DateTime.now().millisecondsSinceEpoch ~/ 1000 % 10000 - tail.length;
      final st = (h.length > 60 ? h.sublist(h.length - 60) : h).whereType<double>().toList();
      final mn = st.isEmpty ? 0.0 : st.reduce(math.min), mx = st.isEmpty ? 0.0 : st.reduce(math.max);
      final avg = st.isEmpty ? 0.0 : st.reduce((a, b) => a + b) / st.length;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, x) in tail.indexed)
            x == null
                ? _ln([_s('Request timeout for icmp_seq ', _rs), _s('${seq0 + i + 1}')])
                : _ln([
                    _s('64 bytes from ', _dim),
                    _s(host),
                    _s(': icmp_seq=', _dim),
                    _s('${seq0 + i + 1}'),
                    _s(' ttl=58 time=', _dim),
                    _s('${x.toStringAsFixed(1)} ms', x > 25 ? _yl : _gr),
                  ]),
          _ln([
            _s(
              'rtt min/avg/max = ${mn.toStringAsFixed(1)}/${avg.toStringAsFixed(1)}/${mx.toStringAsFixed(1)} ms',
              _dim,
            ),
          ]),
        ],
      );
    },
  );
}

// ------------------------------------------------------------------ Claude

class _Claude extends ConsumerWidget {
  const _Claude();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = topicData<ClaudeData>(ref, 'claude')!;
    final h24 = ref.watch(settingsProvider.select((s) => s.clock24));
    return Ticker(
      builder: (context, now) {
        final five = limitPct(c.fiveHour, now), week = limitPct(c.sevenDay, now);
        final peak = maxOf(c.days.map((d) => d.tokens));
        final indent = EdgeInsets.only(left: 7 * _cw());
        return _page(
          'ccusage --live',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _pane(
                'limits',
                n: 1,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Meter('5-hour', five / 100, c.fiveHour == null ? 'n/a' : '${five.round()}%'),
                    Padding(
                      padding: indent + const EdgeInsets.only(bottom: 4),
                      child: _t(resetsIn(c.fiveHour, now).toLowerCase().replaceFirst('resets', 'resets'), c: _dim),
                    ),
                    _Meter('weekly', week / 100, c.sevenDay == null ? 'n/a' : '${week.round()}%'),
                    Padding(
                      padding: indent,
                      child: _t(resetsAt(c.sevenDay, now, h24: h24).replaceFirst('Resets', 'resets'), c: _dim),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: _rowGap),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 140,
                      child: _pane(
                        'daily',
                        n: 2,
                        tr: 'peak ${compact(peak)}',
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _thead([
                              _cell(_t('day', c: _dim), flex: 20),
                              _cell(_t('tokens', c: _dim), flex: 20, right: true),
                              _cell(const SizedBox(), flex: 60, last: true),
                            ]),
                            for (final (i, d) in c.days.indexed)
                              () {
                                final today = i == c.days.length - 1;
                                return _trow(sel: today, [
                                  _cell(_t(dayLabel(d.date, now).toLowerCase(), c: today ? _or : _fg), flex: 20),
                                  _cell(_t('${(d.tokens / 1e6).toStringAsFixed(1)}M'), flex: 20, right: true),
                                  Expanded(
                                    flex: 60,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: FractionallySizedBox(
                                        widthFactor: (d.tokens / peak).clamp(0.0, 1.0),
                                        child: Container(height: 9, color: today ? _or : _yl.withValues(alpha: .7)),
                                      ),
                                    ),
                                  ),
                                ]);
                              }(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: _colGap),
                    Expanded(
                      flex: 100,
                      child: _pane(
                        'today',
                        n: 3,
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _kv([
                              ('tokens', [_s(compact(c.tokens))], null),
                              ('output', [_s(compact(c.outputTokens))], null),
                              ('messages', [_s('${c.messages}')], null),
                              ('last hour', [_s(compact(c.lastHourTokens))], null),
                            ]),
                            const Spacer(),
                            _t('--- by model ---', c: _dim),
                            if (c.modelsToday.isEmpty) _t('no messages yet today', c: _dim),
                            _kv(kc: _tl, [
                              for (final m in c.modelsToday.take(4))
                                (m.family.toLowerCase(), [_s(compact(m.tokens))], null),
                            ]),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------------ Calendar

class _Calendar extends ConsumerWidget {
  const _Calendar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(calendarEventsProvider);
    final h24 = ref.watch(settingsProvider.select((s) => s.clock24));
    return Ticker(
      builder: (context, now) {
        final split = splitEvents(events, now);
        final n = nextEvent(events, now);
        final first = DateTime(now.year, now.month, 1);
        final days = DateTime(now.year, now.month + 1, 0).day;
        final evDays = {
          for (final e in events)
            if (e.start.year == now.year && e.start.month == now.month) e.start.day,
        };
        final cw = _cw();
        final cellW = 2.6 * cw;
        String tm(DateTime t, bool allDay) => (allDay ? 'all day' : clockFull(t, h24: h24)).padLeft(8);
        Widget cell(Widget c) => SizedBox(
          width: cellW,
          height: _lh,
          child: Align(alignment: Alignment.centerRight, child: c),
        );
        final cells = <Widget>[
          for (final d in const ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa']) cell(_t(d, c: _yl)),
          for (var i = 0; i < first.weekday % 7; i++) cell(const SizedBox()),
          for (var d = 1; d <= days; d++)
            cell(
              d == now.day
                  ? Container(
                      width: cellW,
                      alignment: Alignment.centerRight,
                      decoration: BoxDecoration(color: _fg, borderRadius: BorderRadius.circular(2)),
                      child: _t('$d', c: _bg, b: true),
                    )
                  : evDays.contains(d)
                  ? Text(
                      '$d',
                      style: _ts(c: _tl).copyWith(decoration: TextDecoration.underline, decorationColor: _tl),
                    )
                  : _t('$d'),
            ),
        ];
        return _page(
          'cal && agenda',
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _pane(
                '${month(now).toLowerCase()} ${now.year}',
                n: 1,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 7 * cellW + 6 * 6,
                      child: Wrap(spacing: 6, runSpacing: 2, children: cells),
                    ),
                    const Spacer(),
                    _t('underlined days have events', c: _dim),
                  ],
                ),
              ),
              const SizedBox(width: _colGap),
              Expanded(
                child: _pane(
                  'agenda',
                  n: 2,
                  tr: longDate(now),
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (split.today.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _t('  nothing today', c: _dim),
                          ),
                        for (final e in split.today)
                          () {
                            final nx = e == n, past = e.end.isBefore(now);
                            final c = nx ? _or : (past ? _dim : _fg);
                            return Container(
                              color: nx ? _bg2 : null,
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: _ln([
                                _s(
                                  '${nx ? '>' : ' '} ${tm(e.start, e.allDay)}${e.allDay ? '' : ' - ${tm(e.end, false)}'}  ',
                                  c,
                                ),
                                _s(e.title, c, true),
                                if (e.location != null) _s('  @${e.location}', nx ? c : _dim),
                                if (nx) _s('  ${_inText(e, now)}', c),
                              ]),
                            );
                          }(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 10, 4, 2),
                          child: _t('--- later this week ---', c: _dim),
                        ),
                        if (split.later.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _t('  nothing scheduled', c: _dim),
                          ),
                        for (final e in split.later)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            child: _ln([
                              _s('  '),
                              _s(weekday3(e.start).toLowerCase(), _tl),
                              _s(' ${tm(e.start, e.allDay)}  '),
                              _s(e.title, _fg, true),
                              if (e.location != null) _s('  @${e.location}', _dim),
                            ]),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------------ Weather

const _wttr = {
  'cloud': ['      .--.    ', '   .-(    ).  ', '  (___.__)__) ', '              '],
  'rain': ['     .-.      ', '    (   ).    ', '   (___(__)   ', "    ' ' ' '   "],
  'sun': ['    \\   /     ', '     .-.      ', '  - (   ) -   ', '     `-´      '],
  'partly': ['   \\  /       ', ' _ /"".-.     ', '   \\_(   ).   ', '   /(___(__)  '],
};

class _Weather extends ConsumerWidget {
  const _Weather();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(weatherProvider);
    final s = ref.watch(settingsProvider);
    if (w == null) {
      return _page(
        'curl wttr.in',
        _pane('weather', n: 1, Center(child: _t('set your location in settings → weather', c: _dim))),
      );
    }
    final f = s.fahrenheit;
    int t(double c) => temp(c, f);
    final hrs = w.hours.take(12).toList();
    final temps = [for (final h in hrs) t(h.tempC).toDouble()];
    final mn = temps.isEmpty ? 0.0 : temps.reduce(math.min), mx = temps.isEmpty ? 1.0 : temps.reduce(math.max);
    final span = math.max(mx - mn, 4.0);
    String hl(DateTime d) =>
        s.clock24 ? '${two(d.hour)}h' : '${d.hour % 12 == 0 ? 12 : d.hour % 12} ${ampm(d).toLowerCase()}';
    final up = w.now.updated;
    return _page(
      'curl wttr.in/${w.place}',
      Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 115,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _pane(
                  'now',
                  n: 1,
                  tr: (s.clock24 ? clock(up, h24: true) : '${clock(up)} ${ampm(up).toLowerCase()}'),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((_wttr[w.now.icon] ?? _wttr['cloud']!).join('\n'), style: _ts(), softWrap: false),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _t(w.now.condition),
                            _ln([
                              _s('${t(w.now.tempC)}', _yl, true),
                              _s('('),
                              _s('${t(w.now.feelsC)}', _yl),
                              _s(') °${f ? 'F' : 'C'}'),
                            ]),
                            _ln([
                              _s(wind(w.now.windKmh, f).split(' ').first, _gr, true),
                              _s(' ${wind(w.now.windKmh, f).split(' ').last}'),
                            ]),
                            _t('${w.now.humidity}% humidity'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: _rowGap),
                Expanded(
                  child: _pane(
                    'next 12h',
                    n: 3,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _Blocks(
                            [
                              for (final v in temps) ...[v, v, v],
                            ],
                            lo: mn - span * .6,
                            hi: mx + span * .25,
                            palette: const [_bl, _yl, _or],
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            for (final (i, h) in hrs.indexed)
                              if (i % 3 == 0)
                                _ln([_s(i == 0 ? 'now ' : '${hl(h.time)} ', _dim), _s('${t(h.tempC)}°', _yl)]),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: _colGap),
          Expanded(
            flex: 100,
            child: _pane(
              'forecast',
              n: 2,
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _thead([
                    _cell(_t('day', c: _dim), flex: 10),
                    _cell(const SizedBox(), flex: 12),
                    _cell(_t('high', c: _dim), flex: 8, right: true),
                    _cell(_t('low', c: _dim), flex: 8, right: true),
                    _cell(_t('rain', c: _dim), flex: 8, right: true, last: true),
                  ]),
                  for (final (i, d) in w.days.indexed)
                    _trow(sel: i == 0, [
                      _cell(_t(i == 0 ? 'today' : weekday3(d.date).toLowerCase(), c: i == 0 ? _or : _fg), flex: 10),
                      _cell(_t(d.icon, c: _dim), flex: 12),
                      _cell(_t('${t(d.hiC)}°', c: _yl), flex: 8, right: true),
                      _cell(_t('${t(d.loC)}°', c: _bl), flex: 8, right: true),
                      _cell(
                        _t(d.precipPct > 0 ? '${d.precipPct}%' : '-', c: d.precipPct > 50 ? _tl : _dim),
                        flex: 8,
                        right: true,
                        last: true,
                      ),
                    ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ Music

class _Music extends ConsumerWidget {
  const _Music();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = topicData<MediaData>(ref, 'media')!;
    final art = topicData<MediaArt>(ref, 'media.art');
    final skew = ref.read(agentProvider.notifier).clockSkewMs;
    final title = m.title;
    return _page(
      'cmus',
      Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: _artBox(_Pix(title: title ?? 'Nothing playing', b64: art?.artId == m.artId ? art?.b64 : null)),
          ),
          const SizedBox(width: _colGap),
          Expanded(
            child: _pane(
              'playlist',
              n: 1,
              tr: title == null ? 'stopped' : (m.playing ? 'playing' : 'paused'),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (title == null)
                    _t('  queue empty', c: _dim)
                  else
                    _trow(sel: true, [
                      _cell(_t(m.playing ? '>' : '=', c: _or), chars: 1),
                      _cell(_t(m.artist ?? ''), flex: 26),
                      _cell(_t(title, b: true), flex: 34),
                      _cell(_t(m.album ?? '', c: _dim), flex: 26),
                      _cell(
                        _t(m.durationMs == null ? '' : mmss(m.durationMs!), c: _dim),
                        chars: 5,
                        right: true,
                        last: true,
                      ),
                    ]),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(flex: 3, child: _t(title ?? 'nothing playing', c: _or, b: true)),
                            const SizedBox(width: 10),
                            if (m.artist != null) Flexible(flex: 2, child: _t('by ${m.artist}', c: _dim)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      _t((m.source ?? '').toLowerCase(), c: _dim),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Ticker(
                    period: const Duration(seconds: 1),
                    builder: (context, now) {
                      final pos = m.positionNow(now, skewMs: skew);
                      final total = m.durationMs ?? 0;
                      return _Prog(
                        pos: pos,
                        total: total,
                        enabled: m.canSeek && total > 0,
                        onSeek: (f) => act(context, ref, 'media.seek', {'position_ms': (f * total).round()}),
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _Btn('prev', onTap: () => act(context, ref, 'media.prev')),
                      const SizedBox(width: 4),
                      _Btn(m.playing ? 'pause' : 'play', hot: true, onTap: () => act(context, ref, 'media.play_pause')),
                      const SizedBox(width: 4),
                      _Btn('next', onTap: () => act(context, ref, 'media.next')),
                    ],
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

/// cmus progress line `1:17 [=====>-----] 4:01`; tap / drag on the bar to seek.
class _Prog extends StatefulWidget {
  const _Prog({required this.pos, required this.total, required this.enabled, required this.onSeek});
  final int pos, total;
  final bool enabled;
  final ValueChanged<double> onSeek;
  @override
  State<_Prog> createState() => _ProgState();
}

class _ProgState extends State<_Prog> {
  double? _drag;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final cw = _cw();
      final cols = (c.maxWidth / cw - .01).floor();
      final tot = widget.total == 0 ? '-:--' : mmss(widget.total);
      final p = _drag ?? (widget.total == 0 ? 0.0 : widget.pos / widget.total);
      final shown = _drag == null ? widget.pos : (_drag! * widget.total).round();
      List<InlineSpan> spans(int n) {
        final fill = (p.clamp(0.0, 1.0) * n).round();
        return [
          _s(mmss(shown).padLeft(5), _gr),
          _s(' '),
          _s('[', _dim),
          _s('${'=' * math.max(0, fill - 1)}${fill > 0 ? '>' : ''}', _or),
          _s('${'-' * (n - fill)}]', _dim),
          _s(' $tot', _dim),
        ];
      }

      final n = _fitN(c.maxWidth, math.max(10, cols - 9 - tot.length), spans, min: 10);
      final barX0 = 7 * cw, barW = n * cw;
      double f(Offset o) => ((o.dx - barX0) / barW).clamp(0.0, 1.0);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: widget.enabled ? (d) => widget.onSeek(f(d.localPosition)) : null,
        onHorizontalDragStart: widget.enabled ? (d) => setState(() => _drag = f(d.localPosition)) : null,
        onHorizontalDragUpdate: widget.enabled ? (d) => setState(() => _drag = f(d.localPosition)) : null,
        onHorizontalDragEnd: widget.enabled
            ? (_) {
                widget.onSeek(_drag!);
                setState(() => _drag = null);
              }
            : null,
        child: _ln(spans(n), overflow: TextOverflow.clip),
      );
    },
  );
}

// ------------------------------------------------------------------ Hotspot

/// The Hotspot Monitor Overview (the roof phone sharing mobile data) as a btop-ish
/// screen: the phone and its radio on the left, power/heat/data meters and the event
/// journal on the right.
class _Hotspot extends ConsumerWidget {
  const _Hotspot();

  static const _k = TerminalSkin.t;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = topicData<HotspotData>(ref, 'hotspot')!;
    final f = ref.watch(settingsProvider.select((s) => s.fahrenheit));
    return Ticker(
      builder: (context, now) => _page(
        'hotspot status${d.name == null ? '' : ' --phone "${d.name}"'}',
        right: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 7),
              decoration: BoxDecoration(color: hsStateColor(d, _k), shape: BoxShape.circle),
            ),
            _t(_lc(hsSeen(d, now)), c: _dim),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 55, child: _phone(d, now)),
                  const SizedBox(height: _rowGap),
                  Expanded(flex: 45, child: _radio(d)),
                ],
              ),
            ),
            const SizedBox(width: _colGap),
            Expanded(
              flex: 100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _power(d, f),
                  const SizedBox(height: _rowGap),
                  Expanded(child: _journal(d, now)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _phone(HotspotData d, DateTime now) {
    final alert = hsAlert(d, now);
    final session = hsSessionNote(d, now);
    return _pane(
      'phone',
      n: 1,
      tr: d.model?.split(' · ').first,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _lc(hsStateLabel(d)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _ts(size: 22, c: hsStateColor(d, _k), b: true, h: 1.3),
          ),
          if (alert != null)
            Text.rich(
              TextSpan(children: [_s('!! ', _rs, true), _s(alert, _rs)], style: _ts()),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 2),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                final rows = <(String, List<InlineSpan>, VoidCallback?)>[
                  ('net', [_s(hsNetwork(d), _fg, true)], null),
                  ('operator', [_s(d.operator ?? '—')], null),
                  ('sharing', [_s(_lc(hsSharing(d)), d.tetherOn == true ? _gr : _dim)], null),
                  (
                    'uptime',
                    [_s(hsUptime(d.uptimeS)), _s(' phone, ', _dim), _s(hsUptime(d.agentUptimeS)), _s(' agent', _dim)],
                    null,
                  ),
                  ('boot', [_s(hsBootLine(d).replaceFirst('Boot ', ''), _dim)], null),
                  if (session != null) ('login', [_s(_lc(session), _yl)], null),
                ];
                // Drop from the end (boot first) when an alert leaves less room.
                final n = math.min(rows.length, (box.maxHeight / _lh).floor());
                final shown = session != null && n < rows.length ? [...rows.take(n - 1), rows.last] : rows.take(n);
                return _kv(shown.toList());
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _radio(HotspotData d) {
    final g = d.grade;
    final gc = hsGradeColor(g, _k);
    final (down, downU) = hsBpsParts(d.rxBps);
    final (up, upU) = hsBpsParts(d.txBps);
    Widget big(String s, [Color c = _fg]) => Text(s, style: _ts(size: 20, c: c, b: true, h: 1.3));
    return _pane(
      'radio',
      n: 2,
      c: _tl,
      tr: d.operator,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              _t('signal ', c: _tl),
              big(d.score == null ? '—' : '${d.score!.round()}', gc),
              _t('/100 ', c: _dim),
              _t(_lc(hsGradeLabel(g)), c: gc, b: true),
            ],
          ),
          _Meter('', (d.score ?? 0) / 100, '', color: gc),
          _ln([_s(hsSignalLine(d), _dim)]),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              _t('down ', c: _tl),
              big(down),
              _t(' $downU', c: _dim),
              const SizedBox(width: 18),
              _t('up ', c: _bl),
              big(up),
              _t(' $upU', c: _dim),
            ],
          ),
          _ln([_s(_lc(hsPingLine(d)), _dim)]),
        ],
      ),
    );
  }

  Widget _power(HotspotData d, bool f) {
    final frac = d.quotaFrac;
    final dataC = frac == null ? _tl : (frac >= 1 ? _rs : (frac >= .8 ? _yl : _tl));
    final heatC = d.radioResting || d.heat == HotspotHeat.hot
        ? _rs
        : (d.heat == HotspotHeat.warm ? _yl : _fg);
    final bat = d.batteryPct;
    return _pane(
      'power',
      n: 3,
      c: _gr,
      tr: d.chargeStatus,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Meter(
            'batt',
            (bat ?? 0) / 100,
            bat == null ? 'n/a' : '${bat.round()}%',
            color: d.lowBattery ? _rs : _gr,
          ),
          _ln([_s('     '), _s(hsCurrent(d.currentMa), d.lowBattery ? _rs : _fg), _s(' · ${hsPowerLine(d)}', _dim)]),
          _ln([
            _s('temp ', _or, true),
            _s(hsTemp(d.batteryC, fahrenheit: f), heatC, true),
            _s(d.radioResting ? ' radio resting' : ' battery', d.radioResting ? _rs : _dim),
          ]),
          _ln([_s('     '), _s(hsHeatLine(d, fahrenheit: f), _dim)]),
          if (frac != null)
            _Meter('data', frac, '${hsBytes(d.cycleUsed)}/${hsBytes(d.quota)}', color: dataC)
          else
            _ln([_s('data ', _or, true), _s(hsBytes(d.cycleUsed), _fg, true), _s(' used, no quota', _dim)]),
          _ln([_s('     '), _s(hsTodayLine(d), _dim)]),
        ],
      ),
    );
  }

  /// `journalctl`-style event log, newest first, as many lines as fit.
  Widget _journal(HotspotData d, DateTime now) => _pane(
    'events',
    n: 4,
    c: _pu,
    tr: d.events.isEmpty ? null : 'newest first',
    d.events.isEmpty
        ? Center(child: _t('-- no entries --', c: _dim))
        : LayoutBuilder(
            builder: (context, box) {
              final n = math.min(d.events.length, (box.maxHeight / _lh).floor());
              final shown = d.events.take(n).toList();
              final times = [for (final e in shown) slackTime(e.ts, now).replaceFirst('Yesterday', 'yday')];
              final tw = times.map((t) => t.length).fold(3, math.max);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, e) in shown.indexed)
                    _ln([
                      _s(times[i].padLeft(tw), _dim),
                      _s(' '),
                      _s(switch (e.severity) {
                        'critical' => 'crit',
                        'warning' => 'warn',
                        _ => 'info',
                      }, hsEventColor(e, _k), e.severity != 'info'),
                      _s(' '),
                      _s(e.message.replaceAll('→', '->'), e.severity == 'info' ? _fg : hsEventColor(e, _k)),
                    ]),
                ],
              );
            },
          ),
  );
}

// ------------------------------------------------------------------ Timer

class _Timer extends ConsumerWidget {
  const _Timer();

  static String _len(TimerMode m, TimerState st) => switch (m) {
    TimerMode.stopwatch => '--:--',
    TimerMode.countdown => '${st.countdownMin}:00',
    _ => '${m.defaultMin}:00',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(timerProvider);
    final ctl = ref.read(timerProvider.notifier);
    return Ticker(
      period: const Duration(seconds: 1),
      builder: (context, now) {
        final digits = _ms(st.display(now));
        final status = st.running ? 'running' : (st.pristine ? 'stopped' : 'paused');
        final label = st.running ? 'pause' : (st.pristine ? 'start' : 'resume');
        final cmd = switch (st.mode) {
          TimerMode.stopwatch => 'stopwatch',
          TimerMode.countdown => 'timer ${st.countdownMin}m',
          _ => 'timer ${st.mode.defaultMin}m --mode ${st.mode.name.replaceAll('Break', '')}',
        };
        final done = st.sessions.clamp(0, 4);
        return _page(
          cmd,
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 160,
                child: _pane(
                  st.mode.label.toLowerCase(),
                  n: 1,
                  tr: status,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Center(
                          child: SizedBox(
                            height: 130,
                            width: double.infinity,
                            child: _Fig(digits, st.running ? _gr : _or, align: Alignment.center),
                          ),
                        ),
                      ),
                      _Meter('', st.progress(now), digits, color: _or),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: _colGap),
              Expanded(
                flex: 100,
                child: _pane(
                  'controls',
                  n: 2,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _t('mode', c: _dim),
                      for (final m in TimerMode.values)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: _Btn(
                            '${m.label.toLowerCase().padRight(11)} ${_len(m, st).padLeft(5)}',
                            on: m == st.mode,
                            onTap: () => ctl.setMode(m),
                          ),
                        ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          _Btn(label, hot: true, onTap: ctl.toggle),
                          _Btn('reset', onTap: ctl.reset),
                          if (st.mode == TimerMode.countdown && !st.running) ...[
                            _Btn('-', onTap: () => ctl.adjust(-1)),
                            _Btn('+', onTap: () => ctl.adjust(1)),
                          ],
                        ],
                      ),
                      const Spacer(),
                      _ln([
                        _s('sessions ', _dim),
                        _s('#' * done, _or),
                        _s('${'.' * (4 - done)} ${st.sessions}/4', _dim),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------------ Slack

/// `slack inbox`: a mutt-style index with an irc-style line per message: new flag, inverse
/// initials, `<nick>` in the sender's colour, where, age; the text indented underneath.
class _Slack extends ConsumerWidget {
  const _Slack();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = topicData<SlackData>(ref, 'slack')!;
    final total = s.messages.length;
    final team = (s.team ?? 'slack').toLowerCase();
    return Ticker(
      builder: (context, now) => _page(
        'slack inbox',
        right: s.unread > 0 ? _Btn('mark all read', hot: true, onTap: () => slackReadAll(context, ref)) : null,
        _pane(
          'inbox',
          n: 1,
          tr: s.unread > 0 ? '${s.unread} unread' : 'all caught up',
          pad: const EdgeInsets.fromLTRB(10, 12, 10, 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // mutt's status bar.
              Container(
                color: _bg2,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: _ln([
                        _s('-*-', _dim),
                        _s('slack: ', _or, true),
                        _s('$team/${s.user ?? 'you'} '),
                        _s('[msgs:$total new:${s.unread}]', _dim),
                      ]),
                    ),
                    _t('(newest first)', c: _dim),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: total == 0
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _t('no messages.', c: _dim),
                            _ln([_s('inbox zero', _gr, true), _s(', nothing to read', _dim)]),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: total,
                        separatorBuilder: (_, _) => const SizedBox(height: 4),
                        itemBuilder: (context, i) {
                          final m = s.messages[i];
                          return _SlackLine(
                            m,
                            now,
                            onTap: () => slackOpen(context, ref, m),
                            onRead: () => slackMarkRead(context, ref, m),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlackLine extends StatelessWidget {
  const _SlackLine(this.m, this.now, {required this.onTap, required this.onRead});
  final SlackMsg m;
  final DateTime now;
  final VoidCallback onTap, onRead;

  @override
  Widget build(BuildContext context) {
    final on = m.unread;
    final cw = _cw();
    final nick = hex(m.senderColor);
    final nc = on ? nick : nick.withValues(alpha: .5);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        color: on ? _bg2 : null,
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 2 * cw,
                        child: _t(on ? ' N' : '', c: _or, b: true),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 3 * cw,
                        alignment: Alignment.center,
                        color: nc,
                        child: _t(m.initials, c: _bg, b: true),
                      ),
                      SizedBox(width: cw),
                      Expanded(
                        child: _ln([
                          _s('<', _dim),
                          _s(m.sender, nc, true),
                          _s('> ', _dim),
                          _s(slackWhere(m), on ? _tl : _dim),
                        ]),
                      ),
                      SizedBox(width: cw),
                      _t(slackTime(m.ts, now), c: on ? _fg : _dim),
                      const SizedBox(width: 6),
                    ],
                  ),
                  Padding(
                    padding: EdgeInsets.only(left: 6 * cw + 6, right: 6),
                    child: Text(
                      m.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _ts(c: on ? _fg : _dim),
                    ),
                  ),
                ],
              ),
            ),
            // `[ mark read ]`, with a finger-sized margin that also counts as the button.
            Visibility(
              visible: on,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: on ? onRead : null,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 10, 6, 10),
                  child: _Btn('mark read', hot: true, onTap: on ? onRead : null),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ GitHub

class _Github extends ConsumerWidget {
  const _Github();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = topicData<GithubData>(ref, codeTopic(ref))!;
    final src = ref.watch(codeSourceProvider);
    final setSrc = ref.read(codeSourceProvider.notifier).set;
    final now = DateTime.now();
    final today = now.weekday % 7;
    String th(int n) => n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    final week = [for (var i = 0; i < 7; i++) i < g.thisWeek.length ? g.thisWeek[i] : null];
    final mx = maxOf(week);
    final b = g.bestDay;
    return _page(
      '${src == 1 ? 'glab' : 'gh'} contributions --year',
      right: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, l) in codeSources.indexed) ...[
            if (i > 0) const SizedBox(width: 6),
            _Btn(l.toLowerCase(), on: src == i, onTap: () => setSrc(i)),
          ],
        ],
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _pane(
            'contributions',
            n: 1,
            c: _gr,
            tr: '${th(g.total)} total, ${th(g.commits)} commits, ${th(g.private)} private',
            _Heat(g.weeks),
          ),
          const SizedBox(height: _rowGap),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 80,
                  child: _pane(
                    'streak',
                    n: 2,
                    c: _gr,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: 60, child: _Fig('${g.streakCurrent}', _gr)),
                        const Spacer(),
                        _kv(kc: _gr, [
                          ('current', [_s('${g.streakCurrent} day${g.streakCurrent == 1 ? '' : 's'}')], null),
                          ('longest', [_s('${g.streakLongest} days')], null),
                          (
                            'best',
                            [_s(b == null ? '—' : '${b.count}, ${month3(b.date).toLowerCase()} ${b.date.day}')],
                            null,
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: _colGap),
                Expanded(
                  flex: 110,
                  child: _pane(
                    'this week',
                    n: 3,
                    c: _gr,
                    tr: '${g.weekTotal} (${g.weekDelta >= 0 ? '+' : ''}${g.weekDelta})',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _Blocks(
                            [
                              for (final v in week) ...[...List.filled(6, (v ?? 0).toDouble()), 0, 0],
                            ],
                            hi: mx * 1.07,
                            palette: const [_gr],
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [for (var i = 0; i < 7; i++) _t('smtwtfs'[i], c: i == today ? _gr : _dim)],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: _colGap),
                Expanded(
                  flex: 100,
                  child: _pane(
                    topReposLabel(ref).toLowerCase(),
                    n: 4,
                    c: _gr,
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final r in g.topRepos.take(8))
                            _trow([
                              _cell(_t(r.name), flex: 1),
                              _cell(_t('${r.count}', c: _gr), chars: 5, right: true, last: true),
                            ]),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Contribution calendar in four warm-to-green levels.
class _Heat extends StatelessWidget {
  const _Heat(this.weeks);
  final List<List<ContribDay>> weeks;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      const lw = 26.0, top = 14.0;
      final cw = (c.maxWidth - lw) / 53;
      return SizedBox(
        width: c.maxWidth,
        height: top + 7 * cw,
        child: CustomPaint(painter: _HeatPainter(weeks)),
      );
    },
  );
}

class _HeatPainter extends CustomPainter {
  _HeatPainter(this.weeks);
  final List<List<ContribDay>> weeks;

  static const _lv = [Color(0xFF2E2820), Color(0xFF3E5A2E), Color(0xFF5E8A45), Color(0xFF80B060), _gr];

  @override
  void paint(Canvas canvas, Size size) {
    const lw = 26.0, top = 14.0;
    final ws = weeks.length > 53 ? weeks.sublist(weeks.length - 53) : weeks;
    final cw = (size.width - lw) / 53, cs = cw - 2;
    for (var x = 1; x < ws.length - 1; x++) {
      if (ws[x].isEmpty || ws[x - 1].isEmpty) continue;
      if (ws[x].first.date.month != ws[x - 1].first.date.month) {
        _text(canvas, month3(ws[x].first.date).toLowerCase(), _ts(size: 10, c: _dim, h: 1), lw + x * cw, 10);
      }
    }
    for (final (i, d) in const ['mon', 'wed', 'fri'].indexed) {
      _text(canvas, d, _ts(size: 9.5, c: _dim, h: 1), 0, top + (1 + i * 2) * cw + cs * .8);
    }
    final p = Paint();
    for (var x = 0; x < ws.length; x++) {
      for (final day in ws[x]) {
        final y = day.date.weekday % 7;
        p.color = _lv[day.level.clamp(0, 4)];
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(lw + x * cw, top + y * cw, cs, cs), const Radius.circular(1.5)),
          p,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_HeatPainter o) => o.weeks != weeks;
}

// ------------------------------------------------------------------ Shortcuts

const _keys = {
  'mic.toggle': 'm',
  'sound.toggle': 's',
  'volume.down': '-',
  'volume.up': '+',
  'screenshot': 'p',
  'terminal': 't',
  'downloads': 'd',
  'lock': 'l',
};

class _Shortcuts extends ConsumerWidget {
  const _Shortcuts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = topicData<ShortcutsData>(ref, 'shortcuts')!;
    final order = ref.watch(settingsProvider.select((x) => x.tileOrder));
    final tiles = orderedTiles(s.tiles, order);
    final rows = <List<Tile>>[];
    for (var i = 0; i < tiles.length; i += 4) {
      rows.add(tiles.sublist(i, math.min(i + 4, tiles.length)));
    }
    return _page(
      'keys',
      rows.isEmpty
          ? _pane('keys', Center(child: _t('no shortcuts configured', c: _dim)))
          : Column(
              children: [
                for (final (ri, row) in rows.indexed) ...[
                  if (ri > 0) const SizedBox(height: _rowGap),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < 4; i++) ...[
                          if (i > 0) const SizedBox(width: _colGap),
                          Expanded(
                            child: i < row.length ? _KeyCard(tile: row[i], vol: s.volumePct) : const SizedBox(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

/// Keycard: a keycap that sinks when pressed, label underneath; rose when active.
class _KeyCard extends ConsumerStatefulWidget {
  const _KeyCard({required this.tile, this.vol});
  final Tile tile;
  final int? vol;
  @override
  ConsumerState<_KeyCard> createState() => _KeyCardState();
}

class _KeyCardState extends ConsumerState<_KeyCard> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tile;
    final on = t.active;
    final key = _keys[t.id] ?? (t.label.isEmpty ? '?' : t.label[0].toLowerCase());
    final detail = t.id.startsWith('volume') && widget.vol != null ? 'volume ${widget.vol}%' : t.detail?.toLowerCase();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: () => act(context, ref, 'shortcut.run', {'id': t.id}),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: on ? _rs : (_down ? _dim : _box)),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              transform: Matrix4.translationValues(0, _down ? 2 : 0, 0),
              constraints: const BoxConstraints(minWidth: 38),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: on ? _rs : _fg,
                borderRadius: BorderRadius.circular(5),
                boxShadow: [BoxShadow(color: _dim, offset: Offset(0, _down ? 1 : 3))],
              ),
              child: SizedBox(
                height: 38,
                child: Center(
                  widthFactor: 1,
                  child: Text(key, style: _ts(size: 22, c: _bg, b: true, h: 1)),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _t(tileLabel(t).toLowerCase(), c: on ? _rs : _fg, b: true, size: 13),
                if (detail != null) _t(detail, c: _dim),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
