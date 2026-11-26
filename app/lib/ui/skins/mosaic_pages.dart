// Concept 5 — Mosaic pages. Sizes follow deskpanel-concept-5-mosaic.html (CSS px = logical px).
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/conn/controller.dart';
import '../../core/pages.dart';
import '../../core/settings.dart';
import '../fmt.dart';
import '../icons.dart';
import '../pages/kit.dart';
import '../widgets/bar_tip.dart';
import '../widgets/art.dart';
import '../widgets/aurora.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import 'mosaic.dart';

const _t = MosaicSkin.t;
const _dark = MosaicSkin.dark;
const _tile = Color(0xFF161618);
const _gap = 7.0;
const _white = Color(0xFFFFFFFF);

Color _pc(PageId p) => MosaicSkin.pageColor(p);

Widget mosaicPage(PageId id) => switch (id) {
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

TextStyle _s(
  double size, {
  FontWeight w = FontWeight.w600,
  double wdth = 100,
  Color? c,
  double h = 1.3,
  double ls = 0,
}) => TextStyle(
  fontFamily: 'Archivo',
  fontSize: size,
  fontWeight: w,
  fontVariations: [FontVariation('wght', w.value.toDouble()), FontVariation('wdth', wdth)],
  color: c ?? _t.text,
  height: h,
  letterSpacing: ls,
  leadingDistribution: TextLeadingDistribution.even,
  fontFeatures: const [FontFeature.tabularFigures()],
);

/// `.big`: tall condensed numbers.
TextStyle _bs(double size, Color c) => _s(size, w: FontWeight.w800, wdth: 62, c: c, h: .82, ls: -.005 * size);

/// `.wide`: extra-wide headings.
TextStyle _ws(double size, Color c) => _s(size, w: FontWeight.w800, wdth: 125, c: c, h: .98, ls: -.015 * size);

/// `.big` number with its `<small>` unit.
Widget _big(String v, double size, Color c, {String? unit, TextAlign? align}) => Text.rich(
  TextSpan(
    children: [
      TextSpan(text: v, style: _bs(size, c)),
      if (unit != null) ...[
        const WidgetSpan(child: SizedBox(width: 3)),
        TextSpan(
          text: unit,
          style: _s(
            size * .4,
            w: FontWeight.w700,
            wdth: 80,
            c: c.withValues(alpha: c.a * .8),
            h: .82,
          ),
        ),
      ],
    ],
  ),
  maxLines: 1,
  softWrap: false,
  textAlign: align,
);

/// Animated [_big] for numeric values.
Widget _bigN(double v, double size, Color c, {String? unit, int decimals = 0}) => TweenAnimationBuilder<double>(
  tween: Tween(end: v),
  duration: const Duration(milliseconds: 600),
  curve: Curves.easeOut,
  builder: (context, x, _) => _big(x.toStringAsFixed(decimals), size, c, unit: unit),
);

/// Scales a big number down if it would overflow its tile.
Widget _fit(Widget w, {Alignment align = Alignment.centerLeft}) =>
    FittedBox(fit: BoxFit.scaleDown, alignment: align, child: w);

// ------------------------------------------------------------------ tiles

/// Tile palette: plain (`.t`) or page-coloured (`.t.c`).
class _Ink {
  const _Ink(this.bg, this.fg, this.mu, this.track, this.fill);
  final Color bg, fg, mu, track, fill;

  factory _Ink.plain(PageId page) => _Ink(_tile, _t.text, _t.muted, const Color(0x1FFFFFFF), _pc(page));

  factory _Ink.color(PageId p) {
    final on = MosaicSkin.onColor(p);
    return _Ink(_pc(p), on, on.withValues(alpha: .72), const Color(0x29000000), on);
  }
}

Widget _tileW(_Ink k, Widget child, {VoidCallback? onTap, EdgeInsets? pad}) {
  Widget c = Container(
    padding: pad ?? const EdgeInsets.fromLTRB(16, 13, 16, 13),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(color: k.bg, borderRadius: BorderRadius.circular(22)),
    child: child,
  );
  if (onTap != null) c = Press(onTap: onTap, scale: .98, child: c);
  return c;
}

/// `.lb`: small label, optional icon, optional trailing content.
Widget _lb(String s, _Ink k, {String? icon, Widget? trailing, Color? c}) => Row(
  children: [
    if (icon != null) ...[DpIcon(icon, size: 13, color: c ?? k.mu), const SizedBox(width: 6)],
    if (trailing == null)
      Flexible(
        child: Text(
          s,
          style: _s(12.5, c: c ?? k.mu),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      )
    else ...[
      Text(s, style: _s(12.5, c: c ?? k.mu), maxLines: 1),
      const SizedBox(width: 8),
      Expanded(
        child: Align(
          alignment: Alignment.centerRight,
          child: FittedBox(fit: BoxFit.scaleDown, child: trailing),
        ),
      ),
    ],
  ],
);

Widget _mu(String s, _Ink k, {double size = 13, int lines = 1, TextAlign? align}) => Text(
  s,
  style: _s(size, c: k.mu),
  maxLines: lines,
  overflow: TextOverflow.ellipsis,
  textAlign: align,
);

Widget _bar(double p, _Ink k, {double h = 8, Color? fill}) =>
    DpBar(value: p.isFinite ? p : 0, color: fill ?? k.fill, track: k.track, height: h);

/// `.pill` button.
Widget _pill(String label, VoidCallback? onTap) => Press(
  onTap: onTap,
  child: Opacity(
    opacity: onTap == null ? .6 : 1,
    child: Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: _t.text, borderRadius: BorderRadius.circular(99)),
      child: Text(
        label,
        style: _s(13.5, w: FontWeight.w800, wdth: 110, c: _dark, h: 1),
      ),
    ),
  ),
);

/// `.circ` round control on a coloured tile.
/// Round Liquid Glass button (music controls on the aurora); [bright] is the main one.
Widget _glassCirc(String icon, VoidCallback onTap, {double size = 46, double icSize = 17, bool bright = false}) =>
    Press(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: LiquidGlass(
          tint: bright ? const Color(0x3DFFFFFF) : const Color(0x1FFFFFFF),
          child: Center(
            child: DpIcon(icon, size: icSize, color: const Color(0xFFFFFFFF), stroke: 2.2),
          ),
        ),
      ),
    );

// ------------------------------------------------------------------ grid

/// A cell of [_grid]: column/row start and span.
class _G {
  const _G(this.c, this.r, this.child, {this.cs = 1, this.rs = 1});
  final int c, r, cs, rs;
  final Widget child;
}

/// CSS-grid-like layout. Positive track values are `fr`, negative ones fixed px.
Widget _grid(List<double> cols, List<double> rows, List<_G> cells, {double gap = _gap}) => LayoutBuilder(
  builder: (context, box) {
    List<double> sizes(List<double> tr, double total) {
      var fixed = 0.0, frs = 0.0;
      for (final v in tr) {
        v < 0 ? fixed -= v : frs += v;
      }
      final free = math.max(0.0, total - gap * (tr.length - 1) - fixed);
      return [for (final v in tr) v < 0 ? -v : free * v / frs];
    }

    final cw = sizes(cols, box.maxWidth), rh = sizes(rows, box.maxHeight);
    double off(List<double> s, int i) {
      var o = 0.0;
      for (var k = 0; k < i; k++) {
        o += s[k] + gap;
      }
      return o;
    }

    double span(List<double> s, int i, int n) {
      var o = gap * (n - 1);
      for (var k = i; k < i + n; k++) {
        o += s[k];
      }
      return o;
    }

    return Stack(
      children: [
        for (final g in cells)
          Positioned(
            left: off(cw, g.c),
            top: off(rh, g.r),
            width: span(cw, g.c, g.cs),
            height: span(rh, g.r, g.rs),
            child: g.child,
          ),
      ],
    );
  },
);

// ------------------------------------------------------------------ shared bits

String _inText(CalEvent e, DateTime now) {
  if (!e.start.isAfter(now)) return 'Now';
  final d = e.start.difference(now);
  return d.inMinutes < 1 ? 'Now' : 'in ${dur(d)}';
}

String _timerDigits(Duration d) => d.inHours > 0
    ? '${d.inHours}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}'
    : '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';

String _cpuName(String m) => m.replaceFirst(RegExp(r'\s+\d+-Core.*$'), '');
String _gpuName(String? m) => (m ?? 'GPU').replaceFirst('GeForce ', '');

const _gb = 1024 * 1024 * 1024;

/// Smooth area/line chart in the tile's ink (`linePath` + fill).
class _Area extends StatelessWidget {
  const _Area(this.series, {this.max = 100});
  final List<_Line> series;
  final double max;
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _AreaPainter(series, max), size: Size.infinite);
}

class _Line {
  const _Line(this.values, this.color, {this.width = 3, this.fill});
  final List<double?> values;
  final Color color;
  final double width;
  final Color? fill;
}

class _AreaPainter extends CustomPainter {
  _AreaPainter(this.series, this.max);
  final List<_Line> series;
  final double max;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    const pad = 2.0;
    double y(double v) => pad + (h - 2 * pad) * (1 - v.clamp(0, max) / max);
    for (final s in series) {
      final vals = s.values;
      if (vals.length < 2) continue;
      final dx = w / (vals.length - 1);
      // Contiguous runs (nulls = lost samples break the line).
      final runs = <List<Offset>>[];
      var cur = <Offset>[];
      for (var i = 0; i < vals.length; i++) {
        final v = vals[i];
        if (v == null) {
          if (cur.isNotEmpty) runs.add(cur);
          cur = [];
          continue;
        }
        cur.add(Offset(i * dx, y(v)));
      }
      if (cur.isNotEmpty) runs.add(cur);
      for (final r in runs) {
        final p = Path()..moveTo(r.first.dx, r.first.dy);
        for (var i = 1; i < r.length; i++) {
          final xm = (r[i - 1].dx + r[i].dx) / 2;
          p.cubicTo(xm, r[i - 1].dy, xm, r[i].dy, r[i].dx, r[i].dy);
        }
        if (s.fill != null && r.length > 1) {
          final f = Path.from(p)
            ..lineTo(r.last.dx, h)
            ..lineTo(r.first.dx, h)
            ..close();
          canvas.drawPath(f, Paint()..color = s.fill!);
        }
        canvas.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = s.width
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round
            ..color = s.color,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_AreaPainter o) => true;
}

/// `.cols`: rounded column bars with labels; [hi] is drawn solid.
Widget _cols(List<double> values, List<String> labels, Color color, {int? hi, double gap = 8, List<double>? alphas}) {
  final mx = maxOf(values);
  return Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < values.length; i++) ...[
        if (i > 0) SizedBox(width: gap),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) => Align(
                    alignment: Alignment.bottomCenter,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: math.max(6, c.maxHeight * values[i] / mx)),
                      duration: const Duration(milliseconds: 650),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => Container(
                        height: v,
                        width: double.infinity,
                        constraints: const BoxConstraints(maxWidth: 34),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: alphas?[i] ?? (i == hi ? 1 : .5)),
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                labels[i],
                style: _s(11, w: i == hi ? FontWeight.w800 : FontWeight.w600, c: i == hi ? _t.text : _t.muted),
              ),
            ],
          ),
        ),
      ],
    ],
  );
}

// ------------------------------------------------------------------ Home

class _Home extends ConsumerWidget {
  const _Home();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void go(PageId p) => PageNav.go(context, p);
    return Ticker(
      builder: (context, now) => _grid([1, 1, 1, 1, 1, 1], [1, 1, .78], [
        _G(0, 0, _clock(ref, now, () => go(PageId.calendar)), cs: 3, rs: 2),
        _G(3, 0, _claude(ref, now, () => go(PageId.claude)), cs: 2),
        _G(5, 0, _weather(ref, () => go(PageId.weather)), rs: 2),
        _G(3, 1, _slack(ref, now, () => go(PageId.slack))),
        _G(4, 1, _laptop(ref, () => go(PageId.system))),
        _G(0, 2, _music(context, ref, () => go(PageId.music)), cs: 3),
        _G(3, 2, _streak(ref, () => go(PageId.github))),
        _G(4, 2, _focus(ref, () => go(PageId.timer))),
        _G(5, 2, _freeAfter(ref, now, () => go(PageId.calendar))),
      ]),
    );
  }

  Widget _clock(WidgetRef ref, DateTime now, VoidCallback onTap) {
    final k = _Ink.color(PageId.home);
    final h24 = ref.watch(settingsProvider.select((s) => s.clock24));
    final n = nextEvent(ref.watch(calendarEventsProvider), now);
    return _tileW(
      onTap: onTap,
      k,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _lb(longDate(now), k),
          const SizedBox(height: 8),
          _fit(_big(clock(now, h24: h24), 150, k.fg, unit: h24 ? null : ampm(now))),
          const Spacer(),
          Text(n?.title ?? 'Nothing else today', style: _ws(19, k.fg), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          _mu(
            n == null
                ? 'Free for the rest of the day'
                : '${_inText(n, now)}, ${clockFull(n.start, h24: h24)}${n.location != null ? ', ${n.location}' : ''}',
            k,
          ),
        ],
      ),
    );
  }

  Widget _claude(WidgetRef ref, DateTime now, VoidCallback onTap) {
    final k = _Ink.color(PageId.claude);
    final c = topicData<ClaudeData>(ref, 'claude');
    return _tileW(
      onTap: onTap,
      k,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _lb('5-hour limit', k, icon: 'claude'),
          const Spacer(),
          c?.fiveHour == null ? _big('—', 66, k.fg) : _bigN(limitPct(c!.fiveHour, now), 66, k.fg, unit: '%'),
          const SizedBox(height: 4),
          _mu(resetsIn(c?.fiveHour, now), k),
        ],
      ),
    );
  }

  Widget _weather(WidgetRef ref, VoidCallback onTap) {
    final k = _Ink.color(PageId.weather);
    final w = ref.watch(weatherProvider);
    final f = ref.watch(settingsProvider.select((s) => s.fahrenheit));
    return _tileW(
      onTap: onTap,
      k,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _lb(w?.place ?? 'Weather', k, icon: w?.now.icon ?? 'cloud'),
          const SizedBox(height: 10),
          _fit(_big(w == null ? '—' : '${temp(w.now.tempC, f)}°', 70, k.fg)),
          const SizedBox(height: 4),
          Text(
            w?.now.condition ?? 'Set a location',
            style: _s(13, c: k.fg),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          if (w != null)
            for (final (i, d) in w.days.skip(1).take(3).indexed) ...[
              if (i > 0) const SizedBox(height: 4),
              Row(
                children: [
                  SizedBox(
                    width: 30,
                    child: Text(
                      weekday3(d.date),
                      style: _s(12, w: FontWeight.w800, c: k.fg),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DpIcon(d.icon, size: 12, color: k.fg),
                  const Spacer(),
                  Text('${temp(d.hiC, f)}°/${temp(d.loC, f)}°', style: _s(12, c: k.fg)),
                ],
              ),
            ],
        ],
      ),
    );
  }

  /// The aubergine Slack tile: unread count, then the newest unread sender and one line.
  Widget _slack(WidgetRef ref, DateTime now, VoidCallback onTap) {
    final k = _Ink.color(PageId.slack);
    final info = slackHome(ref);
    final top = info.latest;
    final live = info.headline != 'Slack';
    final bold = _s(13.5, w: FontWeight.w800, c: k.fg, h: 1.1);
    return _tileW(
      onTap: onTap,
      k,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _lb(
            'Slack',
            k,
            icon: 'slack',
            trailing: top == null ? null : Text(slackTime(top.ts, now), style: _s(12.5, c: k.mu)),
          ),
          const Spacer(),
          live ? _fit(_bigN(info.unread.toDouble(), 48, k.fg, unit: 'unread')) : _big('—', 48, k.fg),
          const SizedBox(height: 7),
          if (top != null) ...[
            Row(
              children: [
                _avatar(top, 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(top.sender, style: bold, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 3),
            _mu(top.text, k, size: 12),
          ] else if (live) ...[
            Text(info.headline, style: bold, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            _mu(info.detail, k, size: 12),
          ] else if (info.detail != '—')
            Text(info.detail, style: bold, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  /// When today's last event ends ("Free after 5:30 PM"); once the day is clear,
  /// tomorrow's first event. The clock tile already shows the next one.
  Widget _freeAfter(WidgetRef ref, DateTime now, VoidCallback onTap) {
    final k = _Ink.color(PageId.calendar);
    final h24 = ref.watch(settingsProvider.select((s) => s.clock24));
    final timed = ref.watch(calendarEventsProvider).where((e) => !e.allDay);
    final left = timed.where((e) => sameDay(e.start, now) && e.end.isAfter(now)).toList();
    final tmrw = timed.where((e) => sameDay(e.start, DateTime(now.year, now.month, now.day + 1))).firstOrNull;
    final (String label, DateTime? at, String note) = left.isNotEmpty
        ? (
            'Free after',
            left.map((e) => e.end).reduce((a, b) => a.isAfter(b) ? a : b),
            '${left.length} ${left.length == 1 ? 'event' : 'events'} to go',
          )
        : ('Tomorrow', tmrw?.start, tmrw?.title ?? 'Nothing planned');
    return _tileW(
      onTap: onTap,
      k,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _lb(label, k, icon: 'calendar'),
          const Spacer(),
          _fit(at == null ? _big('Free', 44, k.fg) : _big(clock(at, h24: h24), 44, k.fg, unit: h24 ? null : ampm(at))),
          const SizedBox(height: 4),
          _mu(note, k, size: 12),
        ],
      ),
    );
  }

  Widget _laptop(WidgetRef ref, VoidCallback onTap) {
    final k = _Ink.color(PageId.system);
    final s = topicData<SystemData>(ref, 'system');
    Widget stat(double? v, String l) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        v == null ? _big(s == null ? '—' : 'N/A', 44, k.fg) : _bigN(v, 44, k.fg),
        const SizedBox(height: 2),
        _mu(l, k, size: 11),
      ],
    );
    return _tileW(
      onTap: onTap,
      k,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _lb('Laptop', k, icon: 'system'),
          const Spacer(),
          _fit(
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                stat(s?.cpu.pct, 'CPU %'),
                const SizedBox(width: 14),
                stat(s != null && s.gpu.available ? s.gpu.pct : null, 'GPU %'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _music(BuildContext context, WidgetRef ref, VoidCallback onTap) {
    const k = _Music._glass;
    final m = topicData<MediaData>(ref, 'media');
    final art = topicData<MediaArt>(ref, 'media.art');
    final b64 = art?.artId == m?.artId ? art?.b64 : null;
    // Same northern lights as the Music page; on Home they only move while music plays.
    return Press(
      onTap: onTap,
      scale: .98,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ArtPalette(
              b64: b64,
              builder: (context, colors) => Aurora(colors: colors, speed: .8, animate: m?.playing ?? false),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [BoxShadow(color: Color(0x4D000000), offset: Offset(0, 4))],
                      ),
                      child: AlbumArt(title: m?.title ?? 'DeskPanel', b64: b64, radius: 14),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m?.title ?? 'Nothing playing',
                          style: _ws(18, k.fg).copyWith(shadows: _Music._shadow),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        _mu(m?.artist ?? (m == null ? 'Laptop not connected' : ''), k),
                      ],
                    ),
                  ),
                  if (m?.title != null) ...[
                    const SizedBox(width: 8),
                    Center(
                      child: _glassCirc(
                        m!.playing ? 'pause' : 'play',
                        () => act(context, ref, 'media.play_pause'),
                        size: 52,
                        icSize: 20,
                        bright: true,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _streak(WidgetRef ref, VoidCallback onTap) {
    final k = _Ink.color(PageId.github);
    final g = topicData<GithubData>(ref, 'github');
    return _tileW(
      onTap: onTap,
      k,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _lb('Streak', k, icon: 'github'),
          const Spacer(),
          g == null
              ? _big('—', 44, k.fg)
              : _big('${g.streakCurrent}', 44, k.fg, unit: g.streakCurrent == 1 ? 'day' : 'days'),
        ],
      ),
    );
  }

  Widget _focus(WidgetRef ref, VoidCallback onTap) {
    final k = _Ink.color(PageId.timer);
    final st = ref.watch(timerProvider);
    return _tileW(
      onTap: onTap,
      k,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _lb(st.mode.label, k, icon: 'timer'),
          const Spacer(),
          Ticker(
            period: const Duration(seconds: 1),
            builder: (context, now) => _fit(_big(_timerDigits(st.display(now)), 44, k.fg)),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ System

/// `.tabs` on the big coloured tile.
class _Tabs extends ConsumerWidget {
  const _Tabs(this.k);
  final _Ink k;
  @override
  Widget build(BuildContext context, WidgetRef ref) => _pillTabs(
    k,
    const ['Laptop', 'Internet'],
    ref.watch(systemTabProvider),
    ref.read(systemTabProvider.notifier).set,
  );
}

/// The `.tabs` pill switch itself, for any list of options.
Widget _pillTabs(_Ink k, List<String> items, int tab, ValueChanged<int> onChanged) => Container(
  padding: const EdgeInsets.all(3),
  decoration: BoxDecoration(color: const Color(0x33000000), borderRadius: BorderRadius.circular(99)),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final (i, s) in items.indexed)
        Press(
          onTap: () => onChanged(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: i == tab ? k.fg : const Color(0x00000000),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              s,
              style: _s(12, w: FontWeight.w700, c: i == tab ? k.bg : k.fg),
            ),
          ),
        ),
    ],
  ),
);

class _System extends ConsumerWidget {
  const _System();
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(systemTabProvider) == 0 ? const _Pc() : const _Internet();
}

Widget _sideNote(String s, _Ink k) => Opacity(
  opacity: .8,
  child: Text(
    s,
    textAlign: TextAlign.right,
    style: _s(12, c: k.fg),
    maxLines: 2,
  ),
);

Widget _caption(String s, _Ink k) => Opacity(
  opacity: .8,
  child: Text(
    s,
    style: _s(11.5, c: k.fg),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  ),
);

class _Pc extends ConsumerWidget {
  const _Pc();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = topicData<SystemData>(ref, 'system')!;
    final g = s.gpu;
    final k = _Ink.color(PageId.system), p = _Ink.plain(PageId.system);
    final ramPct = s.ramUsed / s.ramTotal * 100;
    final vramPct = g.vramUsed != null && (g.vramTotal ?? 0) > 0 ? g.vramUsed! / g.vramTotal! * 100 : null;
    final (down, downU) = rate(s.downBps);
    final (up, upU) = rate(s.upBps);
    final f = ref.watch(settingsProvider).fahrenheit;
    final cpuTemp = s.cpu.tempC == null ? '' : '${temp(s.cpu.tempC!, f)}°${f ? 'F' : 'C'}, ';

    Widget small(String label, double? pct, String sub) => _tileW(
      p,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _lb(label, p),
          const Spacer(),
          pct == null ? _big('N/A', 58, p.fg) : _bigN(pct, 58, p.fg, unit: '%'),
          const SizedBox(height: 4),
          _mu(sub, p),
          const SizedBox(height: 8),
          _bar((pct ?? 0) / 100, p),
        ],
      ),
    );

    return _grid([1.15, 1.15, 1, 1], [1, 1], [
      _G(
        0,
        0,
        cs: 2,
        rs: 2,
        _tileW(
          k,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _lb('Processor', k)),
                  _Tabs(k),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _bigN(s.cpu.pct, 150, k.fg, unit: '%'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _sideNote(
                      '$cpuTemp${_cpuName(s.cpu.model)}\n${s.cpu.cores ?? '—'} cores, ${s.cpu.threads ?? s.cpu.cores ?? '—'} threads',
                      k,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _Area([
                    if (g.available) _Line(s.gpuHistory, _white.withValues(alpha: .45), width: 2.5),
                    _Line(s.cpuHistory, _white, fill: _white.withValues(alpha: .14)),
                  ]),
                ),
              ),
              const SizedBox(height: 4),
              _caption(
                g.available ? 'Processor (solid) and graphics (faint), last minute' : 'Processor, last minute',
                k,
              ),
            ],
          ),
        ),
      ),
      _G(
        2,
        0,
        small(
          'Graphics',
          g.available ? g.pct : null,
          g.available ? '${g.tempC != null ? '${g.tempC!.round()}°C, ' : ''}${_gpuName(g.model)}' : 'Not available',
        ),
      ),
      _G(3, 0, small('Memory', ramPct, '${(s.ramUsed / _gb).toStringAsFixed(1)} of ${(s.ramTotal / _gb).round()} GB')),
      _G(
        2,
        1,
        small(
          g.vramLabel,
          vramPct,
          vramPct == null
              ? 'Not available'
              : '${(g.vramUsed! / _gb).toStringAsFixed(1)} of ${(g.vramTotal! / _gb).round()} GB',
        ),
      ),
      _G(
        3,
        1,
        _tileW(
          p,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _lb('Network and disk', p),
              const Spacer(),
              _big(down, 30, p.fg, unit: '$downU down'),
              const SizedBox(height: 6),
              _big(up, 30, p.fg, unit: '$upU up'),
              const SizedBox(height: 6),
              _mu('Disk ${s.diskPct.round()}% used', p),
            ],
          ),
        ),
      ),
    ]);
  }
}

class _Internet extends ConsumerWidget {
  const _Internet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = topicData<NetworkData>(ref, 'network');
    final k = _Ink.color(PageId.system), p = _Ink.plain(PageId.system);
    if (n == null) {
      return _tileW(
        k,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _lb('Internet', k)),
                _Tabs(k),
              ],
            ),
            Expanded(
              child: Center(child: Text('Waiting for network data…', style: _ws(22, k.fg))),
            ),
          ],
        ),
      );
    }
    final live = ref.watch(agentProvider).live;
    final sys = topicData<SystemData>(ref, 'system');
    final now = DateTime.now();
    final st = n.speedtest, last = st.last, prog = st.progress;
    final shownDown = st.running ? (prog?.downBps ?? 0) : (last?.downBps ?? 0);
    final shownUp = st.running ? (prog?.upBps ?? 0) : (last?.upBps ?? 0);
    final status = !live ? 'Unknown' : (n.online ? 'Online' : 'Offline');
    final statusC = live && n.online ? _pc(PageId.github) : _pc(PageId.timer);
    // With the Mac's own traffic the right side stacks three rows: status, live, test.
    final mac = sys != null;
    final rows = mac ? <double>[1, 1, 1] : <double>[1, 1];

    final cells = [
      _G(
        0,
        0,
        cs: 2,
        rs: mac ? 3 : 2,
        _tileW(
          k,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _lb('Latency', k)),
                  _Tabs(k),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  n.latencyMs == null ? _big('—', 150, k.fg) : _bigN(n.latencyMs!, 150, k.fg, unit: 'ms'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _sideNote(
                      'Jitter ${n.jitterMs?.toStringAsFixed(1) ?? '—'} ms\n${n.lossPct.round()}% packet loss',
                      k,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _Area([
                    _Line(n.latencyHistory, _white, width: 2.5, fill: _white.withValues(alpha: .14)),
                  ], max: 50),
                ),
              ),
              const SizedBox(height: 4),
              _caption('Last 2 minutes, scale 0 to 50 ms', k),
            ],
          ),
        ),
      ),
      _G(
        2,
        0,
        _tileW(
          p,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _lb('Connection', p),
              const Spacer(),
              _fit(Text(status, style: _ws(30, statusC))),
              const SizedBox(height: 6),
              _mu(
                '${n.onlineSince != null ? 'Up ${durLong(now.difference(n.onlineSince!))}.' : ''}'
                '${n.lastDrop != null ? ' Last drop ${ago(now.difference(n.lastDrop!))}.' : ''}',
                p,
                lines: 2,
              ),
            ],
          ),
        ),
      ),
      _G(
        3,
        0,
        _tileW(
          p,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _lb('Data used', p),
              const Spacer(),
              _fit(
                Builder(
                  builder: (context) {
                    final parts = bytes(n.usageToday).split(' ');
                    return _big(parts.first, 44, p.fg, unit: '${parts.last} today');
                  },
                ),
              ),
              const SizedBox(height: 6),
              _mu('${bytes(n.usageMonth, digits: 0)} this month', p),
            ],
          ),
        ),
      ),
      if (mac) _G(2, 1, cs: 2, _MacNet(sys, p)),
      _G(
        2,
        mac ? 2 : 1,
        cs: 2,
        _tileW(
          p,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _lb(
                'Speed test',
                p,
                trailing: _mu(
                  st.running
                      ? 'Testing now'
                      : (last == null
                            ? 'Never tested'
                            : 'Tested ${ago(now.difference(last.at))}, ping ${last.pingMs.round()} ms'),
                  p,
                ),
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _fit(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _big(mbps(shownDown), 50, p.fg, unit: 'down'),
                          const SizedBox(width: 20),
                          _big(mbps(shownUp), 50, p.fg, unit: 'up'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _pill(
                    st.running ? 'Testing…' : 'Run test',
                    st.running
                        ? null
                        : () => act(context, ref, 'speedtest.run', const {}, null, null, const Duration(seconds: 90)),
                  ),
                ],
              ),
              if (st.running) ...[const SizedBox(height: 10), _bar((prog?.pct ?? 0) / 100, p)],
            ],
          ),
        ),
      ),
    ];
    return _grid([1.15, 1.15, 1, 1], rows, cells);
  }
}

/// What the Mac is moving right now: down and up as big numbers, the last minute as a
/// smooth area chart beside them (down in the page colour, up faint white).
class _MacNet extends StatelessWidget {
  const _MacNet(this.s, this.k);
  final SystemData s;
  final _Ink k;

  @override
  Widget build(BuildContext context) {
    final (down, downU) = rate(s.downBps);
    final (up, upU) = rate(s.upBps);
    final hi = maxOf([...s.downHistory, ...s.upHistory, s.downBps, s.upBps], floor: 64 * 1024) * 1.1;
    return _tileW(
      k,
      Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 132,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _lb('This Mac now', k),
                const Spacer(),
                _fit(_big(down, 34, k.fg, unit: '$downU down')),
                const SizedBox(height: 7),
                _fit(_big(up, 34, k.fg, unit: '$upU up')),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: s.downHistory.length < 2
                      ? Center(child: _mu('Collecting…', k))
                      : _Area([
                          _Line(s.upHistory, _white.withValues(alpha: .5), width: 2),
                          _Line(s.downHistory, k.fill, width: 2.5, fill: k.fill.withValues(alpha: .22)),
                        ], max: hi),
                ),
                const SizedBox(height: 4),
                _mu('Down (solid) and up (faint), last minute', k, size: 11.5),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ Claude

class _Claude extends ConsumerWidget {
  const _Claude();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = topicData<ClaudeData>(ref, 'claude')!;
    final h24 = ref.watch(settingsProvider.select((s) => s.clock24));
    final k = _Ink.color(PageId.claude), p = _Ink.plain(PageId.claude);
    final yellow = _pc(PageId.hotspot);
    return Ticker(
      builder: (context, now) {
        final five = limitPct(c.fiveHour, now), week = limitPct(c.sevenDay, now);
        final fw = c.fiveHour;
        final resetTail = fw == null || fw.resetsAt == null
            ? null
            : (fw.isExpired(now) ? null : dur(fw.resetsAt!.difference(now)));
        Widget kv(String key, String v) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_big(v, 30, p.fg), const SizedBox(height: 2), _mu(key, p, size: 11)],
        );
        return _grid([1.1, 1.1, 1, 1], [1, 1], [
          _G(
            0,
            0,
            cs: 2,
            rs: 2,
            _tileW(
              k,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _lb('5-hour limit', k, icon: 'claude'),
                  const Spacer(),
                  _fit(fw == null ? _big('—', 250, k.fg) : _bigN(five, 250, k.fg, unit: '%')),
                  const SizedBox(height: 10),
                  _bar(five / 100, k, h: 12),
                  const SizedBox(height: 10),
                  resetTail == null
                      ? Text(resetsIn(fw, now), style: _s(14, c: k.fg))
                      : Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Resets in  ',
                                style: _s(14, c: k.fg),
                              ),
                              TextSpan(
                                text: resetTail,
                                style: _s(14, w: FontWeight.w800, c: k.fg),
                              ),
                            ],
                          ),
                        ),
                ],
              ),
            ),
          ),
          _G(
            2,
            0,
            _tileW(
              p,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _lb('Weekly limit', p),
                  const Spacer(),
                  c.sevenDay == null ? _big('—', 62, yellow) : _bigN(week, 62, yellow, unit: '%'),
                  const SizedBox(height: 4),
                  _mu(resetsAt(c.sevenDay, now, h24: h24), p),
                  const SizedBox(height: 8),
                  _bar(week / 100, p, fill: yellow),
                ],
              ),
            ),
          ),
          _G(
            3,
            0,
            _tileW(
              p,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _lb('Today', p),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: kv('Tokens', compact(c.tokens))),
                      const SizedBox(width: 12),
                      Expanded(child: kv('Output', compact(c.outputTokens))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: kv('Messages', '${c.messages}')),
                      const SizedBox(width: 12),
                      Expanded(child: kv('Last hour', compact(c.lastHourTokens))),
                    ],
                  ),
                ],
              ),
            ),
          ),
          _G(
            2,
            1,
            cs: 2,
            _tileW(
              p,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _lb(
                    'Last 7 days',
                    p,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final (i, m) in c.modelsToday.take(3).indexed) ...[
                          if (i > 0) const SizedBox(width: 10),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '${modelName(m.family)} ',
                                  style: _s(12.5, c: p.fg),
                                ),
                                TextSpan(
                                  text: compact(m.tokens),
                                  style: _s(12.5, c: p.mu),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: c.days.isEmpty
                        ? Center(child: _mu('No usage recorded yet', p))
                        : BarTapTip(
                            count: c.days.length,
                            label: (i) => dayTokensLabel(c.days[i], now),
                            child: _cols(
                              [for (final d in c.days) d.tokens.toDouble()],
                              [for (final d in c.days) dayLabel(d.date, now)],
                              _pc(PageId.claude),
                              hi: c.days.length - 1,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ]);
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
    final k = _Ink.color(PageId.calendar), p = _Ink.plain(PageId.calendar);
    return Ticker(
      builder: (context, now) {
        final split = splitEvents(events, now);
        final n = nextEvent(events, now);
        final others = split.today.where((e) => e != n && e.end.isAfter(now)).take(2).toList();

        Widget other(CalEvent e) {
          final t = clockFull(e.start, h24: h24).split(' ');
          return _tileW(
            p,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _lb(e.calendar ?? 'Today', p, c: hex(e.color, _pc(PageId.calendar))),
                const Spacer(),
                _fit(
                  e.allDay ? _big('All day', 42, p.fg) : _big(t.first, 42, p.fg, unit: t.length > 1 ? t.last : null),
                ),
                const SizedBox(height: 6),
                Text(e.title, style: _ws(16, p.fg), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                _mu([if (e.location != null) e.location!, 'until ${clockFull(e.end, h24: h24)}'].join(', '), p),
              ],
            ),
          );
        }

        final later = split.later.take(3).toList();
        return _grid([1.1, 1.1, 1, 1], [1, 1], [
          _G(
            0,
            0,
            cs: 2,
            rs: 2,
            _tileW(
              k,
              n == null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _lb('Today, ${longDate(now)}', k),
                        const Spacer(),
                        Text('All clear', style: _ws(40, k.fg)),
                        const SizedBox(height: 10),
                        Text('Nothing else on the calendar today.', style: _s(14, c: k.fg)),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _lb('Next up,  ${longDate(now)}', k),
                        const SizedBox(height: 14),
                        Text(n.title, style: _ws(40, k.fg), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const Spacer(),
                        _fit(_big(_inText(n, now), 130, k.fg)),
                        const SizedBox(height: 10),
                        Text(
                          '${n.allDay ? 'All day' : '${clockFull(n.start, h24: h24)} to ${clockFull(n.end, h24: h24)}'}'
                          '${n.location != null ? ', ${n.location}' : ''}',
                          style: _s(14, c: k.fg),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
            ),
          ),
          if (others.length == 2) ...[
            _G(2, 0, other(others[0])),
            _G(3, 0, other(others[1])),
          ] else if (others.length == 1)
            _G(2, 0, cs: 2, other(others[0]))
          else
            _G(
              2,
              0,
              cs: 2,
              _tileW(
                p,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _lb('Rest of today', p),
                    const Spacer(),
                    Text('Nothing else today', style: _ws(22, p.fg)),
                  ],
                ),
              ),
            ),
          _G(
            2,
            1,
            cs: 2,
            _tileW(
              p,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _lb('Later this week', p),
                  const Spacer(),
                  if (later.isEmpty) _mu('No more events in the next 7 days', p),
                  for (final (i, e) in later.indexed)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        border: i == 0 ? null : const Border(top: BorderSide(color: Color(0x1AFFFFFF))),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.title,
                                  style: _s(13, w: FontWeight.w800),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                _mu(e.location ?? e.calendar ?? '', p),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(weekday(e.start), style: _s(13)),
                              _mu(e.allDay ? 'All day' : clockFull(e.start, h24: h24), p),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ]);
      },
    );
  }
}

// ------------------------------------------------------------------ Weather

class _Weather extends ConsumerWidget {
  const _Weather();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(weatherProvider);
    final s = ref.watch(settingsProvider);
    final k = _Ink.color(PageId.weather), p = _Ink.plain(PageId.weather);
    if (w == null) {
      return _tileW(k, Center(child: Text('Set your location in Settings', style: _ws(24, k.fg))));
    }
    final f = s.fahrenheit;
    final sky = _pc(PageId.weather);
    String hourLabel(int i, DateTime t) {
      if (i == 0) return 'Now';
      if (s.clock24) return '${two(t.hour)}:00';
      return '${t.hour % 12 == 0 ? 12 : t.hour % 12} ${ampm(t)}';
    }

    return _grid([1, 1.6], [1, 1], [
      _G(
        0,
        0,
        rs: 2,
        _tileW(
          k,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _lb('${w.place}, updated ${clockFull(w.now.updated, h24: s.clock24)}', k, icon: w.now.icon),
              const Spacer(),
              _fit(_big('${temp(w.now.tempC, f)}°', 220, k.fg)),
              const SizedBox(height: 8),
              Text(w.now.condition, style: _ws(24, k.fg), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Text(
                'Feels like ${temp(w.now.feelsC, f)}°. Humidity ${w.now.humidity}%. Wind ${wind(w.now.windKmh, f)}.',
                style: _s(13, c: k.fg),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      _G(
        1,
        0,
        _tileW(
          p,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _lb('Next 12 hours', p),
              Expanded(
                child: Center(
                  child: Row(
                    children: [
                      for (final (i, h) in w.hours.take(12).indexed)
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(hourLabel(i, h.time), style: _s(11, c: p.mu), maxLines: 1, softWrap: false),
                              const SizedBox(height: 6),
                              DpIcon(h.icon, size: 18, color: sky),
                              const SizedBox(height: 6),
                              Text('${temp(h.tempC, f)}°', style: _s(21, w: FontWeight.w800, wdth: 62)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      _G(
        1,
        1,
        _tileW(
          p,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _lb('This week', p),
              Expanded(
                child: Center(
                  child: Row(
                    children: [
                      for (final (i, d) in w.days.take(6).indexed)
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(i == 0 ? 'Today' : weekday3(d.date), style: _s(11.5, c: p.mu)),
                              const SizedBox(height: 6),
                              DpIcon(d.icon, size: 20, color: p.fg),
                              const SizedBox(height: 6),
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '${temp(d.hiC, f)}° ',
                                      style: _s(24, w: FontWeight.w800, wdth: 62),
                                    ),
                                    TextSpan(
                                      text: '${temp(d.loC, f)}°',
                                      style: _s(16.8, w: FontWeight.w800, wdth: 62, c: p.mu),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 2),
                              SizedBox(
                                height: 15,
                                child: Text(
                                  d.precipPct > 0 ? '${d.precipPct}% rain' : '',
                                  style: _s(11.5, w: FontWeight.w700, c: sky),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ]);
  }
}

// ------------------------------------------------------------------ Music

class _Music extends ConsumerWidget {
  const _Music();

  /// Text and controls on the aurora: white, like Apple Music's lyrics/now-playing views.
  static const _glass = _Ink(
    Color(0x00000000),
    Color(0xFFFFFFFF),
    Color(0xC7FFFFFF),
    Color(0x33FFFFFF),
    Color(0xFFFFFFFF),
  );
  // Hard, offset shadows only: anything blurred over the moving aurora would be re-blurred
  // every frame (Impeller has no raster cache), which costs far more than the lights.
  static const _shadow = [Shadow(color: Color(0x59000000), offset: Offset(0, 1.5))];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = topicData<MediaData>(ref, 'media')!;
    final art = topicData<MediaArt>(ref, 'media.art');
    final skew = ref.read(agentProvider.notifier).clockSkewMs;
    final b64 = art?.artId == m.artId ? art?.b64 : null;
    const k = _glass;
    // The tile is the stage: northern lights in the album's colours, glass controls on top.
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ArtPalette(
            b64: b64,
            builder: (context, colors) => Aurora(colors: colors, speed: m.playing ? 1 : .35),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [BoxShadow(color: Color(0x4D000000), offset: Offset(0, 6))],
                    ),
                    child: AlbumArt(title: m.title ?? 'Nothing playing', b64: b64, radius: 18),
                  ),
                ),
                const SizedBox(width: 28),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 6, 6, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _lb(m.source ?? 'Laptop', k, icon: 'music'),
                        const Spacer(),
                        Text(
                          m.title ?? 'Nothing playing',
                          style: _ws(38, k.fg).copyWith(shadows: _shadow),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        if (m.artist != null)
                          Text(
                            m.artist!,
                            style: _s(17, c: k.fg).copyWith(shadows: _shadow),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (m.album != null)
                          Text(
                            m.album!,
                            style: _s(13, c: k.mu),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 22),
                        Ticker(
                          period: const Duration(seconds: 1),
                          builder: (context, now) {
                            final pos = m.positionNow(now, skewMs: skew);
                            final total = m.durationMs ?? 0;
                            return Column(
                              children: [
                                _SeekBar(
                                  value: total == 0 ? 0 : pos / total,
                                  enabled: m.canSeek && total > 0,
                                  ink: k,
                                  onSeek: (f) => act(context, ref, 'media.seek', {'position_ms': (f * total).round()}),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Text(
                                      mmss(pos),
                                      style: _s(12, w: FontWeight.w700, c: k.mu),
                                    ),
                                    const Spacer(),
                                    Text(
                                      total == 0 ? '' : '-${mmss(math.max(0, total - pos))}',
                                      style: _s(12, w: FontWeight.w700, c: k.mu),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _glassCirc('prev', () => act(context, ref, 'media.prev')),
                            const SizedBox(width: 12),
                            _glassCirc(
                              m.playing ? 'pause' : 'play',
                              () => act(context, ref, 'media.play_pause'),
                              size: 64,
                              icSize: 24,
                              bright: true,
                            ),
                            const SizedBox(width: 12),
                            _glassCirc('next', () => act(context, ref, 'media.next')),
                          ],
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

/// Tap / drag to seek. Shows the drag position immediately, sends one seek on release.
class _SeekBar extends StatefulWidget {
  const _SeekBar({required this.value, required this.onSeek, required this.enabled, required this.ink});
  final double value;
  final bool enabled;
  final _Ink ink;
  final ValueChanged<double> onSeek;
  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _drag;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      double f(Offset p) => (p.dx / c.maxWidth).clamp(0.0, 1.0);
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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: _bar(_drag ?? widget.value, widget.ink, h: 10),
        ),
      );
    },
  );
}

// ------------------------------------------------------------------ Hotspot

/// The Hotspot Monitor Overview (the roof phone sharing mobile data): a tall yellow
/// tile with the state and the speed (red with the alert when something is wrong),
/// small plain tiles for the rest, the newest events along the bottom.
class _Hotspot extends ConsumerWidget {
  const _Hotspot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = topicData<HotspotData>(ref, 'hotspot')!;
    final f = ref.watch(settingsProvider.select((s) => s.fahrenheit));
    final p = _Ink.plain(PageId.hotspot);
    return Ticker(
      builder: (context, now) => _grid([1.45, 1, 1, 1], [1.12, 1, 1], [
        _G(0, 0, rs: 3, _hero(d, now)),
        _G(1, 0, _signal(d, p)),
        _G(2, 0, _battery(d, p)),
        _G(3, 0, _temp(d, p, f)),
        _G(1, 1, cs: 2, _data(d, p)),
        _G(3, 1, _uptime(d, p)),
        _G(1, 2, cs: 3, _events(d, p, now)),
      ]),
    );
  }

  static final _red = _pc(PageId.timer);

  Widget _hero(HotspotData d, DateTime now) {
    final alert = hsAlert(d, now);
    final k = alert == null
        ? _Ink.color(PageId.hotspot)
        : _Ink(_red, _dark, _dark.withValues(alpha: .72), const Color(0x29000000), _dark);
    final (dn, dnU) = hsBpsParts(d.rxBps);
    final (up, upU) = hsBpsParts(d.txBps);
    return _tileW(
      k,
      pad: const EdgeInsets.fromLTRB(18, 14, 16, 16),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _lb(
            d.name ?? 'Hotspot',
            k,
            icon: 'hotspot',
            trailing: Text(hsSeen(d, now), style: _s(12.5, c: k.mu)),
          ),
          const SizedBox(height: 10),
          _fit(Text(hsStateLabel(d), style: _ws(30, k.fg))),
          const SizedBox(height: 6),
          if (alert != null) ...[
            Text(
              alert,
              style: _s(14.5, w: FontWeight.w700, c: k.fg, h: 1.25),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
          ],
          _mu([hsNetwork(d), ?d.operator].join(' · '), k, size: 13.5),
          _mu(hsSharing(d), k, size: 13.5),
          const Spacer(),
          _lb('Speed now', k),
          const SizedBox(height: 6),
          _fit(_big(dn, 92, k.fg, unit: '$dnU down')),
          const SizedBox(height: 8),
          _fit(_big(up, 40, k.fg, unit: '$upU up')),
          const SizedBox(height: 8),
          _caption(hsPingLine(d), k),
        ],
      ),
    );
  }

  /// A small plain tile: label (+ trailing), number, then up to [lines] of small print.
  Widget _small(_Ink p, String label, Widget number, {Widget? trailing, Widget? extra, String? note, int lines = 2}) =>
      _tileW(
        p,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _lb(label, p, trailing: trailing),
            const Spacer(),
            _fit(number),
            const SizedBox(height: 5),
            ?extra,
            if (note != null) _mu(note, p, size: 11.5, lines: lines),
          ],
        ),
      );

  Widget _signal(HotspotData d, _Ink p) {
    final c = hsGradeColor(d.grade, _t);
    return _small(
      p,
      'Signal',
      d.score == null ? _big('—', 44, p.fg) : _bigN(d.score!, 44, c, unit: '/100'),
      trailing: Text(
        hsGradeLabel(d.grade),
        style: _s(12.5, w: FontWeight.w800, c: c),
      ),
      extra: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: _bar((d.score ?? 0) / 100, p, h: 6, fill: c),
      ),
      note: hsSignalLine(d),
    );
  }

  Widget _battery(HotspotData d, _Ink p) => _small(
    p,
    'Battery',
    d.batteryPct == null ? _big('—', 44, p.fg) : _bigN(d.batteryPct!, 44, d.lowBattery ? _red : p.fg, unit: '%'),
    trailing: Text(
      hsCurrent(d.currentMa),
      style: _s(12.5, w: FontWeight.w700, c: p.fg),
    ),
    note: hsPowerLine(d),
  );

  Widget _temp(HotspotData d, _Ink p, bool f) {
    final c = switch (d.heat) {
      HotspotHeat.hot => _red,
      HotspotHeat.warm => _t.warn,
      HotspotHeat.ok => p.fg,
    };
    final (v, u) = switch (hsTemp(d.batteryC, fahrenheit: f).split(' ')) {
      [final a, final b] => (a, b),
      final l => (l.first, null),
    };
    return _small(
      p,
      'Temperature',
      _big(v, 44, c, unit: u),
      trailing: d.heat == HotspotHeat.ok
          ? null
          : Text(
              d.heat == HotspotHeat.hot ? 'Hot' : 'Warm',
              style: _s(12.5, w: FontWeight.w800, c: c),
            ),
      extra: d.radioResting
          ? Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: _red, borderRadius: BorderRadius.circular(99)),
              child: Text(
                'Radio resting',
                style: _s(11.5, w: FontWeight.w800, c: _dark),
              ),
            )
          : null,
      note: hsHeatLine(d, fahrenheit: f),
      lines: d.radioResting ? 1 : 2,
    );
  }

  Widget _data(HotspotData d, _Ink p) {
    final q = d.quotaFrac;
    final c = q == null || q < .8 ? p.fg : (q >= 1 ? _red : _t.warn);
    final (v, u) = hsBytesParts(d.cycleUsed);
    return _tileW(
      p,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _lb(
            'Data this cycle',
            p,
            trailing: Text(
              q == null ? 'No quota' : '${(q * 100).round()}% of ${hsBytes(d.quota)}',
              style: _s(12.5, w: FontWeight.w700, c: q == null ? p.mu : c),
            ),
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _fit(_big(v, 44, c, unit: u)),
              const SizedBox(width: 12),
              Expanded(child: _mu(hsTodayLine(d), p, size: 12)),
            ],
          ),
          if (q != null) ...[const SizedBox(height: 8), _bar(q.clamp(0.0, 1.0), p, h: 8, fill: c)],
        ],
      ),
    );
  }

  Widget _uptime(HotspotData d, _Ink p) => _small(
    p,
    'Uptime',
    _big(hsUptime(d.uptimeS), 44, p.fg),
    extra: _mu('Agent ${hsUptime(d.agentUptimeS)}', p, size: 12.5),
    note: hsBootLine(d),
    lines: 1,
  );

  Widget _events(HotspotData d, _Ink p, DateTime now) {
    final foot = [?hsSessionNote(d, now), ?d.model].join(' · ');
    return _tileW(
      p,
      pad: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _lb(
            'Latest events',
            p,
            icon: 'clock',
            trailing: foot.isEmpty ? null : Text(foot, style: _s(12, c: p.mu)),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: d.events.isEmpty
                ? Align(alignment: Alignment.topLeft, child: _mu('Nothing has happened lately', p))
                : LayoutBuilder(
                    builder: (context, box) {
                      const rowH = 21.0;
                      final n = math.min(d.events.length, (box.maxHeight / rowH).floor());
                      return Column(
                        children: [
                          for (final e in d.events.take(n))
                            SizedBox(
                              height: rowH,
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: e.severity == 'info' ? const Color(0x00000000) : hsEventColor(e, _t),
                                      shape: BoxShape.circle,
                                      border: e.severity == 'info' ? Border.all(color: _t.faint, width: 1.5) : null,
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  SizedBox(
                                    width: 36,
                                    child: Text(
                                      slackTime(e.ts, now),
                                      style: _s(
                                        12,
                                        w: FontWeight.w800,
                                        c: e.severity == 'info' ? p.mu : hsEventColor(e, _t),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      e.message,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: _s(
                                        13.5,
                                        w: FontWeight.w600,
                                        c: e.severity == 'info' ? _t.text : hsEventColor(e, _t),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ Timer

class _Timer extends ConsumerWidget {
  const _Timer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(timerProvider);
    final ctl = ref.read(timerProvider.notifier);
    final k = _Ink.color(PageId.timer), p = _Ink.plain(PageId.timer);
    final red = _pc(PageId.timer);
    String sub(TimerMode m) => switch (m) {
      TimerMode.stopwatch => 'Count up',
      TimerMode.countdown => '${st.countdownMin} min',
      _ => '${m.defaultMin} min',
    };
    Widget small(String s, VoidCallback onTap) => Press(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x24000000)),
        alignment: Alignment.center,
        child: Text(
          s,
          style: _s(17, w: FontWeight.w800, c: k.fg, h: 1),
        ),
      ),
    );
    return _grid([3, 1], [1, 1, 1, 1, 1, 1], [
      _G(
        0,
        0,
        rs: 6,
        _tileW(
          k,
          Ticker(
            period: const Duration(milliseconds: 250),
            builder: (context, now) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _lb(st.mode.label, k, icon: 'timer')),
                    if (st.mode == TimerMode.countdown && !st.running) ...[
                      small('−', () => ctl.adjust(-1)),
                      const SizedBox(width: 8),
                      Text(
                        '${st.countdownMin} min',
                        style: _s(13, w: FontWeight.w700, c: k.fg),
                      ),
                      const SizedBox(width: 8),
                      small('+', () => ctl.adjust(1)),
                    ],
                    if (st.mode.isPomodoro) ...[
                      for (var i = 0; i < 4; i++)
                        Container(
                          width: 18,
                          height: 6,
                          margin: const EdgeInsets.only(left: 4),
                          decoration: BoxDecoration(
                            color: i < st.sessions ? k.fg : const Color(0x29000000),
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                      const SizedBox(width: 8),
                      _mu('${st.sessions} of 4 sessions', k, size: 12),
                    ],
                  ],
                ),
                Expanded(
                  child: Center(child: _fit(_big(_timerDigits(st.display(now)), 265, k.fg), align: Alignment.center)),
                ),
                _bar(st.progress(now), k, h: 10),
              ],
            ),
          ),
        ),
      ),
      for (final (i, m) in TimerMode.values.indexed)
        _G(
          1,
          i,
          Press(
            onTap: () => ctl.setMode(m),
            scale: .98,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: BoxDecoration(color: m == st.mode ? _t.text : _tile, borderRadius: BorderRadius.circular(22)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _lb(sub(m), p, c: m == st.mode ? _dark : null),
                  const Spacer(),
                  Text(
                    m.label,
                    style: _ws(16, m == st.mode ? _dark : _t.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      _G(
        1,
        5,
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Press(
                onTap: ctl.toggle,
                scale: .98,
                child: Container(
                  decoration: BoxDecoration(color: red, borderRadius: BorderRadius.circular(22)),
                  alignment: Alignment.center,
                  child: Text(st.running ? 'Pause' : (st.pristine ? 'Start' : 'Resume'), style: _ws(16, _dark)),
                ),
              ),
            ),
            const SizedBox(width: _gap),
            Press(
              onTap: ctl.reset,
              scale: .98,
              child: Container(
                width: 50,
                decoration: BoxDecoration(color: _tile, borderRadius: BorderRadius.circular(22)),
                alignment: Alignment.center,
                child: DpIcon('reset', size: 18, color: _t.text, stroke: 2),
              ),
            ),
          ],
        ),
      ),
    ]);
  }
}

// ------------------------------------------------------------------ Slack

/// Sender avatar: initials on a rounded square in the sender's colour.
Widget _avatar(SlackMsg m, double size) {
  final bg = hex(m.senderColor, _pc(PageId.slack));
  return Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size * .3)),
    child: Text(
      m.initials,
      maxLines: 1,
      style: _s(size * .38, w: FontWeight.w800, wdth: 110, c: bg.computeLuminance() > .4 ? _dark : _white, h: 1),
    ),
  );
}

class _Slack extends ConsumerWidget {
  const _Slack();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = topicData<SlackData>(ref, 'slack')!;
    return Ticker(
      builder: (context, now) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 50, child: _hero(context, ref, s, now)),
          const SizedBox(width: _gap),
          Expanded(
            flex: 58,
            child: s.messages.isEmpty
                ? _tileW(_Ink.plain(PageId.slack), Center(child: _mu('No recent messages', _Ink.plain(PageId.slack))))
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: s.messages.length,
                    separatorBuilder: (_, _) => const SizedBox(height: _gap),
                    itemBuilder: (context, i) => _row(context, ref, s.messages[i], now),
                  ),
          ),
        ],
      ),
    );
  }

  /// The big aubergine tile: unread count and the newest unread message.
  Widget _hero(BuildContext context, WidgetRef ref, SlackData s, DateTime now) {
    final k = _Ink.color(PageId.slack);
    final top = s.unreadMessages.firstOrNull;
    return _tileW(
      k,
      onTap: top == null ? null : () => slackOpen(context, ref, top),
      pad: const EdgeInsets.fromLTRB(18, 14, 16, 16),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _lb(
            'Slack',
            k,
            icon: 'slack',
            trailing: s.team == null ? null : Text(s.team!, style: _s(12.5, c: k.mu)),
          ),
          const SizedBox(height: 8),
          if (top == null) ...[
            _fit(_big('0', 116, k.fg, unit: 'unread')),
            const Spacer(),
            Text('All caught up', style: _ws(30, k.fg), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            _mu(s.messages.isEmpty ? 'No recent messages' : 'Nothing new since you last looked', k, size: 13.5),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: _fit(_bigN(s.unread.toDouble(), 116, k.fg, unit: 'unread'))),
                const SizedBox(width: 12),
                _pill('Mark all read', () => slackReadAll(context, ref)),
              ],
            ),
            const SizedBox(height: 14),
            _senders(s.unreadMessages, k),
            const Spacer(),
            Row(
              children: [
                _avatar(top, 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(top.sender, style: _ws(19, k.fg), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      _mu('${slackWhere(top)}  ·  ${slackTime(top.ts, now)}', k),
                    ],
                  ),
                ),
                SlackReadTick(top, color: k.fg, fill: k.fg, onFill: k.bg, size: 30, hit: 44),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              top.text,
              style: _s(17, w: FontWeight.w600, c: k.fg, h: 1.3),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  /// Who's waiting: overlapping avatars of the unread senders, then their first names.
  Widget _senders(List<SlackMsg> unread, _Ink k) {
    final seen = <String>{};
    final who = [
      for (final m in unread)
        if (seen.add(m.sender)) m,
    ];
    final names = [for (final m in who) m.sender.split(' ').first];
    final text = names.length <= 3
        ? names.length == 1
              ? 'From ${names.first}'
              : 'From ${names.sublist(0, names.length - 1).join(', ')} and ${names.last}'
        : 'From ${names.take(3).join(', ')} and ${names.length - 3} more';
    return Row(
      children: [
        for (final m in who.take(4)) ...[_avatar(m, 30), const SizedBox(width: 5)],
        const SizedBox(width: 7),
        Expanded(child: _mu(text, k, size: 13.5, lines: 2)),
      ],
    );
  }

  /// One message as its own small tile; read ones sit back on the plain tile colour.
  Widget _row(BuildContext context, WidgetRef ref, SlackMsg m, DateTime now) {
    final k = _Ink.plain(PageId.slack);
    final fg = m.unread ? _t.text : _t.muted;
    return Press(
      onTap: () => slackOpen(context, ref, m),
      scale: .98,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
        decoration: BoxDecoration(
          color: m.unread ? const Color(0xFF26262A) : _tile,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Opacity(opacity: m.unread ? 1 : .45, child: _avatar(m, 38)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: m.sender,
                                style: _s(14, w: m.unread ? FontWeight.w800 : FontWeight.w600, c: fg),
                              ),
                              TextSpan(
                                text: '   ${slackWhere(m)}',
                                style: _s(12, c: k.mu),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: slackTime(m.ts, now),
                              style: _s(
                                12,
                                w: m.unread ? FontWeight.w800 : FontWeight.w600,
                                c: m.unread ? _unreadDot : k.mu,
                              ),
                            ),
                            if (m.unread)
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Container(
                                  width: 9,
                                  height: 9,
                                  margin: const EdgeInsets.only(left: 7),
                                  decoration: const BoxDecoration(color: _unreadDot, shape: BoxShape.circle),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    m.text,
                    style: _s(13, w: FontWeight.w500, c: m.unread ? _t.text : _t.faint, h: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Transform.translate(
              offset: const Offset(6, 0),
              child: SlackReadTick(m, color: _unreadDot, fill: _unreadDot, onFill: const Color(0xFF26262A)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Unread marker on the dark list tiles: the aubergine is too dark to read as a dot
/// on #26262A, so a lighter orchid of the same hue.
const _unreadDot = Color(0xFFE08AE2);

// ------------------------------------------------------------------ GitHub

class _Github extends ConsumerWidget {
  const _Github();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = topicData<GithubData>(ref, codeTopic(ref))!;
    final k = _Ink.color(PageId.github), p = _Ink.plain(PageId.github);
    final green = _pc(PageId.github);
    final now = DateTime.now();
    final today = now.weekday % 7;
    final topRepo = maxOf(g.topRepos.map((r) => r.count));
    final best = g.bestDay;
    return LayoutBuilder(
      builder: (context, box) {
        // Row 1 is `auto`: the heatmap's height follows its width.
        final fr = (box.maxWidth - 3 * _gap) / 4.4;
        final heatW = 3.4 * fr + 2 * _gap - 32;
        final topH = 26 + 16.25 + 8 + 13 + 7 * heatW / 53;
        return _grid([1, 1.2, 1.2, 1], [-topH, 1], [
          _G(
            0,
            0,
            rs: 2,
            _tileW(
              k,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _lb('Streak', k, icon: 'github'),
                  const SizedBox(height: 10),
                  _pillTabs(k, codeSources, ref.watch(codeSourceProvider), ref.read(codeSourceProvider.notifier).set),
                  const Spacer(),
                  _fit(_bigN(g.streakCurrent.toDouble(), 170, k.fg)),
                  const SizedBox(height: 6),
                  Text(g.streakCurrent == 1 ? 'day in a row' : 'days in a row', style: _ws(16, k.fg)),
                  const SizedBox(height: 8),
                  Opacity(
                    opacity: .8,
                    child: Text(
                      'Longest ${g.streakLongest}.${best == null ? '' : ' Best day ${best.count} on ${month3(best.date)} ${best.date.day}.'}',
                      style: _s(12.5, c: k.fg),
                      maxLines: 3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _G(
            1,
            0,
            cs: 3,
            _tileW(
              p,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _lb(
                    'Last year',
                    p,
                    trailing: _mu(
                      '${_thousands(g.total)} contributions, ${g.commits} commits, ${g.private} private',
                      p,
                      size: 12.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(child: _Heat(g.weeks)),
                ],
              ),
            ),
          ),
          _G(
            1,
            1,
            cs: 2,
            _tileW(
              p,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _lb(
                    'This week',
                    p,
                    trailing: Text(
                      '${g.weekDelta >= 0 ? '+' : ''}${g.weekDelta}',
                      style: _s(12.5, c: g.weekDelta >= 0 ? green : p.mu),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _bigN(g.weekTotal.toDouble(), 40, p.fg),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _cols(
                      [
                        for (var i = 0; i < 7; i++)
                          i > today ? 0 : ((i < g.thisWeek.length ? g.thisWeek[i] : null) ?? 0).toDouble(),
                      ],
                      [for (var i = 0; i < 7; i++) 'SMTWTFS'[i]],
                      green,
                      hi: today,
                      gap: 5,
                      alphas: [for (var i = 0; i < 7; i++) i == today ? 1 : .55],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _G(
            3,
            1,
            _tileW(
              p,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _lb(topReposLabel(ref), p),
                  const Spacer(),
                  if (g.topRepos.isEmpty) _mu('No pushes yet', p),
                  for (final (i, r) in g.topRepos.take(4).indexed) ...[
                    if (i > 0) const SizedBox(height: 9),
                    Row(
                      children: [
                        Expanded(
                          child: Text(r.name, style: _s(13), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 6),
                        _mu('${r.count}', p),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _bar(r.count / topRepo, p, h: 6),
                  ],
                ],
              ),
            ),
          ),
        ]);
      },
    );
  }
}

String _thousands(int n) => n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

/// Contribution calendar: 53 columns of rounded cells, green by level, month labels on top.
class _Heat extends StatelessWidget {
  const _Heat(this.weeks);
  final List<List<ContribDay>> weeks;
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _HeatPainter(weeks), size: Size.infinite);
}

class _HeatPainter extends CustomPainter {
  _HeatPainter(this.weeks);
  final List<List<ContribDay>> weeks;

  @override
  void paint(Canvas canvas, Size size) {
    final ws = weeks.length > 53 ? weeks.sublist(weeks.length - 53) : weeks;
    final cw = size.width / 53, cs = cw - 2.2;
    const top = 13.0;
    final label = _s(9.5, c: _t.muted, h: 1);
    for (var x = 1; x < ws.length - 1; x++) {
      if (ws[x].isEmpty || ws[x - 1].isEmpty) continue;
      if (ws[x].first.date.month != ws[x - 1].first.date.month) {
        final tp = TextPainter(
          text: TextSpan(text: month3(ws[x].first.date), style: label),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x * cw, 0));
      }
    }
    const green = Color(0xFF3DD68C);
    for (var x = 0; x < ws.length; x++) {
      for (final d in ws[x]) {
        final y = d.date.weekday % 7;
        final v = d.count;
        final o = v == 0
            ? .08
            : v < 4
            ? .3
            : v < 10
            ? .55
            : v < 20
            ? .8
            : 1.0;
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x * cw, top + y * cw, cs, cs), Radius.circular(cs / 2.6)),
          Paint()..color = (v > 0 ? green : _white).withValues(alpha: o),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_HeatPainter o) => o.weeks != weeks;
}

// ------------------------------------------------------------------ Shortcuts

class _Shortcuts extends ConsumerWidget {
  const _Shortcuts();

  static PageId _key(Tile t) => switch (t.icon) {
    'mic' || 'mic_off' || 'micOff' => PageId.timer,
    'speaker' || 'speaker_off' || 'speakerOff' => PageId.hotspot,
    'vol_down' || 'vol_up' || 'volDown' || 'volUp' => PageId.weather,
    'screenshot' || 'shot' => PageId.calendar,
    'terminal' => PageId.github,
    'folder' => PageId.music,
    'lock' => PageId.home,
    _ => const [
      PageId.claude,
      PageId.calendar,
      PageId.music,
      PageId.hotspot,
      PageId.github,
      PageId.weather,
    ][stableHash(t.id) % 6],
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = topicData<ShortcutsData>(ref, 'shortcuts')!;
    final order = ref.watch(settingsProvider.select((x) => x.tileOrder));
    final tiles = orderedTiles(s.tiles, order);
    final rows = math.max(1, (tiles.length / 4).ceil());
    return _grid([1, 1, 1, 1], [for (var i = 0; i < rows; i++) 1], [
      for (final (i, t) in tiles.indexed) _G(i % 4, i ~/ 4, _key2(context, ref, t, s.volumePct)),
    ]);
  }

  Widget _key2(BuildContext context, WidgetRef ref, Tile t, int? vol) {
    final kc = _pc(_key(t));
    final on = t.active;
    final fg = on ? kc : _dark;
    final detail = t.detail ?? (t.id.startsWith('volume') && vol != null ? 'Now $vol%' : null);
    return Press(
      onTap: () => act(context, ref, 'shortcut.run', {'id': t.id}),
      scale: .96,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: on ? _t.bg : kc,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: on ? kc : kc.withValues(alpha: 0), width: 3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            DpIcon(tileIcon(t), size: 32, color: fg, stroke: 2),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tileLabel(t),
                  style: _s(15, w: FontWeight.w800, wdth: 110, c: fg),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (detail != null)
                  Opacity(
                    opacity: .7,
                    child: Text(
                      detail,
                      style: _s(12, c: fg),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
