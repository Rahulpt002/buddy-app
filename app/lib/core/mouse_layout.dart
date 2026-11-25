import 'dart:ui';

/// One of the Mac's displays, from the agent's `mouse.displays` (global points; mm = 0 when
/// the display doesn't report its physical size).
class MacDisplay {
  MacDisplay(Map<String, dynamic> j)
      : rect = Rect.fromLTWH((j['x'] as num).toDouble(), (j['y'] as num).toDouble(), (j['w'] as num).toDouble(),
            (j['h'] as num).toDouble()),
        mmW = (j['mm_w'] as num?)?.toDouble() ?? 0,
        main = (j['main'] as bool?) ?? false,
        builtin = (j['builtin'] as bool?) ?? false;
  final Rect rect;
  final double mmW;
  final bool main, builtin;
}

/// The phone's size in Mac points, so it's drawn (and the mouse moves) to scale next to
/// [d]: Android lays out ~160 logical px per inch; the display knows its own mm. Without a
/// physical size, one phone pixel = one Mac point.
Size phoneSizeInPoints(Size phoneLogical, MacDisplay d) {
  if (d.mmW <= 0) return phoneLogical;
  final ptPerMm = d.rect.width / d.mmW;
  const mmPerDp = 25.4 / 160;
  return phoneLogical * (mmPerDp * ptPerMm);
}

/// Snaps [phone] (anywhere, e.g. where it was dropped) to the nearest spot touching the
/// outside of a display edge, overlapping that edge by at least a quarter of the phone's
/// side, and not covering any display. Returns [phone] unchanged if there are no displays.
Rect snapPhone(List<Rect> displays, Rect phone) {
  final c = phone.center;
  final w = phone.width, h = phone.height;
  Rect? best;
  var bestD = double.infinity;
  for (final d in displays) {
    final mx = w / 4, my = h / 4;
    double cx(double x) => x.clamp(d.left - w + mx, d.right - mx).toDouble();
    double cy(double y) => y.clamp(d.top - h + my, d.bottom - my).toDouble();
    final candidates = [
      Rect.fromLTWH(cx(c.dx - w / 2), d.bottom, w, h), // below
      Rect.fromLTWH(cx(c.dx - w / 2), d.top - h, w, h), // above
      Rect.fromLTWH(d.left - w, cy(c.dy - h / 2), w, h), // left
      Rect.fromLTWH(d.right, cy(c.dy - h / 2), w, h), // right
    ];
    for (final r in candidates) {
      if (displays.any((o) => _overlaps(o, r))) continue;
      final dist = (r.center - c).distanceSquared;
      if (dist < bestD) {
        bestD = dist;
        best = r;
      }
    }
  }
  return best ?? phone;
}

bool _overlaps(Rect a, Rect b) {
  final i = a.intersect(b);
  return i.width > .5 && i.height > .5;
}

/// A short description for Settings: "Below your screen, at the left".
String describePlacement(List<Rect> displays, Rect phone) {
  if (displays.isEmpty) return 'Placed';
  Rect? touching;
  String side = '';
  for (final d in displays) {
    if ((phone.top - d.bottom).abs() < 1) {
      touching = d;
      side = 'Below';
    } else if ((phone.bottom - d.top).abs() < 1) {
      touching = d;
      side = 'Above';
    } else if ((phone.right - d.left).abs() < 1) {
      touching = d;
      side = 'Left of';
    } else if ((phone.left - d.right).abs() < 1) {
      touching = d;
      side = 'Right of';
    }
    if (touching != null) break;
  }
  if (touching == null) return 'Not touching a screen';
  final d = touching;
  final horizontal = side == 'Below' || side == 'Above';
  final f = horizontal ? (phone.center.dx - d.left) / d.width : (phone.center.dy - d.top) / d.height;
  final where = horizontal
      ? (f < .36 ? 'at the left' : f > .64 ? 'at the right' : 'in the middle')
      : (f < .36 ? 'near the top' : f > .64 ? 'near the bottom' : 'in the middle');
  final screen = displays.length > 1 ? (d == displays.first ? 'your main screen' : 'a screen') : 'your screen';
  return '$side $screen, $where';
}

/// Union of rects.
Rect boundsOf(Iterable<Rect> rs) => rs.reduce((a, b) => a.expandToInclude(b));
