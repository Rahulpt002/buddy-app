// Concept 15 — Diorama pages. Sizes follow deskpanel-concept-15-diorama.html
// (CSS px = logical px). The isometric room is a port of the concept's SVG `scene()`;
// Home shows the whole room with callouts, detail pages zoom into one object (`VB`).
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/scheduler.dart' as sch;
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
import '../widgets/common.dart';
import 'diorama.dart';

Widget dioramaPage(PageId id) => switch (id) {
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

// ================================================================== the room

const _ink = Color(0xFF2B2D42);

/// Room colours (concept `DAY` / `NIGHT`).
class _Room {
  const _Room({
    required this.dark,
    required this.floor,
    required this.plank,
    required this.wallL,
    required this.wallR,
    required this.baseL,
    required this.baseR,
    required this.wallTop,
    required this.rug,
    required this.rugLine,
    required this.frame,
    required this.sky0,
    required this.sky1,
    required this.cloud,
    required this.cloudOp,
    required this.sticky,
    required this.paper,
    required this.wood,
    required this.desk,
    required this.cabinet,
    required this.glass,
    required this.lapScr,
    required this.lapTrack,
    required this.lapText,
    required this.card,
    required this.cardLabel,
    required this.cardText,
    required this.laptop,
  });
  final bool dark;
  final Color floor, plank, wallL, wallR, baseL, baseR, wallTop, rug, rugLine, frame, sky0, sky1, cloud;
  final double cloudOp;
  final Color sticky, paper, lapScr, lapTrack, lapText, card, cardLabel, cardText;
  final List<Color> wood, desk, cabinet, glass, laptop;
}

const _day = _Room(
  dark: false,
  floor: Color(0xFFEDD3B0),
  plank: Color(0xFFDFC198),
  wallL: Color(0xFFDCE7D6),
  wallR: Color(0xFFC9D8C2),
  baseL: Color(0xFFBFCDB8),
  baseR: Color(0xFFB2C3AB),
  wallTop: Color(0xFFF3F6F0),
  rug: Color(0xFFFFC857),
  rugLine: Color(0xFFF0A93B),
  frame: Color(0xFFFFFFFF),
  sky0: Color(0xFFAFC2D8),
  sky1: Color(0xFFDCE6F0),
  cloud: Color(0xFFFFFFFF),
  cloudOp: .95,
  sticky: Color(0xFFFFF3B0),
  paper: Color(0xFFFFFFFF),
  wood: [Color(0xFFC99266), Color(0xFFA8734B), Color(0xFF8E5F3D)],
  desk: [Color(0xFFD8A577), Color(0xFFB9845A), Color(0xFF9E6E48)],
  cabinet: [Color(0xFFE6D5C1), Color(0xFFCDB79E), Color(0xFFB9A288)],
  glass: [Color(0xE62B2F3A), Color(0x387896BE), Color(0x4D7896BE)],
  lapScr: Color(0xFFF7F1EA),
  lapTrack: Color(0xFFE7DED3),
  lapText: _ink,
  card: Color(0xFFFFFFFF),
  cardLabel: Color(0xFF6C7086),
  cardText: _ink,
  laptop: [Color(0xFFD3D7E0), Color(0xFFB4BAC7), Color(0xFF9EA5B4)],
);

const _night = _Room(
  dark: true,
  floor: Color(0xFF5B4B3F),
  plank: Color(0xFF4F4137),
  wallL: Color(0xFF2F3652),
  wallR: Color(0xFF272D46),
  baseL: Color(0xFF232941),
  baseR: Color(0xFF1E2339),
  wallTop: Color(0xFF3B4364),
  rug: Color(0xFFB4863A),
  rugLine: Color(0xFF94692A),
  frame: Color(0xFFC3C9DE),
  sky0: Color(0xFF0B1230),
  sky1: Color(0xFF24315C),
  cloud: Color(0xFF8E9BC4),
  cloudOp: .4,
  sticky: Color(0xFFE2CF7A),
  paper: Color(0xFFE4E7F1),
  wood: [Color(0xFF7D5A3F), Color(0xFF664832), Color(0xFF523A29)],
  desk: [Color(0xFF8C6547), Color(0xFF74533A), Color(0xFF5F4430)],
  cabinet: [Color(0xFF6A5C51), Color(0xFF594D44), Color(0xFF4A4038)],
  glass: [Color(0xF012141E), Color(0x268CAADC), Color(0x368CAADC)],
  lapScr: Color(0xFF2A2E45),
  lapTrack: Color(0xFF3B405C),
  lapText: Color(0xFFE8EAF3),
  card: Color(0xFF232842),
  cardLabel: Color(0xFF9AA0B8),
  cardText: Color(0xFFE8EAF3),
  laptop: [Color(0xFF8E94A6), Color(0xFF727889), Color(0xFF5E6475)],
);

const _dark3 = [Color(0xFF4A4F63), Color(0xFF3A3E50), Color(0xFF2F3242)];
const _mon3 = [Color(0xFF5A6075), Color(0xFF464B5E), Color(0xFF3A3E50)];

// ------------------------------------------------------------------ isometric engine

const _c30 = 0.8660254037844386, _s30 = .5, _rw = 10.0, _rd = 8.0, _rh = 6.0, _u = 40.0, _m = 30.0;
const _ox = _rd * _c30 * _u + _m, _oy = _rh * _u + _m;
const _vw = (_rw + _rd) * _c30 * _u + 2 * _m, _vh = (_rh + (_rw + _rd) * _s30) * _u + 2 * _m;

Offset _p(double x, double y, double z) => Offset(_ox + (x - y) * _c30 * _u, _oy + (x + y) * _s30 * _u - z * _u);

/// SVG `matrix(a b c d e f)`.
Float64List _mat(double a, double b, double c, double d, Offset o) =>
    Float64List.fromList([a, b, 0, 0, c, d, 0, 0, 0, 0, 1, 0, o.dx, o.dy, 0, 1]);
Float64List _onY(double x, double y, double z) => _mat(_c30 * _u, _s30 * _u, 0, _u, _p(x, y, z));
Float64List _onX(double x, double y, double z) => _mat(_c30 * _u, -_s30 * _u, 0, _u, _p(x, y, z));
Float64List _onZ(double x, double y, double z) => _mat(_c30 * _u, _s30 * _u, -_c30 * _u, _s30 * _u, _p(x, y, z));
Offset _apply(Float64List m, Offset q) => Offset(m[0] * q.dx + m[4] * q.dy + m[12], m[1] * q.dx + m[5] * q.dy + m[13]);

List<List<Offset>> _faces(double x, double y, double z, double w, double d, double h) => [
      [_p(x, y, z + h), _p(x + w, y, z + h), _p(x + w, y + d, z + h), _p(x, y + d, z + h)],
      [_p(x, y + d, z), _p(x + w, y + d, z), _p(x + w, y + d, z + h), _p(x, y + d, z + h)],
      [_p(x + w, y, z), _p(x + w, y + d, z), _p(x + w, y + d, z + h), _p(x + w, y, z + h)],
    ];

/// Concept `box2vb`: bounding box of points, rounded like `toFixed(0)`.
Rect _vbOf(List<Offset> pts) {
  final xs = pts.map((q) => q.dx), ys = pts.map((q) => q.dy);
  final x0 = xs.reduce(math.min), y0 = ys.reduce(math.min);
  return Rect.fromLTWH(x0.roundToDouble(), y0.roundToDouble(), (xs.reduce(math.max) - x0).roundToDouble(),
      (ys.reduce(math.max) - y0).roundToDouble());
}

/// Concept `VB`: crops of the same room for each page.
final _vbs = <PageId, Rect>{
  PageId.home: const Rect.fromLTWH(-300, 20, _vw + 600, _vh - 20),
  PageId.system: _vbOf([_p(3.2, 1.0, 5.0), _p(6.4, 1.2, 4.9), _p(3.4, 2.8, 2.6), _p(6.4, 2.9, 2.6), _p(4.2, 1.6, 2.7)]),
  PageId.claude: _vbOf([_p(6.0, 1.5, 3.9), _p(7.8, 1.5, 3.9), _p(6.0, 2.8, 2.6), _p(7.8, 2.8, 2.6)]),
  PageId.calendar: _vbOf([_p(6.1, 0, 5.8), _p(8.2, 0, 5.8), _p(6.1, 0, 3.2), _p(8.2, 0, 3.2)]),
  PageId.weather: _vbOf([_p(.6, 0, 5.9), _p(3.9, 0, 5.9), _p(.6, 0, 3.0), _p(3.9, 0, 3.0)]),
  PageId.music: _vbOf([_p(2.1, .7, 4.9), _p(3.2, .7, 4.9), _p(2.1, 1.7, 2.6), _p(3.2, 1.7, 2.6)]),
  PageId.hotspot: _vbOf([_p(.3, 4.5, 3.3), _p(2.6, 4.5, 3.3), _p(.3, 7.0, 1.0), _p(2.6, 7.0, 1.0)]),
  PageId.timer: _vbOf([_p(0, 1.5, 6.0), _p(0, 3.7, 6.0), _p(0, 1.5, 3.8), _p(0, 3.7, 3.8)]),
  PageId.slack: _vbOf([_p(0, 8.05, 5.7), _p(0, 5.9, 5.7), _p(0, 8.05, 3.3), _p(0, 5.9, 3.3)]),
  PageId.github: _vbOf([_p(7.1, .6, 5.2), _p(8.1, .6, 5.2), _p(7.1, 1.5, 2.6), _p(8.1, 1.5, 2.6)]),
};

typedef _Fit = ({double k, double tx, double ty});

// ------------------------------------------------------------------ live data

typedef _CalLine = ({String text, Color color, bool next});

/// A Slack message as a note on the pinboard.
typedef _Note = ({String initials, Color color, bool unread});

class _RoomData {
  _RoomData({
    required this.dark,
    required this.hour,
    required this.minute,
    required this.calHead,
    required this.temp,
    required this.wx,
    required this.cal,
    required this.notes,
    required this.slackOn,
    required this.unread,
    required this.playing,
    required this.cpu,
    required this.mon,
    required this.claude,
    required this.claudeTxt,
    required this.leaves,
    required this.phone,
    this.liveSpeaker = false,
  });
  final bool dark, playing;

  /// The Music close-up: the speaker's cones and the notes are left to [_LiveSpeaker],
  /// which animates them over the room while music plays.
  final bool liveSpeaker;

  /// Slack is connected and set up (otherwise the pinboard stays bare, not "All caught up").
  final bool slackOn;
  final int hour, minute, leaves, unread;
  final String calHead, temp, wx, mon, claudeTxt;
  final List<_CalLine> cal;
  final List<_Note> notes;
  final double claude;

  /// The roof phone, only on the Hotspot page (its close-up puts the phone on the
  /// sideboard); null everywhere else, where the sideboard holds books and a vase instead.
  final _Phone? phone;
  final List<double> cpu;

  bool same(_RoomData o) =>
      dark == o.dark &&
      hour == o.hour &&
      minute == o.minute &&
      calHead == o.calHead &&
      temp == o.temp &&
      wx == o.wx &&
      listEquals(cal, o.cal) &&
      listEquals(notes, o.notes) &&
      slackOn == o.slackOn &&
      unread == o.unread &&
      playing == o.playing &&
      identical(cpu, o.cpu) &&
      mon == o.mon &&
      claude == o.claude &&
      claudeTxt == o.claudeTxt &&
      leaves == o.leaves &&
      phone == o.phone &&
      liveSpeaker == o.liveSpeaker;
}

const _mon3names = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];

/// [code] is the topic the plant's streak leaves come from: GitHub everywhere except the
/// GitHub page, which follows the GitHub / GitLab switch. [phone] is true only on the
/// Hotspot page, the one place the roof phone (and its data) appears. [liveSpeaker]: the
/// Music page, where the speaker comes alive (see [_RoomData.liveSpeaker]).
_RoomData _roomData(WidgetRef ref, DateTime now, bool dark,
    {String code = 'github', bool phone = false, bool liveSpeaker = false}) {
  final sys = topicData<SystemData>(ref, 'system');
  final cl = topicData<ClaudeData>(ref, 'claude');
  final media = topicData<MediaData>(ref, 'media');
  final gh = topicData<GithubData>(ref, code);
  final sl = topicData<SlackData>(ref, 'slack');
  final w = ref.watch(weatherProvider);
  final s = ref.watch(settingsProvider);
  final events = ref.watch(calendarEventsProvider);
  final today = splitEvents(events, now).today;
  final n = nextEvent(events, now);
  final five = limitPct(cl?.fiveHour, now);
  return _RoomData(
    dark: dark,
    hour: now.hour,
    minute: now.minute,
    calHead: '${_mon3names[now.month - 1]} ${now.day}',
    temp: w == null ? '—' : '${temp(w.now.tempC, s.fahrenheit)}°',
    wx: w?.now.icon ?? 'cloud',
    cal: [
      for (final e in today.take(3))
        (
          text: e.allDay ? e.title : '${clock(e.start, h24: s.clock24)} ${e.title.split(' ').first}',
          color: hex(e.color, Dio.sky),
          next: e == n,
        ),
    ],
    notes: [
      for (final m in (sl?.messages ?? const <SlackMsg>[]).take(4))
        (initials: m.initials, color: hex(m.senderColor, Dio.plum), unread: m.unread),
    ],
    slackOn: sl != null,
    unread: sl?.unread ?? 0,
    playing: media?.playing ?? false,
    cpu: sys?.cpuHistory ?? const [],
    mon: sys == null
        ? 'CPU —'
        : 'CPU ${sys.cpu.pct.round()}% GPU ${sys.gpu.available && sys.gpu.pct != null ? '${sys.gpu.pct!.round()}%' : 'N/A'}',
    claude: five / 100,
    claudeTxt: cl?.fiveHour == null ? '—' : '${five.round()}%',
    leaves: (gh?.streakCurrent ?? 0).clamp(0, 12),
    phone: phone ? _phoneOf(topicData<HotspotData>(ref, 'hotspot')) : null,
    liveSpeaker: liveSpeaker,
  );
}

/// The roof phone as the room draws it: [state] picks the colour, [bars] the lit signal
/// arcs (0–3), [net] / [batt] the two words on its screen.
typedef _Phone = ({HsState state, int bars, String net, String batt});

_Phone _phoneOf(HotspotData? h) => h == null
    ? (state: HsState.offline, bars: 0, net: '—', batt: '')
    : (
        state: hsState(h),
        bars: !h.online || h.internet == false
            ? 0
            : switch (h.grade) {
                HotspotGrade.excellent || HotspotGrade.good => 3,
                HotspotGrade.fair => 2,
                HotspotGrade.poor => 1,
                null => 0,
              },
        net: h.netType?.split(' ').first ?? '—',
        batt: h.batteryPct == null ? '' : '${h.batteryPct!.round()}%',
      );

/// The status colour of the roof phone, from the room palette.
Color _hsCol(HsState s) => switch (s) {
      HsState.ok => Dio.leaf,
      HsState.lowBattery => Dio.amber,
      HsState.offline => const Color(0xFF9AA0B8),
      _ => Dio.coral,
    };

// ------------------------------------------------------------------ painting helpers

Paint _fill(Color c) => Paint()..color = c;
Paint _stroke(Color c, double w, {StrokeCap cap = StrokeCap.butt, StrokeJoin join = StrokeJoin.miter}) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = cap
  ..strokeJoin = join;

void _poly(Canvas c, List<Offset> pts, Color col) => c.drawPath(Path()..addPolygon(pts, true), _fill(col));

void _box(Canvas c, double x, double y, double z, double w, double d, double h, List<Color> col, [Paint? stroke]) {
  for (final (i, f) in _faces(x, y, z, w, d, h).indexed) {
    final path = Path()..addPolygon(f, true);
    c.drawPath(path, _fill(col[i]));
    if (stroke != null) c.drawPath(path, stroke);
  }
}

void _group(Canvas c, Float64List m, void Function() f) {
  c.save();
  c.transform(m);
  f();
  c.restore();
}

/// SVG text at baseline ([x], [y]). Laid out at a fixed size and scaled, so tiny
/// local-unit font sizes (0.2) inside the isometric transforms render cleanly.
/// [maxW] shrinks the text (to 80%) and then ellipsizes so it fits.
void _txt(Canvas c, String s, double x, double y, double size, Color col,
    {FontWeight w = FontWeight.w500, bool middle = false, double? maxW}) {
  const base = 32.0;
  var k = size / base;
  final style = TextStyle(fontFamily: 'Fredoka', fontSize: base, fontWeight: w, color: col);
  var tp = TextPainter(text: TextSpan(text: s, style: style), textDirection: TextDirection.ltr, maxLines: 1)..layout();
  if (maxW != null && tp.width * k > maxW) {
    k = math.max(k * .8, maxW / tp.width);
    if (tp.width * k > maxW) {
      tp = TextPainter(
          text: TextSpan(text: s, style: style), textDirection: TextDirection.ltr, maxLines: 1, ellipsis: '…')
        ..layout(maxWidth: maxW / k);
    }
  }
  final bl = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  c.save();
  c.translate(x, y);
  c.scale(k);
  tp.paint(c, Offset(middle ? -tp.width / 2 : 0, -bl));
  c.restore();
}

/// Ellipse filled with a radial gradient that fades out (SVG objectBoundingBox gradient).
void _glow(Canvas c, Offset ctr, double rx, double ry, Color col, double op) {
  c.save();
  c.translate(ctr.dx, ctr.dy);
  c.scale(rx, ry);
  c.drawCircle(
      Offset.zero,
      1,
      Paint()
        ..shader = RadialGradient(colors: [col.withValues(alpha: op), col.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: Offset.zero, radius: 1)));
  c.restore();
}

/// The Slack pinboard (local wall units, 1.4 × 1.9): a cork board with a note per recent
/// message (coloured strip = sender, coral pin = unread) and a badge with the unread count.
void _pinboard(Canvas c, _Room k, List<_Note> notes, int unread, {bool on = true}) {
  const board = Rect.fromLTWH(0, 0, 1.4, 1.9);
  c.drawRRect(RRect.fromRectAndRadius(board.inflate(.08), const Radius.circular(.06)), _fill(k.wood[1]));
  c.drawRect(board, _fill(k.dark ? const Color(0xFF6E5A47) : const Color(0xFFDDB98C)));
  final speck = _fill(k.dark ? const Color(0xFF5E4C3C) : const Color(0xFFC9A273));
  for (final (x, y) in const [(.12, .2), (.7, .12), (1.25, .3), (.2, .95), (.75, .9), (1.3, 1.1), (.1, 1.75), (.65, 1.7), (1.2, 1.8)]) {
    c.drawCircle(Offset(x, y), .025, speck);
  }
  const spots = [(.36, .5, -6.0), (1.04, .58, 5.0), (.38, 1.3, 4.0), (1.03, 1.36, -5.0)];
  const sz = .56;
  if (notes.isEmpty && on) {
    c.save();
    c.translate(.7, .95);
    c.rotate(-4 * math.pi / 180);
    c.drawRect(Rect.fromCenter(center: const Offset(.02, .03), width: .86, height: .78), _fill(const Color(0x26000000)));
    c.drawRect(Rect.fromCenter(center: Offset.zero, width: .86, height: .78), _fill(k.sticky));
    _txt(c, 'All', 0, -.02, .2, _ink, w: FontWeight.w600, middle: true);
    _txt(c, 'caught up', 0, .2, .15, _ink, middle: true);
    c.drawCircle(const Offset(0, -.31), .055, _fill(Dio.teal));
    c.restore();
  }
  for (final (i, n) in notes.take(4).indexed) {
    final (x, y, a) = spots[i];
    c.save();
    c.translate(x, y);
    c.rotate(a * math.pi / 180);
    const note = Rect.fromLTWH(-sz / 2, -sz / 2, sz, sz);
    c.drawRect(note.shift(const Offset(.02, .03)), _fill(const Color(0x26000000)));
    c.drawRect(note, _fill(n.unread ? k.paper : Color.lerp(k.paper, k.dark ? const Color(0xFF6E5A47) : const Color(0xFFDDB98C), .35)!));
    c.drawRect(Rect.fromLTWH(-sz / 2, -sz / 2, sz, .11), _fill(n.unread ? n.color : n.color.withValues(alpha: .45)));
    _txt(c, n.initials, 0, .14, .21, n.unread ? _ink : const Color(0xFF8A8FA3), w: FontWeight.w600, middle: true);
    c.drawCircle(const Offset(0, -sz / 2 + .05), .05, _fill(n.unread ? Dio.coral : const Color(0xFF9AA0B8)));
    c.restore();
  }
  if (unread > 0) {
    const o = Offset(1.36, .02);
    c.drawCircle(o, .25, _fill(k.frame));
    c.drawCircle(o, .21, _fill(Dio.coral));
    _txt(c, unread > 9 ? '9+' : '$unread', o.dx, o.dy + .085, unread > 9 ? .19 : .24, Dio.white, w: FontWeight.w600, middle: true);
  }
}

/// Polyline with an SVG-style dash pattern that continues across segments.
void _dashed(Canvas c, List<Offset> pts, Paint p, double on, double off) {
  var draw = true;
  var left = on;
  for (var i = 0; i < pts.length - 1; i++) {
    var a = pts[i];
    final b = pts[i + 1];
    var seg = (b - a).distance;
    if (seg == 0) continue;
    final dir = (b - a) / seg;
    while (seg > 1e-6) {
      final step = math.min(left, seg);
      final nb = a + dir * step;
      if (draw) c.drawLine(a, nb, p);
      a = nb;
      seg -= step;
      left -= step;
      if (left <= 1e-6) {
        draw = !draw;
        left = draw ? on : off;
      }
    }
  }
}

// ------------------------------------------------------------------ the room (concept `scene()`)

void _paintRoom(Canvas c, _RoomData r) {
  final k = r.dark ? _night : _day;

  // floor + walls
  _poly(c, [_p(0, 0, 0), _p(_rw, 0, 0), _p(_rw, _rd, 0), _p(0, _rd, 0)], k.floor);
  _group(c, _onZ(0, 0, 0), () {
    final pl = _stroke(k.plank, .04);
    for (var i = 0; i < 9; i++) {
      c.drawLine(Offset(i + 1.0, 0), Offset(i + 1.0, _rd), pl);
    }
  });
  _poly(c, [_p(0, 0, 0), _p(0, _rd, 0), _p(0, _rd, _rh), _p(0, 0, _rh)], k.wallL);
  _poly(c, [_p(0, 0, 0), _p(_rw, 0, 0), _p(_rw, 0, _rh), _p(0, 0, _rh)], k.wallR);
  _poly(c, [_p(0, 0, 0), _p(0, _rd, 0), _p(0, _rd, .3), _p(0, 0, .3)], k.baseL);
  _poly(c, [_p(0, 0, 0), _p(_rw, 0, 0), _p(_rw, 0, .3), _p(0, 0, .3)], k.baseR);
  _poly(c, [_p(0, 0, _rh), _p(_rw, 0, _rh), _p(_rw, -.25, _rh), _p(-.25, -.25, _rh), _p(-.25, _rd, _rh), _p(0, _rd, _rh)],
      k.wallTop);

  // rug
  _group(c, _onZ(6.4, 5.7, 0), () {
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: 5, height: 3.4), _fill(k.rug));
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: 4.2, height: 2.7), _stroke(k.rugLine, .12));
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: 2.8, height: 1.7), _stroke(k.rugLine, .12));
  });

  // window on the right wall, with the weather
  _group(c, _onY(1.0, 0, 5.6), () {
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-.12, -.12, 2.84, 2.44), const Radius.circular(.06)),
        _fill(k.frame));
    const sky = Rect.fromLTWH(0, 0, 2.6, 2.2);
    c.drawRect(
        sky,
        Paint()
          ..shader = LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [k.sky0, k.sky1])
              .createShader(sky));
    c.save();
    c.clipRect(sky);
    if (k.dark) {
      c.drawCircle(const Offset(2.05, .5), .26, _fill(const Color(0xFFF4F1DC)));
      c.drawCircle(const Offset(2.15, .43), .22, _fill(k.sky0));
      for (final (x, y) in const [(.3, .3), (.6, 1.5), (1.6, .3), (1.0, 1.7), (2.3, 1.6), (.4, 1.9), (1.8, 1.9)]) {
        c.drawCircle(Offset(x, y), .035, _fill(const Color(0xD9FFFFFF)));
      }
    } else if (r.wx == 'sun' || r.wx == 'partly') {
      c.drawCircle(const Offset(2.05, .5), .26, _fill(const Color(0xFFFFE08A)));
    }
    if (r.wx == 'rain') {
      final rp = _stroke(k.dark ? const Color(0x668E9BC4) : const Color(0xB3FFFFFF), .035, cap: StrokeCap.round);
      for (final (x, y) in const [(.35, 1.1), (.75, 1.35), (1.15, 1.05), (1.55, 1.5), (1.95, 1.55), (2.3, 1.75), (.55, 1.8), (1.35, 1.85)]) {
        c.drawLine(Offset(x, y), Offset(x - .07, y + .22), rp);
      }
    }
    final clouds = <Rect>[
      if (r.wx != 'sun') ...[
        Rect.fromCenter(center: const Offset(.8, .7), width: 1.0, height: .44),
        Rect.fromCenter(center: const Offset(1.1, .58), width: .76, height: .52),
      ],
      Rect.fromCenter(center: const Offset(1.9, 1.2), width: .9, height: .4),
      Rect.fromCenter(center: const Offset(2.1, 1.08), width: .6, height: .4),
    ];
    c.saveLayer(sky, Paint()..color = Color.fromRGBO(0, 0, 0, k.cloudOp));
    for (final o in clouds) {
      c.drawOval(o, _fill(k.cloud));
    }
    c.restore();
    c.restore();
    final fr = _stroke(k.frame, .08);
    c.drawLine(const Offset(1.3, 0), const Offset(1.3, 2.2), fr);
    c.drawLine(const Offset(0, 1.1), const Offset(2.6, 1.1), fr);
    c.drawRect(const Rect.fromLTWH(-.2, 2.2, 3, .14), _fill(k.frame));
    c.save();
    c.translate(.55, .42);
    c.rotate(-5 * math.pi / 180);
    c.translate(-.55, -.42);
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(.1, .12, .95, .6), const Radius.circular(.06)),
        _fill(k.sticky));
    _txt(c, r.temp, .57, .56, .38, _ink, w: FontWeight.w600, middle: true);
    c.restore();
  });

  // wall calendar
  _group(c, _onY(6.3, 0, 5.5), () {
    const paper = Rect.fromLTWH(0, 0, 1.7, 2);
    c.drawRRect(RRect.fromRectAndRadius(paper, const Radius.circular(.06)), _fill(k.paper));
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 1.7, .48), const Radius.circular(.06)),
        _fill(Dio.coral));
    _txt(c, r.calHead, .85, .36, .28, Dio.white, w: FontWeight.w600, middle: true);
    c.save();
    c.clipRect(paper);
    for (final (i, e) in r.cal.indexed) {
      c.drawRect(Rect.fromLTWH(.12, .62 + i * .44, .1, .3), _fill(e.color));
      _txt(c, e.text, .3, .84 + i * .44, .22, e.next ? const Color(0xFFE2502D) : _ink,
          w: e.next ? FontWeight.w600 : FontWeight.w500);
    }
    c.restore();
  });

  // wall clock on the left wall
  _group(c, _onX(0, 2.6, 4.9), () {
    Offset hand(double a, double rr) => Offset(math.sin(a * math.pi / 180) * rr, -math.cos(a * math.pi / 180) * rr);
    c.drawCircle(Offset.zero, .9, _fill(k.paper));
    c.drawCircle(Offset.zero, .9, _stroke(_ink, .09));
    for (var i = 0; i < 12; i++) {
      c.drawCircle(hand(i * 30.0, .7), .045, _fill(_ink));
    }
    final hA = ((r.hour % 12) + r.minute / 60) * 30, mA = r.minute * 6.0;
    c.drawLine(Offset.zero, hand(hA, .42), _stroke(_ink, .1, cap: StrokeCap.round));
    c.drawLine(Offset.zero, hand(mA, .64), _stroke(Dio.coral, .07, cap: StrokeCap.round));
    c.drawCircle(Offset.zero, .07, _fill(_ink));
  });

  // Slack pinboard on the left wall: one note per recent message, unread count badge
  _group(c, _onX(0, 7.9, 5.3), () => _pinboard(c, k, r.notes, r.unread, on: r.slackOn));

  // shelf with books
  _box(c, 0, 4.2, 3.9, .45, 2.2, .1, k.wood);
  _box(c, .05, 4.4, 4.0, .35, .25, .7, const [Color(0xFF8E7CC3), Color(0xFF7A68AF), Color(0xFF6A589F)]);
  _box(c, .05, 4.7, 4.0, .35, .2, .6, const [Color(0xFF2EC4B6), Color(0xFF22A89B), Color(0xFF1C8F84)]);
  _box(c, .05, 4.95, 4.0, .35, .28, .75, const [Color(0xFFFF7A59), Color(0xFFE8613F), Color(0xFFD25536)]);
  if (k.dark) {
    _group(c, _onY(3.0, 0, 5.4), () => _glow(c, const Offset(1.8, 1.1), 2.1, 1.2, const Color(0xFF7C9BFF), .45));
  }

  // desk
  _box(c, 1.9, .6, 0, .2, 2.4, 2.5, k.wood);
  _box(c, 7.9, .6, 0, .2, 2.4, 2.5, k.wood);
  _box(c, 1.8, .5, 2.5, 6.4, 2.6, .22, k.desk);

  // desk lamp; at night it lights the desk
  const lampGlow = Color(0xFFFFD98A);
  if (k.dark) _group(c, _onZ(3.25, 2.15, 2.72), () => _glow(c, Offset.zero, 1.35, 1.1, lampGlow, .75));
  _box(c, 3.05, 2.0, 2.72, .36, .36, .05, _dark3);
  _box(c, 3.19, 2.14, 2.77, .07, .07, .85, _dark3);
  _box(c, 2.98, 1.98, 3.6, .5, .34, .2,
      [k.dark ? const Color(0xFFFFE6A8) : Dio.coral, const Color(0xFFE8613F), const Color(0xFFD25536)]);
  if (k.dark) _glow(c, _p(3.23, 2.15, 3.55), 26, 26, lampGlow, .75);

  // speaker (notes float while music plays; on the Music page [_LiveSpeaker] draws the
  // cones and notes instead, animated)
  _box(c, 2.3, .9, 2.72, .62, .55, .95, _dark3);
  if (!r.liveSpeaker) {
    _group(c, _onY(2.3, 1.45, 3.67), () => _speakerFace(c, 0, 0, 0));
    if (r.playing) {
      for (final (o, s) in [(_p(2.4, 1.0, 4.1), 1.0), (_p(2.8, .9, 4.6), .8)]) {
        c.save();
        c.translate(o.dx, o.dy);
        c.scale(s);
        c.drawOval(Rect.fromCenter(center: const Offset(0, 12), width: 10, height: 8), _fill(Dio.plum));
        c.drawRect(const Rect.fromLTWH(4, -6, 2, 18), _fill(Dio.plum));
        c.restore();
      }
    }
  }

  // monitor with the live CPU graph
  _box(c, 4.4, 1.0, 2.72, .8, .5, .06, _mon3);
  _box(c, 4.7, 1.15, 2.78, .2, .15, .5, _mon3);
  _box(c, 3.6, 1.0, 3.2, 2.4, .14, 1.45, const [Color(0xFF5A6075), Color(0xFF3A3E50), Color(0xFF2F3242)]);
  _group(c, _onY(3.67, 1.14, 4.6), () {
    const scr = Rect.fromLTWH(0, 0, 2.26, 1.32);
    c.drawRect(
        scr,
        Paint()
          ..shader = const LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1E2235), Color(0xFF2B3150)])
              .createShader(scr));
    final cpu = r.cpu;
    if (cpu.length > 1) {
      final path = Path();
      for (final (i, v) in cpu.indexed) {
        final q = Offset(.05 + i / (cpu.length - 1) * 2.2, .2 + 1.0 * (1 - v.clamp(0, 100) / 100));
        i == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
      }
      c.drawPath(path, _stroke(const Color(0xFF5BE39B), .05, join: StrokeJoin.round));
    }
    _txt(c, r.mon, .1, .2, .17, const Color(0xFF9FB0D8));
  });

  // laptop with the Claude ring
  _box(c, 6.2, 1.7, 2.72, 1.4, .95, .06, k.laptop);
  _box(c, 6.2, 1.55, 2.78, 1.4, .07, .95, k.laptop);
  _group(c, _onY(6.28, 1.62, 3.66), () {
    c.drawRect(const Rect.fromLTWH(0, 0, 1.24, .8), _fill(k.lapScr));
    const ring = Offset(.38, .4);
    c.drawCircle(ring, .25, _stroke(k.lapTrack, .08));
    if (r.claude > 0) {
      c.drawArc(Rect.fromCircle(center: ring, radius: .25), -math.pi / 2, 2 * math.pi * r.claude.clamp(0, 1), false,
          _stroke(Dio.claude, .08));
    }
    _txt(c, r.claudeTxt, .72, .46, .2, k.lapText, w: FontWeight.w600);
  });

  // plant: one leaf per day of GitHub streak
  final pp = _p(7.65, 1.05, 3.17);
  _box(c, 7.4, .8, 2.72, .5, .5, .45, const [Color(0xFFE8A07E), Color(0xFFD9875F), Color(0xFFC7754F)]);
  c.drawPath(
      Path()
        ..moveTo(pp.dx, pp.dy)
        ..relativeQuadraticBezierTo(3, -40, 0, -(30 + r.leaves * 9.0)),
      _stroke(const Color(0xFF3F8E4A), 3));
  for (var i = 0; i < r.leaves; i++) {
    final yy = pp.dy - 14 - i * 9, side = i.isOdd ? 1.0 : -1.0;
    c.save();
    c.translate(pp.dx + side * 11, yy);
    c.rotate(side * -28 * math.pi / 180);
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: 22, height: 11),
        _fill(i == r.leaves - 1 ? const Color(0xFF8EE29A) : Dio.leaf));
    c.restore();
  }

  // sideboard with three drawers facing the room
  _box(c, .4, 4.6, 0, 2.0, 2.2, 1.5, k.cabinet);
  _group(c, _onX(2.4, 6.8, 1.5), () {
    final front = _fill(Color.lerp(k.cabinet[2], k.cabinet[1], .55)!);
    final pull = _fill(k.wood[k.dark ? 0 : 1]);
    for (var i = 0; i < 3; i++) {
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(.12, .1 + i * .45, 1.96, .37), const Radius.circular(.04)), front);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(.88, .245 + i * .45, .44, .08), const Radius.circular(.04)), pull);
    }
  });
  final phone = r.phone;
  if (phone == null) {
    _sideboardDecor(c, k);
  } else {
    _roofPhone(c, k, phone);
  }
}

/// The Hotspot page's close-up: the roof phone clamped upright on a little mast on the
/// sideboard, its screen facing the room and signal arcs above it (lit by the signal
/// grade, coloured by its state).
void _roofPhone(Canvas c, _Room k, _Phone ph) {
  final col = _hsCol(ph.state);
  // base puck, mast, clamp
  _box(c, 1.0, 5.45, 1.5, .6, .6, .07, _dark3);
  _box(c, 1.27, 5.72, 1.57, .07, .07, .45, _mon3);
  _box(c, 1.2, 5.45, 2.0, .16, .62, .07, _dark3);
  // the phone, upright, screen towards the room (+x)
  const x = 1.25, y = 5.43, z = 2.06, w = .1, d = .66, h = 1.22;
  _box(c, x, y, z, w, d, h, const [Color(0xFF4A4F63), Color(0xFF2F3242), Color(0xFF22252F)]);
  _group(c, _onX(x + w, y + d, z + h), () {
    const scr = Rect.fromLTWH(.05, .05, d - .1, h - .1);
    c.drawRRect(
        RRect.fromRectAndRadius(scr, const Radius.circular(.05)),
        Paint()
          ..shader = const LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1E2235), Color(0xFF2B3150)])
              .createShader(scr));
    _txt(c, ph.net, .11, .25, .13, const Color(0xFF9FB0D8), w: FontWeight.w600);
    _txt(c, ph.batt, d - .3, .25, .11, const Color(0xFF9FB0D8));
    // four signal bars on the screen, lit by the grade
    for (var i = 0; i < 4; i++) {
      final bh = .14 + i * .1;
      final lit = ph.bars > 0 && i < ph.bars + 1;
      c.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(.13 + i * .11, .92 - bh, .07, bh), const Radius.circular(.02)),
          _fill(lit ? col : const Color(0xFF3B405C)));
    }
    c.drawCircle(Offset(d / 2, h - .12), .035, _fill(const Color(0xFF3B405C)));
  });
  // signal arcs above the phone (an x when it is offline)
  final top = _p(x + w / 2, y + d / 2, z + h + .12);
  if (ph.state == HsState.offline) {
    final p = _stroke(col, 3.5, cap: StrokeCap.round);
    c.drawLine(top + const Offset(-7, -22), top + const Offset(7, -8), p);
    c.drawLine(top + const Offset(7, -22), top + const Offset(-7, -8), p);
    return;
  }
  for (var i = 0; i < 3; i++) {
    final rr = 9.0 + i * 8;
    c.drawArc(Rect.fromCircle(center: top, radius: rr), -math.pi * .78, math.pi * .56, false,
        _stroke(i < ph.bars ? col : col.withValues(alpha: k.dark ? .25 : .3), 3.2, cap: StrokeCap.round));
  }
  c.drawCircle(top, 3, _fill(col));
}

/// A flat book on the sideboard: cover colours [col], page edges facing the room, two
/// bands on the spine.
void _book(Canvas c, _Room k, double x, double y, double z, double w, double d, double h, List<Color> cover) {
  // a touch dimmer at night, so they sit in the lamplit room
  final col = [for (final cc in cover) k.dark ? Color.lerp(cc, _ink, .2)! : cc];
  final pages = k.dark ? Color.lerp(k.paper, _ink, .2)! : k.paper;
  _box(c, x, y, z, w, d, h, col);
  _group(c, _onX(x + w, y + d, z + h), () => c.drawRect(Rect.fromLTWH(.05, .035, d - .1, h - .07), _fill(pages)));
  _group(c, _onY(x, y + d, z + h), () {
    final band = _fill(Color.lerp(col[1], Dio.white, .35)!);
    c.drawRect(Rect.fromLTWH(.14, 0, .05, h), band);
    c.drawRect(Rect.fromLTWH(w - .19, 0, .05, h), band);
  });
}

/// What sits on the sideboard everywhere but the Hotspot page: a stack of books and a
/// ceramic vase of pampas grass.
void _sideboardDecor(Canvas c, _Room k) {
  final dark = k.dark;

  // vase (behind the books), a bulb with a narrow neck, shaded like the boxes: lit left, dim right
  final b = _p(1.85, 5.15, 1.5);
  final body = Path()
    ..moveTo(b.dx - 13, b.dy)
    ..cubicTo(b.dx - 22, b.dy - 8, b.dx - 20, b.dy - 24, b.dx - 7, b.dy - 32)
    ..lineTo(b.dx - 6, b.dy - 40)
    ..lineTo(b.dx + 6, b.dy - 40)
    ..lineTo(b.dx + 7, b.dy - 32)
    ..cubicTo(b.dx + 20, b.dy - 24, b.dx + 22, b.dy - 8, b.dx + 13, b.dy)
    ..arcToPoint(Offset(b.dx - 13, b.dy), radius: const Radius.elliptical(13, 6.5));
  final vase = dark
      ? const [Color(0xFF6F84A0), Color(0xFF4C5D76)]
      : const [Color(0xFFB4CBE0), Color(0xFF7E9BB8)];
  c.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(colors: vase, stops: const [.3, 1])
            .createShader(Rect.fromLTRB(b.dx - 21, b.dy - 40, b.dx + 21, b.dy)));
  c.drawOval(Rect.fromCenter(center: Offset(b.dx, b.dy - 40), width: 12, height: 5),
      _fill(dark ? const Color(0xFF34404F) : const Color(0xFF5E7A96)));

  // pampas: three curved stems, a soft plume at the end of each
  final stem = _stroke(dark ? const Color(0xFF8C7E66) : const Color(0xFFBFA77E), 2, cap: StrokeCap.round);
  final plume = dark ? const Color(0xFFB5A58A) : const Color(0xFFF6E7C8);
  final plume2 = dark ? const Color(0xFF9E8F75) : const Color(0xFFE9D3A8);
  final top = Offset(b.dx, b.dy - 40);
  for (final (dx, dy, bend) in const [(-19.0, -86.0, -9.0), (4.0, -100.0, 6.0), (27.0, -78.0, 12.0)]) {
    final end = top + Offset(dx, dy);
    final ctl = top + Offset(dx * .2 + bend, dy * .55);
    c.drawPath(Path()
      ..moveTo(top.dx, top.dy)
      ..quadraticBezierTo(ctl.dx, ctl.dy, end.dx, end.dy), stem);
    // the plume follows the stem's last stretch
    final dir = end - ctl;
    final a = math.atan2(dir.dy, dir.dx) + math.pi / 2;
    c.save();
    c.translate(end.dx - dir.dx / dir.distance * 14, end.dy - dir.dy / dir.distance * 14);
    c.rotate(a);
    c.drawOval(Rect.fromCenter(center: const Offset(1.5, 2), width: 11, height: 38), _fill(plume2));
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: 10, height: 36), _fill(plume));
    c.restore();
  }

  // a stack of three books, front left
  _book(c, k, .6, 5.5, 1.5, 1.0, 1.15, .17, const [Color(0xFF7FB7E6), Color(0xFF6699C8), Color(0xFF5584B3)]);
  _book(c, k, .68, 5.6, 1.67, .86, 1.0, .15, const [Color(0xFFFFC857), Color(0xFFE8AE3C), Color(0xFFD39A2E)]);
  _book(c, k, .63, 5.66, 1.82, .94, .9, .16, const [Color(0xFFF28B82), Color(0xFFDD7168), Color(0xFFC85F57)]);
}

class _RoomPainter extends CustomPainter {
  _RoomPainter(this.r, this.fit);
  final _RoomData r;
  final _Fit fit;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(fit.tx, fit.ty);
    canvas.scale(fit.k);
    _paintRoom(canvas, r);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RoomPainter o) => o.fit != fit || !o.r.same(r);
}

// ------------------------------------------------------------------ the live speaker (Music)

/// The speaker's front (local face units, .62 × .95): tweeter above, woofer below. [woof]
/// and [tweet] (0..1) push the cones out; [e] (0..1) is how alive it is. All zero draws the
/// still speaker exactly as the room always has.
void _speakerFace(Canvas c, double woof, double tweet, double e) {
  const cone = Color(0xFF22252F), cap = Color(0xFF555B70);
  c.drawCircle(const Offset(.31, .3), .14 * (1 + .05 * tweet), _fill(cone));
  if (e > 0) c.drawCircle(const Offset(.31, .3), .045 * (1 + .5 * tweet), _fill(cap.withValues(alpha: e)));
  c.drawCircle(const Offset(.31, .66), .22 * (1 + .06 * woof), _fill(cone));
  if (e > 0) {
    // the cone's rim catching the light as it moves
    c.drawCircle(const Offset(.31, .66), .155 * (1 + .14 * woof),
        _stroke(cap.withValues(alpha: (.25 + .5 * woof) * e), .022));
  }
  c.drawCircle(const Offset(.31, .66), .08 * (1 + .45 * woof), _fill(cap));
}

/// The room's music note in room pixels (head centred at (0, 12), stem up to −6); [kind] 1
/// adds a flag (♪), 2 makes a beamed pair (♫). One path, so a fading note stays even.
Path _notePath(int kind) {
  final p = Path()
    ..addOval(Rect.fromCenter(center: const Offset(0, 12), width: 10, height: 8))
    ..addRect(const Rect.fromLTWH(4, -6, 2, 18));
  if (kind == 1) {
    p
      ..moveTo(6, -6)
      ..quadraticBezierTo(13, -1, 11, 7)
      ..quadraticBezierTo(10, 1, 6, -1)
      ..close();
  } else if (kind == 2) {
    p
      ..addOval(Rect.fromCenter(center: const Offset(13, 10), width: 10, height: 8))
      ..addRect(const Rect.fromLTWH(17, -8, 2, 18))
      ..addPolygon(const [Offset(4, -6), Offset(19, -8), Offset(19, -3.5), Offset(4, -1.5)], true);
  }
  return p;
}

final _notePaths = [for (var k = 0; k < 3; k++) _notePath(k)];

/// One rising note: [born] in [_SpeakerClock.t] seconds; the rest comes from [id].
typedef _Rise = ({int id, double born});

const _riseLife = 3.4;

/// Stable pseudo-random 0..1 for an integer.
double _rnd(int i) {
  var x = (i * 0x27d4eb2d + 0x165667b1) & 0x7fffffff;
  x = ((x ^ (x >> 15)) * 0x2c1b3c6d) & 0x7fffffff;
  x = ((x ^ (x >> 12)) * 0x297a2d39) & 0x7fffffff;
  return (x ^ (x >> 15)) / 0x7fffffff;
}

/// The Music close-up's clock: [t] is real seconds (the notes keep rising after a pause),
/// [beat] seconds of music (slows to a stop on pause), [e] eases 0 ↔ 1 with play / pause.
/// New notes only while playing; the ticker stops once paused, settled and the last note
/// has faded, and (like any ticker) pauses off screen.
class _SpeakerClock extends ChangeNotifier {
  _SpeakerClock(TickerProvider vsync, bool playing) : _on = playing, e = playing ? 1 : 0 {
    _tk = vsync.createTicker(_tick);
    if (playing) {
      // opened mid-song: a couple of notes are already on their way up
      notes.addAll([(id: _id++, born: -1.9), (id: _id++, born: -.95)]);
      _tk.start();
    }
  }

  late final sch.Ticker _tk;
  bool _on;
  double t = 0, beat = 0, e, _wait = 0;
  int _id = 0;
  Duration _last = Duration.zero;
  final notes = <_Rise>[];

  set playing(bool v) {
    if (v == _on) return;
    _on = v;
    _wait = 0;
    if (!_tk.isActive) {
      _last = Duration.zero;
      _tk.start();
    }
  }

  void _tick(Duration now) {
    final dt = ((now - _last).inMicroseconds / 1e6).clamp(0.0, .1);
    _last = now;
    t += dt;
    final goal = _on ? 1.0 : 0.0;
    e += (goal - e) * (1 - math.exp(-dt * 3.5));
    if ((goal - e).abs() < .003) e = goal;
    beat += dt * e;
    notes.removeWhere((n) => t - n.born > _riseLife);
    if (_on && (_wait -= dt) <= 0) {
      notes.add((id: _id, born: t));
      _wait = .7 + .5 * _rnd(_id++ * 7 + 1);
    }
    notifyListeners();
    if (!_on && e == 0 && notes.isEmpty) _tk.stop();
  }

  /// A plausible kick drum (about 117 bpm, each hit a little different), 0..1.
  double kick(double tb) {
    final x = tb * 1.95, i = x.floor(), f = x - i;
    final strength = .45 + .55 * _rnd(i);
    return strength * math.min(1.0, f / .07) * math.exp(-math.max(0.0, f - .07) * 6);
  }

  @override
  void dispose() {
    _tk.dispose();
    super.dispose();
  }
}

/// Draws the Music close-up's speaker over the room: cones that pump with the beat, a
/// faint sound ring off the woofer on each hit, and notes that rise from the speaker and
/// fade. Still (and identical to the room's own speaker) when paused.
class _LiveSpeaker extends StatefulWidget {
  const _LiveSpeaker({required this.fit, required this.playing});
  final _Fit fit;
  final bool playing;
  @override
  State<_LiveSpeaker> createState() => _LiveSpeakerState();
}

class _LiveSpeakerState extends State<_LiveSpeaker> with SingleTickerProviderStateMixin {
  late final _k = _SpeakerClock(this, widget.playing);

  @override
  void didUpdateWidget(_LiveSpeaker old) {
    super.didUpdateWidget(old);
    _k.playing = widget.playing;
  }

  @override
  void dispose() {
    _k.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RepaintBoundary(child: CustomPaint(painter: _SpeakerPainter(_k, widget.fit), size: Size.infinite));
}

class _SpeakerPainter extends CustomPainter {
  _SpeakerPainter(this.k, this.fit) : super(repaint: k);
  final _SpeakerClock k;
  final _Fit fit;

  static const _cols = [Dio.plum, Dio.plum, Dio.coral, Dio.teal];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(fit.tx, fit.ty);
    canvas.scale(fit.k);
    final e = k.e;
    final kick = k.kick(k.beat) * e;
    // hi-hats: twice the kick's rate, softer, with a little wander
    final hx = k.beat * 3.9, hf = hx - hx.floor();
    final hat = e * (.35 + .65 * _rnd(hx.floor() + 77)) * math.exp(-hf * 9);
    _group(canvas, _onY(2.3, 1.45, 3.67), () {
      // a ripple off the woofer's rim on each kick, gone before it leaves the cabinet
      if (e > 0) {
        final f = (k.beat * 1.95) % 1;
        final a = .5 * e * (1 - f) * (1 - f) * (.45 + .55 * _rnd((k.beat * 1.95).floor()));
        if (a > .01) {
          canvas.drawCircle(const Offset(.31, .66), .235 + .07 * Curves.easeOut.transform(f),
              _stroke(Dio.plum.withValues(alpha: a), .022));
        }
      }
      _speakerFace(canvas, kick, hat, e);
    });
    // notes rise to just under the top of the close-up
    final ceil = _vbs[PageId.music]!.top + 14;
    for (final n in k.notes) {
      final age = k.t - n.born, p = (age / _riseLife).clamp(0.0, 1.0);
      double rr(int salt) => _rnd(n.id * 31 + salt);
      final o = _p(2.42 + .4 * rr(1), 1.0 + .3 * rr(2), 3.85);
      final x = o.dx + (rr(3) - .55) * 50 * p + 5 * math.sin(age * (2 + rr(4)) + rr(5) * 6);
      final y = o.dy - math.min(60.0, o.dy - ceil) * Curves.easeOutSine.transform(p);
      final alpha = math.min((p / .14).clamp(0.0, 1.0), ((1 - p) / .45).clamp(0.0, 1.0));
      if (alpha <= .01) continue;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate((rr(6) - .5) * .5 + .15 * math.sin(age * 2.6 + rr(7) * 6));
      canvas.scale((.62 + .3 * rr(8)) * (.6 + .4 * Curves.easeOutBack.transform((p / .2).clamp(0.0, 1.0))));
      final kind = rr(9);
      canvas.drawPath(_notePaths[kind < .4 ? 1 : (kind < .65 ? 2 : 0)],
          _fill(_cols[(rr(10) * _cols.length).floor() % _cols.length].withValues(alpha: alpha)));
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SpeakerPainter o) => o.k != k || o.fit != fit;
}

// ------------------------------------------------------------------ callouts (Home)

typedef _Pin = ({int side, int slot, Offset at, String label, String value, Color color, PageId to});

Rect _pinRect(int side, int slot) => Rect.fromLTWH(side < 0 ? -285 : _vw + 35, 40 + slot * 118.0, 250, 66);

class _PinsPainter extends CustomPainter {
  _PinsPainter(this.pins, this.fit, this.dark);
  final List<_Pin> pins;
  final _Fit fit;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final k = dark ? _night : _day;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(fit.tx, fit.ty);
    canvas.scale(fit.k);
    for (final p in pins) {
      final box = _pinRect(p.side, p.slot);
      final ex = p.side < 0 ? box.right : box.left, ey = box.center.dy;
      _dashed(canvas, [p.at, Offset((p.at.dx + ex) / 2, ey), Offset(ex, ey)], _stroke(p.color, 2.5), 5, 5);
      canvas.drawCircle(p.at, 7, _fill(k.card));
      canvas.drawCircle(p.at, 7, _stroke(p.color, 3.5));
      final rr = RRect.fromRectAndRadius(box, const Radius.circular(18));
      canvas.drawRRect(rr, _fill(k.card));
      canvas.drawRRect(rr, _stroke(p.color, 3));
      _txt(canvas, p.label, box.left + 18, box.top + 26, 20, k.cardLabel, maxW: 214);
      _txt(canvas, p.value, box.left + 18, box.top + 54, 27, k.cardText, w: FontWeight.w600, maxW: 214);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PinsPainter o) => o.fit != fit || o.dark != dark || !listEquals(o.pins, pins);
}

String _digits(Duration d) => d.inHours > 0
    ? '${d.inHours}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}'
    : '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';

String _inText(CalEvent e, DateTime now) {
  if (!e.start.isAfter(now)) return 'now';
  final d = e.start.difference(now);
  return d.inMinutes < 1 ? 'starting now' : 'in ${dur(d)}';
}

List<_Pin> _pinData(WidgetRef ref, DateTime now, TimerState st, bool dark) {
  final sys = topicData<SystemData>(ref, 'system');
  final cl = topicData<ClaudeData>(ref, 'claude');
  final media = topicData<MediaData>(ref, 'media');
  final gh = topicData<GithubData>(ref, 'github');
  final slack = slackHome(ref);
  final w = ref.watch(weatherProvider);
  final s = ref.watch(settingsProvider);
  final n = nextEvent(ref.watch(calendarEventsProvider), now);

  final tLabel = switch (st.mode) {
    TimerMode.focus => 'Focus timer',
    TimerMode.countdown => 'Timer',
    _ => st.mode.label,
  };
  final tState = st.running ? 'running' : (st.pristine ? 'ready' : 'paused');

  final title = media?.title;
  final (mLabel, mValue) = title == null
      ? ('Music', 'Nothing playing')
      : (media!.playing ? 'Now playing' : 'Paused', title.length > 15 ? '${title.substring(0, 14)}…' : title);

  final g = sys?.gpu;
  final top = slack.latest;
  final five = limitPct(cl?.fiveHour, now);

  return [
    (
      side: -1, slot: 0, at: _p(2.3, 0, 4.5), color: Dio.sky, to: PageId.weather,
      label: w?.place ?? 'Weather',
      value: w == null ? '—' : '${temp(w.now.tempC, s.fahrenheit)}° ${w.now.condition.toLowerCase()}',
    ),
    (
      side: -1, slot: 1, at: _p(0, 2.6, 4.9), color: dark ? const Color(0xFFC3C9DE) : _ink, to: PageId.timer,
      label: tLabel, value: '${_digits(st.display(now))} $tState',
    ),
    // the pinboard sits lower than the speaker; slot 2 keeps the two leaders from crossing
    (
      side: -1, slot: 2, at: _p(0, 7.2, 4.4), color: Dio.amber, to: PageId.slack,
      label: top == null ? 'Slack' : 'Slack, from ${top.sender.split(' ').first}',
      value: slack.headline == 'Slack' ? slack.detail : slack.headline,
    ),
    (side: -1, slot: 3, at: _p(2.6, 1.2, 3.6), color: Dio.plum, to: PageId.music, label: mLabel, value: mValue),
    (
      side: 1, slot: 0, at: _p(7.1, 0, 5.2), color: Dio.coral, to: PageId.calendar,
      label: n?.title ?? 'Calendar', value: n == null ? 'Free today' : _inText(n, now),
    ),
    (
      side: 1, slot: 1, at: _p(4.8, 1.07, 4.4), color: Dio.teal, to: PageId.system, label: 'Laptop',
      value: sys == null
          ? '—'
          : 'CPU ${sys.cpu.pct.round()}%, GPU ${g!.available && g.pct != null ? '${g.pct!.round()}%' : 'N/A'}',
    ),
    (
      side: 1, slot: 2, at: _p(6.9, 1.6, 3.9), color: Dio.claude, to: PageId.claude, label: 'Claude, 5-hour',
      value: cl?.fiveHour == null ? '—' : '${five.round()}% used',
    ),
    (
      side: 1, slot: 3, at: _p(7.65, 1.05, 4.2), color: Dio.leaf, to: PageId.github, label: 'GitHub',
      value: gh == null ? '—' : '${gh.streakCurrent}-day streak',
    ),
  ];
}

class _Pins extends ConsumerWidget {
  const _Pins({required this.fit, required this.dark});
  final _Fit fit;
  final bool dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(timerProvider);
    return Ticker(
      key: ValueKey(st.running),
      period: st.running ? const Duration(seconds: 1) : const Duration(minutes: 1),
      builder: (context, now) => CustomPaint(painter: _PinsPainter(_pinData(ref, now, st, dark), fit, dark)),
    );
  }
}

// ------------------------------------------------------------------ hit testing

Path _boxPath(double x, double y, double z, double w, double d, double h) {
  final p = Path();
  for (final f in _faces(x, y, z, w, d, h)) {
    p.addPolygon(f, true);
  }
  return p;
}

Path _rectIn(Float64List m, Rect r) =>
    Path()..addPolygon([r.topLeft, r.topRight, r.bottomRight, r.bottomLeft].map((q) => _apply(m, q)).toList(), true);

/// Tappable objects in drawing order (topmost last).
List<(Path, PageId)> _hits(int leaves) {
  final pp = _p(7.65, 1.05, 3.17);
  final stem = 30 + leaves * 9.0;
  final notes = _p(2.6, .95, 4.4);
  return [
    (_rectIn(_onY(1.0, 0, 5.6), const Rect.fromLTWH(-.2, -.12, 3.0, 2.5)), PageId.weather),
    (_rectIn(_onY(6.3, 0, 5.5), const Rect.fromLTWH(0, 0, 1.7, 2)), PageId.calendar),
    (_rectIn(_onX(0, 2.6, 4.9), const Rect.fromLTWH(-.9, -.9, 1.8, 1.8)), PageId.timer),
    (_rectIn(_onX(0, 7.9, 5.3), const Rect.fromLTWH(-.08, -.3, 1.72, 2.28)), PageId.slack),
    (_boxPath(2.3, .9, 2.72, .62, .55, .95), PageId.music),
    (Path()..addRect(Rect.fromCenter(center: notes, width: 44, height: 50)), PageId.music),
    (_boxPath(4.4, 1.0, 2.72, .8, .5, .56)..addPath(_boxPath(3.6, 1.0, 3.2, 2.4, .14, 1.45), Offset.zero), PageId.system),
    (_boxPath(6.2, 1.55, 2.72, 1.4, 1.1, 1.01), PageId.claude),
    (
      _boxPath(7.4, .8, 2.72, .5, .5, .45)..addRect(Rect.fromLTRB(pp.dx - 24, pp.dy - stem - 6, pp.dx + 24, pp.dy)),
      PageId.github
    ),
  ];
}

PageId? _hitTest(Offset q, int leaves, bool pins) {
  if (pins) {
    for (final (side, slot, to) in const [
      (-1, 0, PageId.weather), (-1, 1, PageId.timer), (-1, 2, PageId.slack), (-1, 3, PageId.music),
      (1, 0, PageId.calendar), (1, 1, PageId.system), (1, 2, PageId.claude), (1, 3, PageId.github),
    ]) {
      if (_pinRect(side, slot).inflate(4).contains(q)) return to;
    }
  }
  for (final (path, to) in _hits(leaves).reversed) {
    if (path.contains(q)) return to;
  }
  return null;
}

// ------------------------------------------------------------------ scene widget

/// CSS `filter: grayscale(.7) brightness(.9)` for the scene while the laptop is offline.
const _offFilter = ColorFilter.matrix([
  .40394, .45058, .04549, 0, 0, //
  .13394, .72058, .04549, 0, 0, //
  .13394, .45058, .31549, 0, 0, //
  0, 0, 0, 1, 0,
]);

class _Scene extends ConsumerWidget {
  const _Scene(this.view, {this.pins = false});
  final PageId view;
  final bool pins;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = Dio.of(context);
    final off = Dio.offlineOf(context);
    return Ticker(
      builder: (context, now) {
        final r = _roomData(ref, now, d.dark,
            code: view == PageId.github ? codeTopic(ref) : 'github',
            phone: view == PageId.hotspot,
            liveSpeaker: view == PageId.music);
        return LayoutBuilder(builder: (context, c) {
          final size = c.biggest;
          final vb = _vbs[view]!;
          final k = math.min(size.width / vb.width, size.height / vb.height);
          final _Fit fit = (
            k: k,
            tx: (size.width - vb.width * k) / 2 - vb.left * k,
            ty: (size.height - vb.height * k) / 2 - vb.top * k,
          );
          Widget w = Stack(fit: StackFit.expand, children: [
            RepaintBoundary(child: CustomPaint(painter: _RoomPainter(r, fit))),
            // still while the laptop is offline (its music state is stale)
            if (r.liveSpeaker) _LiveSpeaker(fit: fit, playing: r.playing && !off),
            if (pins) RepaintBoundary(child: _Pins(fit: fit, dark: d.dark)),
          ]);
          if (off) w = ColorFiltered(colorFilter: _offFilter, child: w);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (e) {
              final q = Offset((e.localPosition.dx - fit.tx) / k, (e.localPosition.dy - fit.ty) / k);
              final to = _hitTest(q, r.leaves, pins);
              if (to != null && to != view) PageNav.go(context, to);
            },
            child: w,
          );
        });
      },
    );
  }
}

// ================================================================== cards & controls

/// [Dio.shadow] without the blur, for a page where something moves: the desk phone would
/// redraw blurred shadows every frame (Impeller keeps no raster cache).
List<BoxShadow> _flatShadow(Dio d) => [
      BoxShadow(color: d.shA, offset: const Offset(0, 4)),
      BoxShadow(color: d.shB, offset: const Offset(0, 1)),
    ];

/// `.card`; [flat] swaps the soft shadow for [_flatShadow].
Widget _card(Dio d, Widget child, {EdgeInsets pad = const EdgeInsets.fromLTRB(14, 11, 14, 11), bool flat = false}) =>
    Container(
      padding: pad,
      decoration: BoxDecoration(
          color: d.card, borderRadius: BorderRadius.circular(20), boxShadow: flat ? _flatShadow(d) : d.shadow),
      child: child,
    );

Widget _lab(Dio d, String s, {TextAlign? align, int lines = 1, double size = 12}) => Text(s,
    style: d.t(size, c: d.mu, h: 1.3), maxLines: lines, overflow: TextOverflow.ellipsis, textAlign: align);

/// `.big` number with an optional `<small>` unit (.45em, muted).
Widget _big(Dio d, String n, double size, {String? small, Color? c}) => Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(n, style: d.t(size, w: FontWeight.w600, c: c, h: .95)),
        if (small != null) ...[
          const SizedBox(width: 2),
          Text(small, style: d.t(size * .45, c: d.mu, h: 1)),
        ],
      ],
    );

/// `.bar`: rounded track with an animated fill.
Widget _bar(Dio d, double v, Color c, {double h = 10}) => SizedBox(
      height: h,
      child: DecoratedBox(
        decoration: BoxDecoration(color: d.track, borderRadius: BorderRadius.circular(99)),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: v.isNaN ? 0 : v.clamp(0, 1)),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
          builder: (context, x, _) => FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: x,
            heightFactor: 1,
            child: DecoratedBox(decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(99))),
          ),
        ),
      ),
    );

enum _K { coral, soft }

/// `.btn`: a chunky key with a 3px bottom edge that presses down.
class _Btn extends StatefulWidget {
  const _Btn({
    this.label,
    this.icon,
    this.onTap,
    this.kind = _K.coral,
    this.on = false,
    this.h = 38,
    this.w,
    this.padH = 18,
    this.radius = 14,
    this.size = 14,
    this.iconSize = 17,
  });
  final String? label, icon;
  final VoidCallback? onTap;
  final _K kind;
  final bool on;
  final double h, padH, radius, size, iconSize;
  final double? w;

  @override
  State<_Btn> createState() => _BtnState();
}

class _BtnState extends State<_Btn> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final d = Dio.of(context);
    final b = widget;
    final (bg, fg, sh) = switch ((b.kind, b.on)) {
      (_K.coral, _) => (Dio.coral, Dio.white, Dio.coralSh),
      (_K.soft, true) => (d.ink, d.card, const Color(0x59000000)),
      (_K.soft, false) => (d.soft, d.ink, d.softsh),
    };
    final enabled = b.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTap: b.onTap,
      child: Opacity(
        opacity: enabled ? 1 : .55,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: b.h,
          width: b.w,
          padding: EdgeInsets.symmetric(horizontal: b.w != null ? 0 : b.padH),
          transform: Matrix4.translationValues(0, _down ? 2 : 0, 0),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(b.radius),
            boxShadow: [BoxShadow(color: sh, offset: Offset(0, _down ? 1 : 3))],
          ),
          alignment: Alignment.center,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (b.icon != null) DpIcon(b.icon!, size: b.iconSize, color: fg, stroke: 2),
            if (b.icon != null && b.label != null) const SizedBox(width: 7),
            if (b.label != null) Text(b.label!, style: d.t(b.size, w: FontWeight.w600, c: fg, h: 1)),
          ]),
        ),
      ),
    );
  }
}

/// Concept `detail()`: the zoomed room in a soft card next to a column of cards.
/// [body] replaces the scrolling column when a page lays out its own right side. [flat]:
/// unblurred shadow (a page whose scene moves).
Widget _detail(BuildContext context, PageId k, List<Widget> right,
    {int l = 110, int r = 100, Widget? body, bool flat = false}) {
  final d = Dio.of(context);
  return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Expanded(
      flex: l,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: flat ? _flatShadow(d) : d.shadow,
          gradient: LinearGradient(
            begin: const Alignment(-.342, -.94),
            end: const Alignment(.342, .94),
            colors: [d.scene0, d.scene1],
          ),
        ),
        child: ClipRect(child: _Scene(k)),
      ),
    ),
    const SizedBox(width: 10),
    Expanded(
      flex: r,
      child: body ?? SingleChildScrollView(
        clipBehavior: Clip.none,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final (i, w) in right.indexed) ...[if (i > 0) const SizedBox(height: 10), w],
        ]),
      ),
    ),
  ]);
}

TextSpan _b(Dio d, String s, {double size = 13.5}) => TextSpan(text: s, style: d.t(size, w: FontWeight.w600));
TextSpan _sm(Dio d, String s, {double size = 12}) => TextSpan(text: s, style: d.t(size, c: d.mu));

// ================================================================== Home

class _Home extends StatelessWidget {
  const _Home();
  @override
  Widget build(BuildContext context) => const _Scene(PageId.home, pins: true);
}

// ================================================================== System

class _System extends ConsumerWidget {
  const _System();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(systemTabProvider);
    final set = ref.read(systemTabProvider.notifier).set;
    final tabs = Row(children: [
      _Btn(label: 'Laptop', kind: _K.soft, on: tab == 0, h: 32, onTap: () => set(0)),
      const SizedBox(width: 6),
      _Btn(label: 'Internet', kind: _K.soft, on: tab == 1, h: 32, onTap: () => set(1)),
    ]);
    return _detail(context, PageId.system, [tabs, ...(tab == 0 ? _pc(context, ref) : _internet(context, ref))]);
  }

  List<Widget> _pc(BuildContext context, WidgetRef ref) {
    final d = Dio.of(context);
    final s = topicData<SystemData>(ref, 'system')!;
    final g = s.gpu;
    const gb = 1024 * 1024 * 1024;
    Widget meter(String l, String sub, double? pct, Color c) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Text(l, style: d.t(13.5, w: FontWeight.w600, h: 1.3)),
              const SizedBox(width: 8),
              Expanded(child: _lab(d, sub)),
              Text(pct == null ? 'N/A' : '${pct.round()}%', style: d.t(20, w: FontWeight.w600, h: .95)),
            ]),
            const SizedBox(height: 4),
            _bar(d, (pct ?? 0) / 100, c),
          ]),
        );
    final vram = g.available && g.vramUsed != null && (g.vramTotal ?? 0) > 0 ? g.vramUsed! / g.vramTotal! * 100 : null;
    final (down, downU) = rate(s.downBps);
    final (up, upU) = rate(s.upBps);
    final f = ref.watch(settingsProvider).fahrenheit;
    final cpuT = s.cpu.tempC;
    return [
      _card(
        d,
        pad: const EdgeInsets.fromLTRB(14, 5, 14, 11),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          meter(
              'Processor',
              [
                s.cpu.cores != null ? '${s.cpu.cores} cores' : s.cpu.model,
                if (cpuT != null) '${temp(cpuT, f)}°${f ? 'F' : 'C'}',
              ].join(', '),
              s.cpu.pct,
              Dio.teal),
          meter('Graphics', !g.available ? 'Not available' : (g.tempC != null ? '${g.tempC!.round()}°C' : (g.model ?? '')),
              g.available ? g.pct : null, Dio.plum),
          meter('Memory', '${(s.ramUsed / gb).toStringAsFixed(1)}/${(s.ramTotal / gb).round()} GB',
              s.ramTotal == 0 ? null : s.ramUsed / s.ramTotal * 100, Dio.sky),
          meter(g.vramLabel == 'VRAM' ? 'Video memory' : g.vramLabel,
              vram == null ? 'N/A' : '${(g.vramUsed! / gb).toStringAsFixed(1)}/${(g.vramTotal! / gb).round()} GB', vram, Dio.coral),
        ]),
      ),
      _card(
        d,
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _lab(d, '${s.cpu.model}${g.model != null ? ', ${g.model}' : ''}'),
          const SizedBox(height: 2),
          Text('$down $downU down, $up $upU up. Disk ${s.diskPct.round()}% used.',
              style: d.t(13.5, h: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
        ]),
      ),
    ];
  }

  List<Widget> _internet(BuildContext context, WidgetRef ref) {
    final d = Dio.of(context);
    final n = topicData<NetworkData>(ref, 'network');
    final live = ref.watch(agentProvider).live;
    if (n == null) {
      return [_card(d, Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Center(child: _lab(d, 'Waiting for network data…', size: 13.5))))];
    }
    final now = DateTime.now();
    final st = n.speedtest, last = st.last, prog = st.progress;
    final shownDown = st.running ? (prog?.downBps ?? 0) : (last?.downBps ?? 0);
    final shownUp = st.running ? (prog?.upBps ?? 0) : (last?.upBps ?? 0);
    final (status, sc) = !live ? ('Unknown', Dio.coral) : (n.online ? ('Online', d.lkfg) : ('Offline', Dio.coral));
    // The laptop's own traffic gets a card between latency and the speed test; the other
    // two tighten up a little so the column still fits.
    final sys = topicData<SystemData>(ref, 'system');
    final tight = sys != null;
    final tested = st.running ? 'Testing now' : (last == null ? 'Never tested' : 'Tested ${ago(now.difference(last.at))}');
    final runBtn = _Btn(
      label: st.running ? 'Testing…' : 'Run test',
      h: 32,
      onTap: st.running ? null : () => act(context, ref, 'speedtest.run', const {}, null, null, const Duration(seconds: 90)),
    );
    return [
      _card(
        d,
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _lab(d, 'Latency'),
              n.latencyMs == null
                  ? _big(d, '—', 40)
                  : _big(d, '${n.latencyMs!.round()}', 40, small: 'ms'),
            ]),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(status, style: d.t(13.5, w: FontWeight.w600, c: sc, h: 1.3)),
              _lab(d, n.onlineSince != null
                  ? 'up ${durLong(now.difference(n.onlineSince!))}'
                  : (n.lastDrop != null ? 'dropped ${ago(now.difference(n.lastDrop!))}' : '')),
            ]),
          ]),
          const SizedBox(height: 6),
          SizedBox(height: tight ? 28 : 46, child: CustomPaint(painter: _LatPainter(n.latencyHistory, d.latfill))),
        ]),
      ),
      if (sys != null) _traffic(d, sys),
      _card(
        d,
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _lab(d, 'Speed test'),
          // With the traffic card above, the button moves up beside the figures to make room.
          Row(children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                    _big(d, last == null && !st.running ? '—' : mbps(shownDown), 30, small: 'down'),
                    const SizedBox(width: 14),
                    _big(d, last == null && !st.running ? '—' : mbps(shownUp), 30, small: 'up'),
                  ]),
                ),
              ),
            ),
            if (tight) ...[const SizedBox(width: 8), runBtn],
          ]),
          SizedBox(height: tight ? 2 : 6),
          if (tight && st.running)
            Row(children: [
              _lab(d, 'Testing now'),
              const SizedBox(width: 10),
              Expanded(child: _bar(d, (prog?.pct ?? 0) / 100, Dio.coral, h: 8)),
            ])
          else
            Row(children: [
              Expanded(child: _lab(d, '$tested, ${bytes(n.usageToday)} today')),
              if (!tight) ...[const SizedBox(width: 8), runBtn],
            ]),
          if (!tight && st.running) ...[const SizedBox(height: 6), _bar(d, (prog?.pct ?? 0) / 100, Dio.coral)],
        ]),
      ),
    ];
  }

  /// What the laptop is moving right now (down and up) beside a sparkline of the last minute.
  Widget _traffic(Dio d, SystemData s) {
    final (down, downU) = rate(s.downBps);
    final (up, upU) = rate(s.upBps);
    Widget now(String icon, Color c, String v, String u) => Row(mainAxisSize: MainAxisSize.min, children: [
          DpIcon(icon, size: 14, color: c, stroke: 2.4),
          const SizedBox(width: 2),
          Text.rich(TextSpan(children: [_b(d, v, size: 16), _sm(d, ' $u')]), maxLines: 1),
        ]);
    return _card(
      d,
      pad: const EdgeInsets.fromLTRB(14, 6, 14, 7),
      Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          _lab(d, 'Laptop traffic now'),
          Row(mainAxisSize: MainAxisSize.min, children: [
            now('down', Dio.teal, down, downU),
            const SizedBox(width: 10),
            now('up', Dio.plum, up, upU),
          ]),
        ]),
        const SizedBox(width: 14),
        Expanded(
          child: SizedBox(
            height: 34,
            child: CustomPaint(painter: _RatePainter(s.downHistory, s.upHistory, d.latfill)),
          ),
        ),
      ]),
    );
  }
}

/// Last minute of laptop traffic: download as a teal line over the soft fill, upload as a
/// thinner plum line, on a shared scale.
class _RatePainter extends CustomPainter {
  _RatePainter(this.down, this.up, this.fill);
  final List<double> down, up;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final peak = [...down, ...up].fold(64 * 1024.0, math.max) * 1.12;
    const pad = 2.0;
    Path? line(List<double> v) {
      if (v.length < 2) return null;
      double y(double x) => pad + (h - 2 * pad) * (1 - (x / peak).clamp(0.0, 1.0));
      final dx = w / (v.length - 1);
      final p = Path()..moveTo(0, y(v[0]));
      for (var i = 1; i < v.length; i++) {
        final xm = (i - .5) * dx;
        p.cubicTo(xm, y(v[i - 1]), xm, y(v[i]), i * dx, y(v[i]));
      }
      return p;
    }

    final dl = line(down), ul = line(up);
    if (dl != null) {
      canvas.drawPath(
          Path.from(dl)
            ..lineTo(w, h)
            ..lineTo(0, h)
            ..close(),
          _fill(fill));
    }
    if (ul != null) canvas.drawPath(ul, _stroke(Dio.plum, 1.8, cap: StrokeCap.round, join: StrokeJoin.round));
    if (dl != null) canvas.drawPath(dl, _stroke(Dio.teal, 2.5, cap: StrokeCap.round, join: StrokeJoin.round));
  }

  @override
  bool shouldRepaint(_RatePainter o) => !identical(o.down, down) || !identical(o.up, up) || o.fill != fill;
}

/// Concept `charts.lat`: smooth latency line over a soft fill (0–50 ms).
class _LatPainter extends CustomPainter {
  _LatPainter(this.vals, this.fill);
  final List<double?> vals;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (vals.length < 2) return;
    final w = size.width, h = size.height;
    const pad = 3.0;
    double y(double? v) => pad + (h - 2 * pad) * (1 - (v ?? 50).clamp(0, 50) / 50);
    final dx = w / (vals.length - 1);
    final line = Path()..moveTo(0, y(vals[0]));
    for (var i = 1; i < vals.length; i++) {
      final xm = (i - .5) * dx;
      line.cubicTo(xm, y(vals[i - 1]), xm, y(vals[i]), i * dx, y(vals[i]));
    }
    final area = Path.from(line)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(area, _fill(fill));
    canvas.drawPath(line, _stroke(Dio.teal, 2.5, join: StrokeJoin.round));
  }

  @override
  bool shouldRepaint(_LatPainter o) => !identical(o.vals, vals) || o.fill != fill;
}

// ================================================================== Claude

class _Claude extends ConsumerWidget {
  const _Claude();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = Dio.of(context);
    final c = topicData<ClaudeData>(ref, 'claude')!;
    final h24 = ref.watch(settingsProvider.select((s) => s.clock24));
    return Ticker(builder: (context, now) {
      final five = limitPct(c.fiveHour, now), week = limitPct(c.sevenDay, now);
      final f = c.fiveHour;
      final reset = f == null || f.resetsAt == null
          ? 'no data yet'
          : (f.isExpired(now) ? 'window has reset' : dur(f.resetsAt!.difference(now)));
      final peak = maxOf(c.days.map((x) => x.tokens));
      return _detail(context, PageId.claude, [
        _card(
          d,
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _lab(d, '5-hour limit'),
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              f == null ? _big(d, '—', 52) : _big(d, '${five.round()}', 52, small: '% used'),
              const Spacer(),
              Text.rich(TextSpan(children: [
                _sm(d, f != null && f.resetsAt != null && !f.isExpired(now) ? 'resets in ' : ''),
                _b(d, reset, size: 12),
              ])),
            ]),
            const SizedBox(height: 6),
            _bar(d, five / 100, Dio.claude, h: 12),
            const SizedBox(height: 10),
            Row(children: [
              _lab(d, 'Weekly'),
              const Spacer(),
              Text(c.sevenDay == null ? '—' : '${week.round()}%', style: d.t(13.5, w: FontWeight.w600, h: 1.3)),
            ]),
            const SizedBox(height: 4),
            _bar(d, week / 100, Dio.mustard),
            const SizedBox(height: 4),
            _lab(d, resetsAt(c.sevenDay, now, h24: h24)),
          ]),
        ),
        _card(
          d,
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              _lab(d, 'Last 7 days'),
              const SizedBox(width: 8),
              Expanded(
                child: _lab(d, '${compact(c.tokens)} tokens today, ${c.messages} messages', align: TextAlign.right),
              ),
            ]),
            const SizedBox(height: 6),
            SizedBox(
              height: 80,
              child: BarTapTip(count: c.days.length, label: (i) => dayTokensLabel(c.days[i], now), child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final (i, day) in c.days.indexed) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(end: 80 * .74 * day.tokens / peak),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        builder: (context, h, _) => Container(
                          width: 22,
                          height: h,
                          decoration: BoxDecoration(
                            color: i == c.days.length - 1 ? Dio.claude : const Color(0xFFF2C7B4),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(8), bottom: Radius.circular(4)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(dayLabel(day.date, now).substring(0, 3), style: d.t(11, c: d.mu, h: 1.3)),
                    ]),
                  ),
                ],
              ])),
            ),
          ]),
        ),
      ]);
    });
  }
}

// ================================================================== Calendar

class _Calendar extends ConsumerWidget {
  const _Calendar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = Dio.of(context);
    final events = ref.watch(calendarEventsProvider);
    final h24 = ref.watch(settingsProvider.select((s) => s.clock24));
    String time(CalEvent e) => e.allDay ? 'All day' : clockFull(e.start, h24: h24);
    return Ticker(builder: (context, now) {
      final split = splitEvents(events, now);
      final n = nextEvent(events, now);
      final today = split.today.where((e) => e != n).take(4).toList();
      final later = split.later.take(3).toList();
      return _detail(context, PageId.calendar, [
        _card(
          d,
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _lab(d, 'Next up'),
            Text(n?.title ?? 'Nothing else today',
                style: d.t(22, w: FontWeight.w600, h: 1.3), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (n != null)
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text(_inText(n, now).replaceFirst('now', 'Now'),
                    style: d.t(36, w: FontWeight.w600, c: Dio.coral, h: .95)),
                const SizedBox(width: 8),
                Expanded(
                  child: _lab(
                      d,
                      n.allDay
                          ? 'All day${n.location != null ? ', ${n.location}' : ''}'
                          : '${clockFull(n.start, h24: h24)} to ${clockFull(n.end, h24: h24)}${n.location != null ? ', ${n.location}' : ''}',
                      align: TextAlign.right),
                ),
              ])
            else
              _lab(d, 'Free until tomorrow'),
          ]),
        ),
        _card(
          d,
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _lab(d, 'Today'),
            if (today.isEmpty) Padding(padding: const EdgeInsets.only(top: 7), child: _lab(d, 'Nothing else today', size: 13.5)),
            for (final e in today)
              Opacity(
                opacity: e.end.isBefore(now) ? .5 : 1,
                child: Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Row(children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: hex(e.color, Dio.sky), borderRadius: BorderRadius.circular(4)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(e.title,
                          style: d.t(13.5, w: FontWeight.w600, h: 1.3), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    _lab(d, '${time(e)}${e.location != null ? ', ${e.location}' : ''}'),
                  ]),
                ),
              ),
            const SizedBox(height: 12),
            _lab(d, 'Later this week'),
            if (later.isEmpty) Padding(padding: const EdgeInsets.only(top: 5), child: _lab(d, 'Nothing else this week', size: 13.5)),
            for (final e in later)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Row(children: [
                  Expanded(
                    child: Text(e.title,
                        style: d.t(13.5, w: FontWeight.w600, h: 1.3), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  _lab(d, '${weekday3(e.start)} ${time(e)}'),
                ]),
              ),
          ]),
        ),
      ]);
    });
  }
}

// ================================================================== Weather

class _Weather extends ConsumerWidget {
  const _Weather();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = Dio.of(context);
    final w = ref.watch(weatherProvider);
    final f = ref.watch(settingsProvider.select((s) => s.fahrenheit));
    if (w == null) {
      return _detail(context, PageId.weather, [
        _card(d, Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: _lab(d, 'Set your location in Settings → Weather', size: 13.5, align: TextAlign.center),
        )),
      ]);
    }
    return _detail(context, PageId.weather, [
      _card(
        d,
        Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _lab(d, w.place),
            _big(d, '${temp(w.now.tempC, f)}°', 56),
          ]),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(w.now.condition, style: d.t(18, w: FontWeight.w600, h: 1.3), maxLines: 1, overflow: TextOverflow.ellipsis),
              _lab(d,
                  'Feels like ${temp(w.now.feelsC, f)}°, humidity ${w.now.humidity}%, wind ${wind(w.now.windKmh, f)}',
                  lines: 2),
            ]),
          ),
        ]),
      ),
      _card(
        d,
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _lab(d, 'This week'),
          const SizedBox(height: 6),
          Row(children: [
            for (final (i, day) in w.days.take(6).indexed)
              Expanded(
                child: Column(children: [
                  _lab(d, i == 0 ? 'Today' : weekday3(day.date)),
                  const SizedBox(height: 4),
                  DpIcon(day.icon, size: 22, color: day.icon == 'rain' ? Dio.rain : const Color(0xFF8A93A6)),
                  const SizedBox(height: 4),
                  Text.rich(TextSpan(children: [
                    _b(d, '${temp(day.hiC, f)}°'),
                    const TextSpan(text: ' '),
                    _sm(d, '${temp(day.loC, f)}°', size: 13.5),
                  ])),
                  SizedBox(
                    height: 15,
                    child: Text(day.precipPct > 0 ? '${day.precipPct}%' : '', style: d.t(11.5, c: Dio.rain, h: 1.3)),
                  ),
                ]),
              ),
          ]),
        ]),
      ),
    ]);
  }
}

// ================================================================== Music

class _Music extends ConsumerWidget {
  const _Music();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = Dio.of(context);
    final m = topicData<MediaData>(ref, 'media')!;
    final art = topicData<MediaArt>(ref, 'media.art');
    final skew = ref.read(agentProvider.notifier).clockSkewMs;
    // The speaker in the scene moves while music plays, so this page's shadows are flat.
    return _detail(context, PageId.music, flat: true, [
      _card(
        d,
        flat: true,
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [BoxShadow(color: Color(0x262B2D42), offset: Offset(0, 4))],
              ),
              child: AlbumArt(
                  title: m.title ?? 'Nothing playing', b64: art?.artId == m.artId ? art?.b64 : null, radius: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _lab(d, m.source ?? 'Laptop'),
                Text(m.title ?? 'Nothing playing',
                    style: d.t(21, w: FontWeight.w600, h: 1.1), maxLines: 2, overflow: TextOverflow.ellipsis),
                if (m.artist != null) _lab(d, m.artist!),
              ]),
            ),
          ]),
          Ticker(
            period: const Duration(seconds: 1),
            builder: (context, now) {
              final pos = m.positionNow(now, skewMs: skew);
              final total = m.durationMs ?? 0;
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SizedBox(height: 6),
                _Seek(
                  value: total == 0 ? 0 : pos / total,
                  enabled: m.canSeek && total > 0,
                  onSeek: (f) => act(context, ref, 'media.seek', {'position_ms': (f * total).round()}),
                ),
                Row(children: [
                  _lab(d, mmss(pos)),
                  const Spacer(),
                  _lab(d, total == 0 ? '' : '-${mmss(total - pos)}'),
                ]),
              ]);
            },
          ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _Btn(icon: 'prev', kind: _K.soft, w: 48, onTap: () => act(context, ref, 'media.prev')),
            const SizedBox(width: 10),
            _Btn(
              icon: m.playing ? 'pause' : 'play',
              w: 76,
              h: 46,
              radius: 16,
              iconSize: 19,
              onTap: () => act(context, ref, 'media.play_pause'),
            ),
            const SizedBox(width: 10),
            _Btn(icon: 'next', kind: _K.soft, w: 48, onTap: () => act(context, ref, 'media.next')),
          ]),
          const SizedBox(height: 3),
        ]),
      ),
    ]);
  }
}

/// Tap / drag to seek: the bar follows the finger, one seek is sent on release.
class _Seek extends StatefulWidget {
  const _Seek({required this.value, required this.onSeek, required this.enabled});
  final double value;
  final bool enabled;
  final ValueChanged<double> onSeek;
  @override
  State<_Seek> createState() => _SeekState();
}

class _SeekState extends State<_Seek> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final d = Dio.of(context);
    return LayoutBuilder(builder: (context, c) {
      double f(Offset p) => (p.dx / c.maxWidth).clamp(0.0, 1.0);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: widget.enabled ? (e) => widget.onSeek(f(e.localPosition)) : null,
        onHorizontalDragStart: widget.enabled ? (e) => setState(() => _drag = f(e.localPosition)) : null,
        onHorizontalDragUpdate: widget.enabled ? (e) => setState(() => _drag = f(e.localPosition)) : null,
        onHorizontalDragEnd: widget.enabled
            ? (_) {
                widget.onSeek(_drag!);
                setState(() => _drag = null);
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 2),
          child: _bar(d, _drag ?? widget.value, Dio.plum),
        ),
      );
    });
  }
}

// ================================================================== Hotspot

/// The Hotspot Monitor Overview (the roof phone sharing mobile data).
class _Hotspot extends ConsumerWidget {
  const _Hotspot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = Dio.of(context);
    final h = topicData<HotspotData>(ref, 'hotspot')!;
    final f = ref.watch(settingsProvider).fahrenheit;
    const t = DioramaSkin.t;
    return Ticker(builder: (context, now) {
      final st = hsState(h);
      final col = _hsCol(st);
      final alert = hsAlert(h, now);
      final bad = st != HsState.ok && st != HsState.lowBattery;
      final head = _card(
        d,
        pad: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: bad ? d.offbg : (st == HsState.ok ? d.lkbg : Dio.amber.withValues(alpha: .22)),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: DpIcon(h.online ? 'hotspot' : 'off',
                  size: 20, color: bad ? d.offfg : (st == HsState.ok ? d.lkfg : Dio.amber), stroke: 2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                  Flexible(
                    child: Text(hsStateLabel(h),
                        style: d.t(20, w: FontWeight.w600, h: 1.15, c: st == HsState.ok ? d.ink : (bad ? d.offfg : col)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  Text(hsSeen(h, now), style: d.t(12, c: d.mu)),
                ]),
                _lab(d, [hsNetwork(h), ?h.operator, hsSharing(h)].join(', ')),
              ]),
            ),
          ]),
          if (alert != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              decoration: BoxDecoration(color: d.offbg, borderRadius: BorderRadius.circular(12)),
              child: Text(alert,
                  style: d.t(12.5, w: FontWeight.w600, c: d.offfg, h: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          ],
        ]),
      );
      final grade = hsGradeColor(h.grade, t);
      final (down, downU) = hsBpsParts(h.rxBps);
      final (up, upU) = hsBpsParts(h.txBps);
      final (used, usedU) = hsBytesParts(h.cycleUsed);
      final q = h.quotaFrac;
      final temp = hsTemp(h.batteryC, fahrenheit: f);
      final sp = temp.lastIndexOf(' ');
      final heat = switch (h.heat) {
        HotspotHeat.hot => Dio.coral,
        HotspotHeat.warm => Dio.amber,
        _ => null,
      };
      final tiles = <Widget>[
        _tile(d, 'Signal score', _big(d, h.score == null ? '—' : '${h.score!.round()}', 26, small: '/100'), hsSignalLine(h),
            tag: Text(hsGradeLabel(h.grade), style: d.t(12.5, w: FontWeight.w600, c: grade, h: 1.3)),
            bar: _bar(d, (h.score ?? 0) / 100, grade, h: 6)),
        _tile(
            d,
            'Speed now',
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              _big(d, down, 26, small: '$downU down'),
              const SizedBox(width: 10),
              _big(d, up, 26, small: 'up'),
            ]),
            hsPingLine(h)),
        _tile(d, 'Battery', _big(d, h.batteryPct == null ? '—' : '${h.batteryPct!.round()}', 26, small: '%', c: h.lowBattery ? Dio.coral : null),
            hsPowerLine(h),
            tag: Text(hsCurrent(h.currentMa), style: d.t(12.5, w: FontWeight.w600, c: d.mu, h: 1.3)),
            bar: _bar(d, (h.batteryPct ?? 0) / 100, h.lowBattery ? Dio.coral : Dio.leaf, h: 6)),
        _tile(d, 'Temperature', _big(d, sp < 0 ? temp : temp.substring(0, sp), 26, small: sp < 0 ? null : temp.substring(sp + 1), c: heat),
            hsHeatLine(h, fahrenheit: f),
            tag: h.radioResting ? Text('Radio resting', style: d.t(12.5, w: FontWeight.w600, c: Dio.coral, h: 1.3)) : null),
        _tile(d, 'Data this cycle', _big(d, used, 26, small: usedU), hsTodayLine(h),
            tag: Text(h.quota == null ? 'No quota' : 'of ${hsBytes(h.quota)}', style: d.t(12, c: d.mu, h: 1.3)),
            bar: q == null ? null : _bar(d, q, q >= 1 ? Dio.coral : (q >= .8 ? Dio.amber : Dio.sky), h: 6)),
        _tile(d, 'Uptime', _big(d, hsUptime(h.uptimeS), 26), 'Agent ${hsUptime(h.agentUptimeS)}, ${_lower(hsBootLine(h))}'),
      ];
      Widget row(int i) => Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: tiles[i]),
              const SizedBox(width: 8),
              Expanded(child: tiles[i + 1]),
            ]),
          );
      return _detail(
        context,
        PageId.hotspot,
        const [],
        l: 90,
        r: 110,
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          head,
          const SizedBox(height: 8),
          row(0),
          const SizedBox(height: 8),
          row(2),
          const SizedBox(height: 8),
          row(4),
        ]),
      );
    });
  }

  /// A compact card: label (+ a tag on the right), big value with an optional bar beside
  /// it, one muted line.
  /// The muted line drops out when the card is too short to hold it.
  Widget _tile(Dio d, String label, Widget value, String sub, {Widget? tag, Widget? bar}) => Container(
        padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
        decoration: BoxDecoration(color: d.card, borderRadius: BorderRadius.circular(16), boxShadow: d.shadow),
        child: LayoutBuilder(builder: (context, box) {
          final showSub = box.maxHeight >= 54;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Row(children: [
                Expanded(child: _lab(d, label)),
                if (tag != null) ...[const SizedBox(width: 6), tag],
              ]),
              Row(children: [
                Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: value)),
                if (bar != null) ...[const SizedBox(width: 12), Expanded(child: bar)],
              ]),
              if (showSub)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(sub, maxLines: 1, style: d.t(11.5, c: d.mu, h: 1.3)),
                ),
            ],
          );
        }),
      );
}

String _lower(String s) => s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

// ================================================================== Timer

class _Timer extends ConsumerWidget {
  const _Timer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = Dio.of(context);
    final st = ref.watch(timerProvider);
    final ctl = ref.read(timerProvider.notifier);
    return Ticker(
      key: ValueKey(st.running),
      period: st.running ? const Duration(seconds: 1) : const Duration(minutes: 1),
      builder: (context, now) => _detail(context, PageId.timer, [
        _card(
          d,
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _lab(d, st.mode.label),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Center(
                child: FittedBox(
                  child: Text(_digits(st.display(now)),
                      style: d.t(78, w: FontWeight.w600, c: st.running ? Dio.coral : d.ink, h: .95)),
                ),
              ),
            ),
            _bar(d, st.progress(now), Dio.coral, h: 12),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                for (final (i, m) in TimerMode.values.indexed) ...[
                  if (i > 0) const SizedBox(width: 6),
                  _Btn(
                    label: m.label,
                    kind: _K.soft,
                    on: m == st.mode,
                    h: 32,
                    padH: 12,
                    onTap: () => ctl.setMode(m),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _Btn(
                  icon: st.running ? 'pause' : 'play',
                  label: st.running ? 'Pause' : (st.pristine ? 'Start' : 'Resume'),
                  onTap: ctl.toggle,
                ),
                const SizedBox(width: 8),
                _Btn(label: 'Reset', kind: _K.soft, onTap: ctl.reset),
                if (st.mode == TimerMode.countdown && !st.running) ...[
                  const SizedBox(width: 14),
                  _Btn(label: '−', kind: _K.soft, w: 38, size: 18, onTap: () => ctl.adjust(-1)),
                  const SizedBox(width: 8),
                  Text('${st.countdownMin} min', style: d.t(13.5, w: FontWeight.w600)),
                  const SizedBox(width: 8),
                  _Btn(label: '+', kind: _K.soft, w: 38, size: 18, onTap: () => ctl.adjust(1)),
                ],
              ]),
            ),
            const SizedBox(height: 8),
            _lab(d, '${st.sessions} of 4 focus sessions today', align: TextAlign.center),
          ]),
        ),
      ]),
    );
  }
}

// ================================================================== Slack

class _Slack extends ConsumerWidget {
  const _Slack();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = Dio.of(context);
    final s = topicData<SlackData>(ref, 'slack')!;
    final unread = s.unreadMessages;
    final top = unread.isEmpty ? null : unread.first;
    return Ticker(builder: (context, now) {
      final head = _card(
        d,
        pad: const EdgeInsets.fromLTRB(14, 11, 12, 11),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _lab(d, s.team == null ? 'Slack' : 'Slack, ${s.team}'),
              const SizedBox(height: 2),
              s.unread == 0
                  ? Text('All caught up',
                      style: d.t(22, w: FontWeight.w600, h: 1.15), maxLines: 1, overflow: TextOverflow.ellipsis)
                  : _big(d, '${s.unread}', 30, small: 'unread', c: Dio.coral),
            ]),
          ),
          if (s.unread > 0) ...[
            const SizedBox(width: 8),
            _Btn(label: 'Mark all read', kind: _K.soft, h: 32, padH: 12, size: 12.5, onTap: () => slackReadAll(context, ref)),
          ] else
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: d.lkbg, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: DpIcon('slack', size: 20, color: d.lkfg, stroke: 2),
            ),
        ]),
      );
      final list = _card(
        d,
        pad: const EdgeInsets.fromLTRB(6, 6, 6, 6),
        s.messages.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('No messages yet', style: d.t(16, w: FontWeight.w600)),
                  const SizedBox(height: 2),
                  _lab(d, 'DMs and mentions get pinned here', size: 13, align: TextAlign.center),
                ]),
              )
            : ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: s.messages.length,
                itemBuilder: (context, i) => _row(context, ref, d, s.messages[i], now, featured: s.messages[i] == top),
              ),
      );
      return _detail(
        context,
        PageId.slack,
        const [],
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          head,
          const SizedBox(height: 10),
          Expanded(child: list),
        ]),
      );
    });
  }

  Widget _row(BuildContext context, WidgetRef ref, Dio d, SlackMsg m, DateTime now, {bool featured = false}) {
    final c = hex(m.senderColor, Dio.plum);
    final av = featured ? 40.0 : 32.0;
    return Press(
      onTap: () => slackOpen(context, ref, m),
      scale: .985,
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: EdgeInsets.fromLTRB(8, featured ? 10 : 7, 10, featured ? 10 : 7),
        decoration: BoxDecoration(
          color: featured ? Dio.coral.withValues(alpha: d.dark ? .14 : .09) : null,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Opacity(
          opacity: m.unread ? 1 : .55,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: av,
              height: av,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(av * .32),
                boxShadow: [BoxShadow(color: Color.lerp(c, const Color(0xFF000000), .3)!, offset: const Offset(0, 2))],
              ),
              alignment: Alignment.center,
              child: Text(m.initials,
                  style: d.t(av * .36,
                      w: FontWeight.w600, c: c.computeLuminance() > .45 ? _ink : Dio.white, h: 1)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                  Expanded(
                    child: Text.rich(
                        TextSpan(children: [
                          TextSpan(text: m.sender, style: d.t(featured ? 15.5 : 13.5, w: FontWeight.w600, h: 1.3)),
                          TextSpan(text: '  ${slackWhere(m)}', style: d.t(12, c: d.mu, h: 1.3)),
                        ]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 6),
                  Text.rich(TextSpan(children: [
                    TextSpan(
                        text: slackTime(m.ts, now),
                        style: d.t(12,
                            w: m.unread ? FontWeight.w600 : FontWeight.w500, c: m.unread ? Dio.coral : d.mu)),
                    if (m.unread)
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: const BoxDecoration(color: Dio.coral, shape: BoxShape.circle),
                        ),
                      ),
                  ])),
                ]),
                const SizedBox(height: 1),
                Text(m.text,
                    style: d.t(featured ? 14 : 12.5, c: featured ? d.ink : d.mu, h: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ]),
            ),
            Transform.translate(
              offset: Offset(6, featured ? 0 : -3),
              child: SlackReadTick(m, color: Dio.coral, fill: Dio.coral, onFill: Dio.white, radius: 9, size: featured ? 30 : 26),
            ),
          ]),
        ),
      ),
    );
  }
}

// ================================================================== GitHub

class _Github extends ConsumerWidget {
  const _Github();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = Dio.of(context);
    final g = topicData<GithubData>(ref, codeTopic(ref))!;
    final best = g.bestDay;
    final src = ref.watch(codeSourceProvider);
    final set = ref.read(codeSourceProvider.notifier).set;
    final tabs = Row(children: [
      for (final (i, l) in codeSources.indexed) ...[
        if (i > 0) const SizedBox(width: 6),
        _Btn(label: l, kind: _K.soft, on: src == i, h: 32, onTap: () => set(i)),
      ],
    ]);
    return _detail(context, PageId.github, l: 100, r: 125, [
      tabs,
      _card(
        d,
        Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _lab(d, 'Streak, one leaf per day'),
            _big(d, '${g.streakCurrent}', 52, small: g.streakCurrent == 1 ? 'day' : 'days', c: d.leafink),
          ]),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              _lab(d, 'Longest ${g.streakLongest}', align: TextAlign.right),
              _lab(d, best == null ? 'Best day —' : 'Best day ${best.count}, ${month3(best.date)} ${best.date.day}',
                  align: TextAlign.right),
              _lab(d, '${g.weekTotal} this week (${g.weekDelta >= 0 ? '+' : ''}${g.weekDelta})', align: TextAlign.right),
            ]),
          ),
        ]),
      ),
      _card(
        d,
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            _lab(d, 'Last 12 months'),
            const Spacer(),
            _lab(d, '${_thousands(g.total)} contributions'),
          ]),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, c) => SizedBox(
              height: 7 * c.maxWidth / 53,
              child: CustomPaint(
                size: Size.infinite,
                painter: _HeatPainter(g.weeks, [d.track, d.h1, d.h2, Dio.leaf, d.h4]),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 14, runSpacing: 6, children: [
            for (final r in g.topRepos.take(4))
              Text.rich(TextSpan(children: [_b(d, r.name), const TextSpan(text: ' '), _sm(d, '${r.count}', size: 13.5)])),
          ]),
        ]),
      ),
    ]);
  }
}

String _thousands(int n) => n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

/// Concept `charts.heat`: 53 week columns of rounded squares, no labels.
class _HeatPainter extends CustomPainter {
  _HeatPainter(this.weeks, this.levels);
  final List<List<ContribDay>> weeks;
  final List<Color> levels;

  @override
  void paint(Canvas canvas, Size size) {
    final ws = weeks.length > 53 ? weeks.sublist(weeks.length - 53) : weeks;
    final cw = size.width / 53, cs = cw - 2;
    for (final (x, week) in ws.indexed) {
      for (final day in week) {
        final y = day.date.weekday % 7;
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x * cw, y * cw, cs, cs), Radius.circular(cs / 3)),
          _fill(levels[day.level.clamp(0, 4)]),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_HeatPainter o) => !identical(o.weeks, weeks) || !listEquals(o.levels, levels);
}

// ================================================================== Shortcuts

class _Shortcuts extends ConsumerWidget {
  const _Shortcuts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = topicData<ShortcutsData>(ref, 'shortcuts')!;
    final order = ref.watch(settingsProvider.select((x) => x.tileOrder));
    final tiles = orderedTiles(s.tiles, order);
    final rows = <List<Tile>>[
      for (var i = 0; i < tiles.length; i += 4) tiles.sublist(i, math.min(i + 4, tiles.length)),
    ];
    return Column(children: [
      for (final (ri, row) in rows.indexed) ...[
        if (ri > 0) const SizedBox(height: 10),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: i < row.length
                    ? _Key(tile: row[i], vol: s.volumePct, onTap: () => act(context, ref, 'shortcut.run', {'id': row[i].id}))
                    : const SizedBox(),
              ),
            ],
          ]),
        ),
      ],
      const SizedBox(height: 5),
    ]);
  }
}

Color _keyColor(Tile t, Dio d) {
  final id = t.id;
  if (id.startsWith('mic')) return Dio.coral;
  if (id.startsWith('sound')) return Dio.amber;
  if (id.startsWith('volume')) return Dio.teal;
  if (id.startsWith('screenshot')) return Dio.plum;
  if (id.startsWith('terminal')) return d.ink;
  if (id.startsWith('downloads')) return Dio.sky;
  if (id.startsWith('lock')) return Dio.leaf;
  return hex(t.color, d.ink);
}

/// `.key`: a big keycap with a 5px edge; coral while the tile is on.
class _Key extends StatefulWidget {
  const _Key({required this.tile, required this.vol, required this.onTap});
  final Tile tile;
  final int? vol;
  final VoidCallback onTap;
  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final d = Dio.of(context);
    final t = widget.tile, on = t.active;
    final detail = t.detail ?? (t.id.startsWith('volume') && widget.vol != null ? 'Volume ${widget.vol}%' : null);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.translationValues(0, _down ? 3 : 0, 0),
        decoration: BoxDecoration(
          color: on ? Dio.coral : d.card,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(color: on ? Dio.coralSh : d.softsh, offset: Offset(0, _down ? 2 : 5)),
            if (!_down) BoxShadow(color: d.keySh, blurRadius: 18, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          DpIcon(tileIcon(t), size: 30, color: on ? Dio.white : _keyColor(t, d), stroke: 2.1),
          const SizedBox(height: 8),
          Text(tileLabel(t),
              style: d.t(14.5, w: FontWeight.w600, c: on ? Dio.white : d.ink, h: 1.3),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          if (detail != null) ...[
            const SizedBox(height: 8),
            Text(detail, style: d.t(12, c: on ? Dio.white : d.mu, h: 1.3)),
          ],
        ]),
      ),
    );
  }
}
