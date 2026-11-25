// Concept 10 — Departures pages. Sizes follow deskpanel-concept-10-departures.html
// (CSS px = logical px). Every value is a run of split-flap cells (DepFlaps); bars are
// rows of coloured chips. Times are 24-hour by design.
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
import '../widgets/common.dart';
import 'departures.dart';

const _t = DeparturesSkin.t;
const _y = DeparturesSkin.yl;
const _g = DeparturesSkin.gr;
const _r = DeparturesSkin.rd;
const _b = DeparturesSkin.bl;
const _off = DeparturesSkin.off;
const _dark = DeparturesSkin.caseC;

Widget departuresPage(PageId id) => switch (id) {
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
  PageId.shortcuts => const _Keys(),
};

// ------------------------------------------------------------------ board parts

String _hm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

/// Flap run of [n] cells.
Widget _fl(Object? text, int n, {Color? c, bool right = false}) => DepFlaps('${text ?? ''}', n, color: c, right: right);

/// `.rw`: one board row; rows cascade their entry flip top to bottom.
Widget _rw(int r, List<Widget> cells, {VoidCallback? onTap, double gap = 10}) {
  Widget row = Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final (i, c) in cells.indexed) ...[if (i > 0) SizedBox(width: gap), c],
    ],
  );
  if (onTap != null) row = Press(onTap: onTap, scale: .99, child: row);
  return DepRowDelay(ms: r * 45, child: row);
}

TextStyle _lblS({double ls = 1.54}) => depText(11, c: _y, ls: ls);

/// `.lbl` / single `.colh` heading.
Widget _lbl(String s, {double ls = 1.54}) => Text(s.toUpperCase(), style: _lblS(ls: ls), maxLines: 1, softWrap: false);

/// `.colh`: column headings sized to the flap runs below them.
Widget _colh(List<(String, int)> cols) => Padding(
  padding: const EdgeInsets.only(bottom: 4),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final (i, (s, n)) in cols.indexed) ...[
        if (i > 0) const SizedBox(width: 10),
        SizedBox(
          width: FlapSize.md.span(n),
          child: Text(s.toUpperCase(), style: _lblS(), maxLines: 1, softWrap: false, overflow: TextOverflow.visible),
        ),
      ],
    ],
  ),
);

/// `.board`: rows with a 6 px gap.
Widget _board(List<Widget> rows, {double gap = 6}) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  mainAxisSize: MainAxisSize.min,
  children: [
    for (final (i, r) in rows.indexed) ...[if (i > 0) SizedBox(height: gap), r],
  ],
);

/// Page body: top-left aligned, scrolls rather than overflowing on short screens.
Widget _pg(Widget child) => Align(
  alignment: Alignment.topLeft,
  child: SingleChildScrollView(
    physics: const ClampingScrollPhysics(),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      child: child,
    ),
  ),
);

/// `HEAT`: green < 50% ≤ yellow < 80% ≤ red along the row.
Color _heat(double f) => f < .5 ? _g : (f < .8 ? _y : _r);

/// `.ch`: row of [n] chips, lit up to [p] (heat colours unless [color]).
Widget _chips(double p, int n, {Color? color, double w = 17, double h = 26}) {
  final lit = (p.isFinite ? p.clamp(0.0, 1.0) : 0.0) * n;
  final k = lit.round();
  return _ChipRow([for (var i = 0; i < n; i++) i < k ? (color ?? _heat((i + 1) / n)) : _off], w: w, h: h);
}

class _ChipRow extends StatelessWidget {
  const _ChipRow(this.colors, {this.w = 17, this.h = 26, this.ring = false});
  final List<Color> colors;
  final double w, h;
  static const gap = 2.0;
  final bool ring;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final (i, c) in colors.indexed) ...[
        if (i > 0) SizedBox(width: gap),
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(3),
            border: ring ? Border.all(color: const Color(0x38FFFFFF)) : null,
          ),
        ),
      ],
    ],
  );
}

String _inText(CalEvent e, DateTime now) {
  if (!e.start.isAfter(now)) return 'Now';
  final d = e.start.difference(now);
  return d.inMinutes < 1 ? 'Now' : 'in ${dur(d)}';
}

/// Board time for a message: "12:51" today, else "YEST", "MON" or "NOV 3".
String _when(DateTime ts, DateTime now) {
  final days = DateTime(now.year, now.month, now.day).difference(DateTime(ts.year, ts.month, ts.day)).inDays;
  if (days <= 0) return _hm(ts);
  if (days == 1) return 'Yest';
  if (days < 7) return weekday3(ts);
  return '${month3(ts)}${'${ts.day}'.padLeft(2)}';
}

String _cpuName(String m) => m.replaceFirst(RegExp(r'\s+\d+-Core.*$'), '');
String _gpuName(String? m) => (m ?? '').replaceFirst('GeForce ', '');
const _gb = 1024 * 1024 * 1024;

// ------------------------------------------------------------------ Home

class _Home extends ConsumerWidget {
  const _Home();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void go(PageId p) => PageNav.go(context, p);
    return Ticker(
      builder: (context, now) {
        final events = ref.watch(calendarEventsProvider);
        final n = nextEvent(events, now);
        final today = splitEvents(events, now).today.where((e) => e.end.isAfter(now)).take(3);
        final sl = slackHome(ref);
        final c = topicData<ClaudeData>(ref, 'claude');
        final w = ref.watch(weatherProvider);
        final f = ref.watch(settingsProvider.select((s) => s.fahrenheit));
        final s = topicData<SystemData>(ref, 'system');
        final m = topicData<MediaData>(ref, 'media');

        // Timed departures, sorted like a real board.
        final items = <(DateTime, String, String, String, Color?, PageId)>[
          for (final e in today)
            (
              e.start,
              e.allDay ? 'ALL' : _hm(e.start),
              e.title,
              e == n ? _inText(e, now) : (e.location ?? e.calendar ?? ''),
              e == n ? _y : null,
              PageId.calendar,
            ),
        ];
        // Slack arrives on the board at its newest unread message's time; with nothing
        // unread it has no time and waits below the timed rows.
        final slm = sl.latest;
        if (slm != null) {
          items.add((slm.ts, _when(slm.ts, now), 'Slack ${slm.sender}', sl.headline, _y, PageId.slack));
        }
        final fw = c?.fiveHour;
        if (fw?.resetsAt != null && !fw!.isExpired(now)) {
          final pct = limitPct(fw, now);
          items.add((
            fw.resetsAt!,
            _hm(fw.resetsAt!),
            'Claude 5h reset',
            '${pct.round()}% used',
            usageColor(pct, _t),
            PageId.claude,
          ));
        }
        items.sort((a, b) => a.$1.compareTo(b.$1));
        final timed = items.take(5).toList(); // 3 events + Claude + Slack: never trims Slack.

        final gpu = s != null && s.gpu.available && s.gpu.pct != null ? ' GPU ${s.gpu.pct!.round()}%' : '';
        var r = 0;
        return _pg(
          _board([
            _colh(const [('Time', 5), ('What', 20), ('Status', 12)]),
            if (timed.isEmpty) _rw(r++, [_fl('--:--', 5), _fl('Nothing scheduled', 20), _fl('', 12)]),
            for (final it in timed)
              _rw(r++, [_fl(it.$2, 5), _fl(it.$3, 20), _fl(it.$4, 12, c: it.$5)], onTap: () => go(it.$6)),
            if (slm == null)
              _rw(r++, [
                _fl('--:--', 5),
                _fl('Slack', 20),
                sl.headline == 'All caught up'
                    ? _fl('Caught up', 12, c: _g)
                    : _fl(sl.detail == '—' ? '' : sl.detail, 12),
              ], onTap: () => go(PageId.slack)),
            _rw(r++, [
              _fl('Now', 5, c: _y),
              _fl(w == null ? 'No location set' : '${temp(w.now.tempC, f)}° ${w.now.condition}', 20),
              _fl(w == null || w.days.isEmpty ? '' : 'High ${temp(w.days.first.hiC, f)}°', 12),
            ], onTap: () => go(PageId.weather)),
            _rw(r++, [
              _fl('Live', 5, c: _y),
              _fl(s == null ? 'Laptop offline' : 'CPU ${s.cpu.pct.round()}%$gpu', 20),
              _fl(s?.gpu.tempC == null ? '' : '${s!.gpu.tempC!.round()}°C', 12),
            ], onTap: () => go(PageId.system)),
            _rw(r++, [
              _fl(m?.title == null ? 'Idle' : (m!.playing ? 'Play' : 'Pause'), 5, c: _y),
              _fl(m?.title ?? 'Nothing playing', 20),
              _fl(m?.artist ?? '', 12),
            ], onTap: () => go(PageId.music)),
          ]),
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

class _Pc extends ConsumerWidget {
  const _Pc();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = topicData<SystemData>(ref, 'system')!;
    final g = s.gpu;
    final ramPct = s.ramUsed / s.ramTotal * 100;
    final vramPct = g.vramUsed != null && (g.vramTotal ?? 0) > 0 ? g.vramUsed! / g.vramTotal! * 100 : null;
    final (down, downU) = rate(s.downBps);
    final (up, upU) = rate(s.upBps);
    final gpuPct = g.available ? g.pct : null;
    return _pg(
      _board([
        _colh(const [('Unit', 5), ('Load', 9), ('Level', 18), ('Detail', 9)]),
        _rw(0, [
          _fl('CPU', 5),
          _fl('${s.cpu.pct.round()}%', 9),
          _chips(s.cpu.pct / 100, 18),
          _fl(s.cpu.cores == null ? '' : '${s.cpu.cores}C ${s.cpu.threads ?? s.cpu.cores}T', 9),
        ]),
        _rw(1, [
          _fl('GPU', 5),
          _fl(gpuPct == null ? 'N/A' : '${gpuPct.round()}%', 9),
          _chips((gpuPct ?? 0) / 100, 18),
          _fl(g.tempC == null ? '' : '${g.tempC!.round()}°C', 9),
        ]),
        _rw(2, [
          _fl('RAM', 5),
          _fl('${(s.ramUsed / _gb).toStringAsFixed(1)}/${(s.ramTotal / _gb).round()}G', 9),
          _chips(ramPct / 100, 18),
          _fl('${ramPct.round()}%', 9),
        ]),
        _rw(3, [
          _fl(g.vramLabel, 5),
          _fl(
            vramPct == null ? 'N/A' : '${(g.vramUsed! / _gb).toStringAsFixed(1)}/${(g.vramTotal! / _gb).round()}G',
            9,
          ),
          _chips((vramPct ?? 0) / 100, 18),
          _fl(vramPct == null ? '' : '${vramPct.round()}%', 9),
        ]),
        _rw(4, [_fl('Disk', 5), _fl('${s.diskPct.round()}%', 9), _chips(s.diskPct / 100, 18, color: _b), _fl('', 9)]),
        _rw(5, [_fl('Down', 5), _fl('$down $downU', 9), _fl('', 18), _fl('', 9)]),
        _rw(6, [_fl('Up', 5), _fl('$up $upU', 9), _fl('', 18), _fl('', 9)]),
        _rw(7, [_fl('Chip', 5, c: _y), _fl(_cpuName(s.cpu.model), 18), _fl(_gpuName(g.model), 18)]),
      ]),
    );
  }
}

class _Internet extends ConsumerWidget {
  const _Internet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = topicData<NetworkData>(ref, 'network');
    if (n == null) {
      return _pg(
        _board([
          _colh(const [('Item', 8), ('Value', 10)]),
          _rw(0, [_fl('Status', 8), _fl('Waiting', 10, c: _y)]),
        ]),
      );
    }
    final live = ref.watch(agentProvider).live;
    final now = DateTime.now();
    final st = n.speedtest, last = st.last, prog = st.progress;
    final status = !live ? 'Unknown' : (n.online ? 'Online' : 'Offline');
    final lat = n.latencyHistory.length > 18
        ? n.latencyHistory.sublist(n.latencyHistory.length - 18)
        : n.latencyHistory;
    final speed = st.running
        ? '${mbps(prog?.downBps ?? 0)}/${mbps(prog?.upBps ?? 0)}'
        : (last == null ? '—' : '${mbps(last.downBps)}/${mbps(last.upBps)}');
    final dropped = n.lastDrop == null ? null : ago(now.difference(n.lastDrop!));
    return _pg(
      _board([
        _colh(const [('Item', 8), ('Value', 10), ('Last 18 seconds', 18)]),
        _rw(0, [
          _fl('Status', 8),
          _fl(status, 10, c: live && n.online ? _g : _r),
          _fl(n.onlineSince == null ? '' : 'Up ${durLong(now.difference(n.onlineSince!))}', 18),
        ]),
        _rw(1, [
          _fl('Latency', 8),
          _fl(n.latencyMs == null ? 'Timeout' : '${n.latencyMs!.round()} ms', 10),
          _ChipRow([
            for (var i = 0; i < 18; i++)
              i < lat.length ? (lat[i] == null ? _r : (lat[i]! > 28 ? _r : (lat[i]! > 20 ? _y : _g))) : _off,
          ]),
        ]),
        _rw(2, [
          _fl('Jitter', 8),
          _fl(n.jitterMs == null ? '—' : '${n.jitterMs!.toStringAsFixed(1)} ms', 10),
          _fl('Loss ${n.lossPct.round()}%', 18),
        ]),
        _rw(3, [
          _fl('Dropped', 8),
          _fl(dropped == null ? 'Never' : dropped.replaceFirst(' ago', ''), 10),
          _fl(dropped == null || !dropped.endsWith(' ago') ? '' : 'ago', 18),
        ]),
        _rw(4, [_fl('Today', 8), _fl(bytes(n.usageToday), 10), _fl('', 18)]),
        _rw(5, [_fl('Month', 8), _fl(bytes(n.usageMonth, digits: 0), 10), _fl('', 18)]),
        _rw(6, [
          _fl('Speed', 8),
          _fl(speed, 10),
          _fl(st.running ? 'Testing' : (last == null ? 'Never' : ago(now.difference(last.at))), 13),
          DepBtn(
            label: st.running ? 'Testing…' : 'Run test',
            onTap: st.running
                ? null
                : () => act(context, ref, 'speedtest.run', const {}, null, null, const Duration(seconds: 90)),
          ),
        ]),
        if (st.running) _rw(7, [_fl('', 8), _fl('', 10), _chips((prog?.pct ?? 0) / 100, 18, color: _y)]),
      ]),
    );
  }
}

// ------------------------------------------------------------------ Claude

class _Claude extends ConsumerWidget {
  const _Claude();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = topicData<ClaudeData>(ref, 'claude')!;
    return Ticker(
      builder: (context, now) {
        final five = limitPct(c.fiveHour, now), week = limitPct(c.sevenDay, now);
        String inT(LimitWindow? w) =>
            w?.resetsAt == null ? '—' : (w!.isExpired(now) ? 'Reset' : dur(w.resetsAt!.difference(now)));
        String atT(LimitWindow? w) => w?.resetsAt == null || w!.isExpired(now) ? '' : _hm(w.resetsAt!.toLocal());
        final wk = c.sevenDay;
        final wkReset = wk?.resetsAt == null
            ? '—'
            : (wk!.isExpired(now) ? 'Reset' : '${weekday3(wk.resetsAt!.toLocal())} ${_hm(wk.resetsAt!.toLocal())}');
        final mx = maxOf(c.days.map((d) => d.tokens));
        final left = _board([
          _colh(const [('Limit', 7), ('Used', 5), ('Level', 14)]),
          _rw(0, [_fl('5-hour', 7), _fl(c.fiveHour == null ? '—' : '${five.round()}%', 5), _chips(five / 100, 14)]),
          _rw(1, [_fl('Resets', 7, c: _y), _fl(inT(c.fiveHour), 8), _fl(atT(c.fiveHour), 5, c: _y)]),
          _rw(2, [_fl('Weekly', 7), _fl(wk == null ? '—' : '${week.round()}%', 5), _chips(week / 100, 14)]),
          _rw(3, [_fl('Resets', 7, c: _y), _fl(wkReset, 13)]),
          _rw(4, [_fl('Tokens', 7), _fl(compact(c.tokens), 7)]),
          _rw(5, [_fl('Output', 7), _fl(compact(c.outputTokens), 7)]),
          _rw(6, [_fl('Msgs', 7), _fl('${c.messages}', 7)]),
          _rw(7, [_fl('Hour', 7), _fl(compact(c.lastHourTokens), 7)]),
        ]);
        final right = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _lbl('Tokens, last 7 days'),
            const SizedBox(height: 10),
            BarTapTip(
              count: c.days.length,
              label: (i) => dayTokensLabel(c.days[i], now),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final (i, d) in c.days.indexed) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Builder(
                      builder: (context) {
                        final lit = (d.tokens / mx * 7).round();
                        final isToday = i == c.days.length - 1;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                dayLabel(
                                  d.date,
                                  now,
                                ).substring(0, math.min(3, dayLabel(d.date, now).length)).toUpperCase(),
                                style: _lblS(ls: .66),
                              ),
                            ),
                            for (var r = 6; r >= 0; r--) ...[
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                width: 22,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: r < lit ? (isToday ? _g : _y) : _off,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              if (r > 0) const SizedBox(height: 2),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            _board([
              if (c.modelsToday.isEmpty) _rw(8, [_fl('None', 7), _fl('', 6)]),
              for (final (i, m) in c.modelsToday.take(4).indexed)
                _rw(8 + i, [_fl(modelName(m.family), 7), _fl(compact(m.tokens), 6, c: _g)]),
            ]),
          ],
        );
        return _pg(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [left, const SizedBox(width: 28), right],
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
    return Ticker(
      builder: (context, now) {
        final split = splitEvents(events, now);
        final n = nextEvent(events, now);
        final today = split.today.take(4).toList();
        final later = split.later.take(math.max(2, 7 - math.max(1, today.length))).take(4).toList();
        (String, Color?) remark(CalEvent e) {
          if (e == n) return (_inText(e, now), _y);
          if (!e.end.isAfter(now)) return ('Done', null);
          if (e.start.difference(now).inMinutes < 240) return ('On time', _g);
          return ('Later', null);
        }

        var r = 0;
        return _pg(
          _board([
            _colh(const [('Time', 5), ('Event', 16), ('Where', 12), ('Remarks', 9)]),
            if (today.isEmpty) _rw(r++, [_fl('--:--', 5), _fl('Nothing today', 16), _fl('', 12), _fl('', 9)]),
            for (final e in today)
              Builder(
                builder: (context) {
                  final (rem, rc) = remark(e);
                  return _rw(r++, [
                    _fl(e.allDay ? 'ALL' : _hm(e.start), 5),
                    _fl(e.title, 16),
                    _fl(e.location ?? e.calendar ?? '', 12),
                    _fl(rem, 9, c: rc),
                  ]);
                },
              ),
            Padding(padding: const EdgeInsets.only(top: 4), child: _colh(const [('Later this week', 16)])),
            if (later.isEmpty) _rw(r++, [_fl('', 5), _fl('Nothing planned', 16), _fl('', 12), _fl('', 9)]),
            for (final e in later)
              _rw(r++, [
                _fl(weekday3(e.start), 5, c: _y),
                _fl(e.title, 16),
                _fl(e.location ?? e.calendar ?? '', 12),
                _fl(e.allDay ? 'All day' : _hm(e.start), 9),
              ]),
          ]),
        );
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
    final f = ref.watch(settingsProvider.select((s) => s.fahrenheit));
    if (w == null) {
      return _pg(
        _board([
          _colh(const [('Now', 8), ('', 10)]),
          _rw(0, [_fl('Location', 8), _fl('Not set', 10, c: _y)]),
          _lbl('Set your location in Settings'),
        ]),
      );
    }
    final u = f ? '°F' : '°C';
    final left = _board([
      _colh(const [('Now', 8), ('', 10)]),
      _rw(0, [_fl(w.place, 18, c: _y)]),
      _rw(1, [_fl('Temp', 8), _fl('${temp(w.now.tempC, f)}$u', 10)]),
      _rw(2, [_fl('Sky', 8), _fl(w.now.condition, 10)]),
      _rw(3, [_fl('Feels', 8), _fl('${temp(w.now.feelsC, f)}$u', 10)]),
      _rw(4, [_fl('Humidity', 8), _fl('${w.now.humidity}%', 10)]),
      _rw(5, [_fl('Wind', 8), _fl(wind(w.now.windKmh, f), 10)]),
    ]);
    final right = _board([
      _colh(const [('Day', 5), ('High/low', 7), ('Rain', 4), ('Chance', 10)]),
      for (final (i, d) in w.days.take(6).indexed)
        _rw(i, [
          _fl(i == 0 ? 'Today' : weekday3(d.date), 5, c: _y),
          _fl('${temp(d.hiC, f)}/${temp(d.loC, f)}', 7),
          _fl(d.precipPct > 0 ? '${d.precipPct}%' : 'Dry', 4, c: d.precipPct > 50 ? _b : null),
          _ChipRow([for (var k = 0; k < 10; k++) k < (d.precipPct / 10).round() ? _b : _off], ring: true),
        ]),
      Padding(padding: const EdgeInsets.only(top: 2), child: _lbl('Updated ${_hm(w.now.updated)}')),
    ]);
    return _pg(
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [left, const SizedBox(width: 18), right],
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
    final skew = ref.read(agentProvider.notifier).clockSkewMs;
    final title = m.title ?? 'Nothing playing';
    final board = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _board([
          _colh([('Now playing on ${m.source ?? 'laptop'}', 20)]),
          _rw(0, [_fl(title, 20)]),
          _rw(1, [_fl(m.artist ?? '', 20, c: _y)]),
          _rw(2, [_fl(m.album ?? '', 20)]),
          Ticker(
            period: const Duration(seconds: 1),
            builder: (context, now) {
              final pos = m.positionNow(now, skewMs: skew);
              final total = m.durationMs ?? 0;
              final tt = total == 0 ? mmss(pos) : '${mmss(pos)}/${mmss(total)}';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _rw(3, [
                    _fl(tt, math.max(9, tt.length)),
                    _fl(m.title == null ? 'Idle' : (m.playing ? 'Playing' : 'Paused'), 10, c: m.playing ? _g : _y),
                  ]),
                  const SizedBox(height: 6),
                  _SeekChips(
                    value: total == 0 ? 0 : pos / total,
                    enabled: m.canSeek && total > 0,
                    onSeek: (f) => act(context, ref, 'media.seek', {'position_ms': (f * total).round()}),
                  ),
                ],
              );
            },
          ),
        ]),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DepBtn(icon: 'prev', height: 40, hPad: 18, onTap: () => act(context, ref, 'media.prev')),
            const SizedBox(width: 8),
            DepBtn(
              icon: m.playing ? 'pause' : 'play',
              label: m.playing ? 'Pause' : 'Play',
              height: 40,
              hPad: 26,
              onTap: () => act(context, ref, 'media.play_pause'),
            ),
            const SizedBox(width: 8),
            DepBtn(icon: 'next', height: 40, hPad: 18, onTap: () => act(context, ref, 'media.next')),
          ],
        ),
      ],
    );
    return _pg(
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _ChipArt(hue: hueFor(title), seed: stableHash(title) % 7 + 1),
          const SizedBox(width: 28),
          board,
        ],
      ),
    );
  }
}

/// Seek bar as a row of 20 wide chips; tap or drag to seek.
class _SeekChips extends StatefulWidget {
  const _SeekChips({required this.value, required this.enabled, required this.onSeek});
  final double value;
  final bool enabled;
  final ValueChanged<double> onSeek;
  @override
  State<_SeekChips> createState() => _SeekChipsState();
}

class _SeekChipsState extends State<_SeekChips> {
  double? _drag;
  static const _n = 20, _w = 25.0;
  static const _width = _n * _w + (_n - 1) * 2;

  double _f(Offset p) => (p.dx / _width).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapUp: widget.enabled ? (d) => widget.onSeek(_f(d.localPosition)) : null,
    onHorizontalDragStart: widget.enabled ? (d) => setState(() => _drag = _f(d.localPosition)) : null,
    onHorizontalDragUpdate: widget.enabled ? (d) => setState(() => _drag = _f(d.localPosition)) : null,
    onHorizontalDragEnd: widget.enabled
        ? (_) {
            widget.onSeek(_drag!);
            setState(() => _drag = null);
          }
        : null,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: _chips(_drag ?? widget.value, _n, color: _g, w: _w),
    ),
  );
}

/// Album art as an 8×8 chip mosaic (port of the concept's `mosaic()`).
class _ChipArt extends StatelessWidget {
  const _ChipArt({required this.hue, required this.seed});
  final double hue;
  final int seed;
  static const n = 8, cw = 25.0, gap = 3.0;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: n * cw + (n - 1) * gap,
    child: CustomPaint(painter: _ChipArtPainter(hue, seed)),
  );
}

class _ChipArtPainter extends CustomPainter {
  _ChipArtPainter(this.hue, this.seed);
  final double hue;
  final int seed;

  Color _hsl(double h, double s, double l) => HSLColor.fromAHSL(1, h % 360, s / 100, l / 100).toColor();

  @override
  void paint(Canvas canvas, Size size) {
    const n = _ChipArt.n, cw = _ChipArt.cw, gap = _ChipArt.gap;
    final sx = (30 + (seed * 37) % 40) / 100 * n, sy = (34 + (seed * 13) % 10) / 100 * n;
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        final fx = (x + .5) / n * 100, fy = (y + .5) / n * 100;
        var c = _hsl(hue, 55, 22 + fy / 100 * 22);
        final dx = x + .5 - sx, dy = y + .5 - sy;
        if (math.sqrt(dx * dx + dy * dy) < .17 * n) c = _hsl(44, 95, 80);
        if (fy > 62 - 6 * math.sin(fx / 100 * 5.6)) c = _hsl(hue + 6, 45, 30);
        if (fy > 79 - 5 * math.sin(fx / 100 * 3.8 + 1)) c = _hsl(hue, 55, 16);
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x * (cw + gap), y * (cw + gap), cw, cw), const Radius.circular(3)),
          Paint()..color = c,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ChipArtPainter o) => o.hue != hue || o.seed != seed;
}

// ------------------------------------------------------------------ Hotspot

/// The Hotspot Monitor Overview (the roof phone sharing mobile data) as two boards: the
/// readings on medium flaps (status, signal, speed, battery, heat, data) and, on small
/// flaps beside it, the phone's link details over the latest events, newest first.
class _Hotspot extends ConsumerWidget {
  const _Hotspot();

  static const _sm = FlapSize.sm;
  static const _md = FlapSize.md;
  static const _gap = 10.0;
  static const _lbW = 6; // small-board label column

  /// Small-flap run.
  static Widget _f(String s, int n, {Color? c}) => DepFlaps(_flap(s), n, size: _sm, color: c);

  /// Board text: arrows have no flap.
  static String _flap(String s) => s.replaceAll('→', '>');

  static Color _heatC(HotspotData d) =>
      d.radioResting || d.heat == HotspotHeat.hot ? _r : (d.heat == HotspotHeat.warm ? _y : _g);

  /// The state on 19 flaps: "Radio resting (heat)" loses its aside.
  static String _state(HotspotData d) {
    final s = hsStateLabel(d);
    return s.length > 19 ? s.replaceFirst(RegExp(r'\s*\(.*\)$'), '') : s;
  }

  /// "149/300GB" when the quota shares the unit, else "149 GB".
  static String _dataNow(HotspotData d) {
    final (v, u) = hsBytesParts(d.cycleUsed);
    if (d.quota == null || d.cycleUsed == null) return hsBytes(d.cycleUsed);
    final (qv, qu) = hsBytesParts(d.quota);
    return qu == u ? '$v/$qv$u' : hsBytes(d.cycleUsed);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = topicData<HotspotData>(ref, 'hotspot')!;
    final f = ref.watch(settingsProvider.select((s) => s.fahrenheit));
    return Ticker(
      builder: (context, now) => LayoutBuilder(
        builder: (context, box) {
          final left = _readings(d, f);
          // Left board: 7 + 9 + 10 md cells and two column gaps.
          final leftW = _md.span(7) + _md.span(9) + _md.span(10) + 2 * _gap;
          final rightW = math.max(260.0, box.maxWidth - leftW - 22);
          final valN = math.max(12, ((rightW - _sm.span(_lbW) - _gap + _sm.gap) / (_sm.w + _sm.gap)).floor());
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: box.maxHeight,
                child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.topLeft, child: left),
              ),
              const SizedBox(width: 22),
              Expanded(
                child: SizedBox(height: box.maxHeight, child: _side(d, now, valN, rightW, box.maxHeight)),
              ),
            ],
          );
        },
      ),
    );
  }

  /// The readings board (medium flaps, nine rows).
  Widget _readings(HotspotData d, bool f) {
    final gc = hsGradeColor(d.grade, _t);
    final frac = d.quotaFrac;
    final dataC = frac == null ? null : (frac >= 1 ? _r : (frac >= .8 ? _y : null));
    final (down, downU) = hsBpsParts(d.rxBps);
    final (up, upU) = hsBpsParts(d.txBps);
    final bat = d.batteryPct;
    final batC = d.lowBattery ? _r : null;
    // Battery temperature on a 20-50 °C scale, lit in the heat colour.
    final heat = d.batteryC == null ? 0.0 : ((d.batteryC! - 20) / 30).clamp(0.0, 1.0);
    var r = 0;
    return _board([
      _colh(const [('Item', 7), ('Now', 9), ('Level', 10)]),
      _rw(r++, [
        _fl('Status', 7),
        // The state spans Now + Level.
        SizedBox(
          width: _md.span(9) + _md.span(10) + _gap,
          child: _fl(_state(d), 19, c: hsStateColor(d, _t)),
        ),
      ]),
      _rw(r++, [
        _fl('Signal', 7),
        _fl(d.score == null ? '—' : '${d.score!.round()}/100', 9),
        _chips((d.score ?? 0) / 100, 10, color: gc),
      ]),
      _rw(r++, [
        _fl('Grade', 7),
        _fl(hsGradeLabel(d.grade), 9, c: gc),
        _fl(d.rsrp == null ? '' : 'RSRP ${d.rsrp!.round()}', 10),
      ]),
      _rw(r++, [
        _fl('Down', 7),
        _fl(d.rxBps == null ? '—' : '$down $downU', 9),
        _fl(d.pingMs == null ? 'Ping —' : 'Ping ${d.pingMs!.round()} ms', 10),
      ]),
      _rw(r++, [
        _fl('Up', 7),
        _fl(d.txBps == null ? '—' : '$up $upU', 9),
        _fl(d.lossPct == null ? '' : 'Loss ${d.lossPct!.round()}%', 10),
      ]),
      _rw(r++, [
        _fl('Battery', 7, c: batC),
        _fl(bat == null ? '—' : '${bat.round()}%', 9, c: batC),
        _chips((bat ?? 0) / 100, 10, color: d.lowBattery ? _r : _g),
      ]),
      _rw(r++, [
        _fl('Temp', 7),
        _fl(hsTemp(d.batteryC, fahrenheit: f), 9, c: d.heat == HotspotHeat.ok && !d.radioResting ? null : _heatC(d)),
        d.radioResting ? _fl('Resting', 10, c: _r) : _chips(heat, 10, color: _heatC(d)),
      ]),
      _rw(r++, [
        _fl('Data', 7),
        _fl(_dataNow(d), 9, c: dataC),
        frac == null ? _fl('No quota', 10) : _chips(frac, 10, color: dataC ?? _b),
      ]),
      _rw(r++, [
        _fl('Today', 7),
        _fl(hsBytes(d.todayUsed), 9),
        _fl(d.cycleStart == null ? '' : 'From ${month3(d.cycleStart!)} ${d.cycleStart!.day}', 10),
      ]),
    ]);
  }

  /// Link details and the latest events (small flaps), with any alert announced on top.
  Widget _side(HotspotData d, DateTime now, int valN, double w, double h) {
    final alert = hsAlert(d, now);
    final session = hsSessionNote(d, now);
    final seen = d.lastSeen == null ? 'Never' : ago(now.difference(d.lastSeen!));
    final rows = <(String, String, Color?)>[
      ('Radio', hsNetwork(d), null),
      ('SIM', d.operator ?? '—', null),
      (
        'Tether',
        hsSharing(d).length > valN ? hsSharing(d).replaceFirst('Sharing ', '') : hsSharing(d),
        d.tetherOn == true ? _g : null,
      ),
      ('Seen', seen, d.online ? null : _r),
      ('Power', '${hsCurrent(d.currentMa)} ${d.chargeStatus ?? ''}', d.lowBattery ? _r : null),
      ('Uptime', '${hsUptime(d.uptimeS)} · agent ${hsUptime(d.agentUptimeS)}', null),
      ('Boot', hsBootLine(d).replaceFirst('Boot ', ''), null),
    ];
    final rowH = _sm.h + 5;
    // Alert (two text lines), the details board, then as many events as fit.
    final alertSt = depText(13, c: _r, ls: .6, h: 1.25);
    final alertH = alert == null
        ? 0.0
        : (TextPainter(
                text: TextSpan(text: alert.toUpperCase(), style: alertSt),
                textDirection: TextDirection.ltr,
                maxLines: 2,
              )..layout(maxWidth: w)).height +
              10;
    final sessionH = session == null ? 0.0 : 18.0;
    const colhH = 18.5; // 11 px label × 1.3 + 4
    final detailsH = colhH + rows.length * rowH - 5;
    final evN = math.max(0, ((h - alertH - sessionH - detailsH - 10 - colhH + 5) / rowH).floor());
    final events = d.events.take(evN).toList();
    var r = 0;
    Widget colh(List<(String, int)> cols) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, (s, n)) in cols.indexed) ...[
            if (i > 0) const SizedBox(width: _gap),
            SizedBox(
              width: _sm.span(n),
              child: Text(s.toUpperCase(), style: _lblS(), maxLines: 1, softWrap: false),
            ),
          ],
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (alert != null)
          SizedBox(
            height: alertH,
            child: Text(alert.toUpperCase(), style: alertSt, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                colh([(d.name ?? 'Phone', _lbW), ('', valN)]),
                _board([
                  for (final (k, v, c) in rows) _rw(r++, [_f(k, _lbW, c: _y), _f(v, valN, c: c)], gap: _gap),
                ], gap: 5),
                const SizedBox(height: 10),
                colh([('Time', _lbW), ('Latest events', valN)]),
                if (d.events.isEmpty)
                  _rw(r++, [_f('--:--', _lbW), _f('No events', valN)], gap: _gap)
                else
                  _board([
                    for (final e in events)
                      _rw(r++, [
                        _f(_Slack._when(e.ts, now), _lbW),
                        _f(e.message, valN, c: e.severity == 'info' ? null : hsEventColor(e, _t)),
                      ], gap: _gap),
                  ], gap: 5),
              ],
            ),
          ),
        ),
        if (session != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(session.toUpperCase(), style: _lblS(), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
      ],
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
    final label = switch (st.mode) {
      TimerMode.stopwatch => 'Stopwatch, counting up',
      _ => '${st.mode.label}, ${st.total.inMinutes} minutes',
    };
    return Ticker(
      period: const Duration(milliseconds: 250),
      builder: (context, now) {
        final d = st.display(now);
        final digits = d.inHours > 0
            ? '${d.inHours}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}'
            : '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
        return Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _lbl(label),
                const SizedBox(height: 16),
                DepFlaps(digits, digits.length, size: FlapSize.big, color: st.running ? _g : null, right: true),
                const SizedBox(height: 16),
                _chips(st.progress(now), 25, color: _y, w: 14, h: 10),
                const SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (i, m) in TimerMode.values.indexed) ...[
                      if (i > 0) const SizedBox(width: 6),
                      DepBtn(label: m.label, pressed: m == st.mode, onTap: () => ctl.setMode(m)),
                    ],
                    const SizedBox(width: 16),
                    DepBtn(
                      label: st.running ? 'Pause' : (st.pristine ? 'Start' : 'Resume'),
                      bg: _g,
                      fg: _dark,
                      onTap: ctl.toggle,
                    ),
                    const SizedBox(width: 6),
                    DepBtn(label: 'Reset', onTap: ctl.reset),
                    if (st.mode == TimerMode.countdown && !st.running) ...[
                      const SizedBox(width: 16),
                      DepBtn(label: '−', onTap: () => ctl.adjust(-1)),
                      const SizedBox(width: 6),
                      DepBtn(label: '+', onTap: () => ctl.adjust(1)),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                _lbl('${st.sessions} of 4 focus sessions today'),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------------ Slack

/// The inbox as a departures board on small flaps (so the message column is wide enough
/// to read): time, the sender's initials as a coloured "flight code", sender, where, the
/// message and a remark: a "✓ READ" button on unread rows, READ once it's read. The header reads out the newest unread message.
class _Slack extends ConsumerWidget {
  const _Slack();

  static const _sm = FlapSize.sm;
  static const _gap = 10.0;
  static const _cols = [5, 2, 10, 10, 0, 6]; // 0 = message, takes the rest
  static const _muted = Color(0xFFA8A398);
  static const _faint = Color(0xFF6E6A62);

  static Widget _f(String s, int n, {Color? c, bool right = false}) =>
      DepFlaps(s, n, size: _sm, color: c, right: right);

  /// slackTime on five cells.
  static String _when(DateTime ts, DateTime now) {
    final t = slackTime(ts, now);
    return t == 'Yesterday' ? 'Yest' : t;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = topicData<SlackData>(ref, 'slack')!;
    final latest = s.unreadMessages.firstOrNull;
    return Ticker(
      builder: (context, now) => LayoutBuilder(
        builder: (context, box) {
          final fixed = _cols.where((n) => n > 0).fold(0.0, (a, n) => a + _sm.span(n)) + (_cols.length - 1) * _gap;
          final msgN = math.max(8, ((box.maxWidth - fixed + _sm.gap) / (_sm.w + _sm.gap)).floor());
          final cols = [for (final n in _cols) n == 0 ? msgN : n];
          Widget fit(Widget w) => FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: w);

          final head = Row(
            children: [
              DepFlaps('${math.min(s.unread, 99)}', 2, size: FlapSize.med, color: s.unread > 0 ? _y : _g, right: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (s.unread == 0 ? 'All caught up' : (s.unread == 1 ? 'Unread message' : 'Unread messages'))
                          .toUpperCase(),
                      style: depText(11, c: s.unread > 0 ? _y : _g, ls: 1.54),
                      maxLines: 1,
                    ),
                    Text(
                      (latest == null
                              ? (s.messages.isEmpty ? 'No messages on the board' : 'Nothing new since you last looked')
                              : 'Latest: ${latest.sender}, ${slackWhere(latest)}: ${latest.text}')
                          .toUpperCase(),
                      style: depText(13, c: latest == null ? _muted : DeparturesSkin.wh, ls: .6),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (s.unread > 0) ...[
                const SizedBox(width: 12),
                DepBtn(label: 'Mark all read', onTap: () => slackReadAll(context, ref)),
              ],
            ],
          );

          final colh = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, (l, n)) in [
                ('Time', cols[0]),
                ('', cols[1]),
                ('From', cols[2]),
                ('Where', cols[3]),
                ('Message', cols[4]),
                ('Remarks', cols[5]),
              ].indexed) ...[
                if (i > 0) const SizedBox(width: _gap),
                SizedBox(
                  width: _sm.span(n),
                  child: Text(l.toUpperCase(), style: _lblS(), maxLines: 1, softWrap: false),
                ),
              ],
            ],
          );

          Widget row(int r, SlackMsg m) {
            final on = m.unread;
            final c = on ? null : _muted;
            final code = hex(m.senderColor);
            return _rw(
              math.min(r, 12),
              [
                _f(_when(m.ts, now), cols[0], c: c),
                _f(m.initials, cols[1], c: on ? code : code.withValues(alpha: .5)),
                _f(m.sender, cols[2], c: c),
                _f(slackWhere(m), cols[3], c: on ? _y : _muted),
                _f(m.text, cols[4], c: c),
                // Unread: a flap button that marks just this one read.
                on
                    ? SizedBox(
                        width: _sm.span(cols[5]),
                        child: DepBtn(
                          icon: 'check',
                          label: 'Read',
                          height: _sm.h + 5,
                          hPad: 4,
                          fg: _g,
                          onTap: () => slackMarkRead(context, ref, m),
                        ),
                      )
                    : _f('Read', cols[5], c: _faint),
              ],
              gap: _gap,
              onTap: () => slackOpen(context, ref, m),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              head,
              const SizedBox(height: 10),
              fit(colh),
              const SizedBox(height: 4),
              Expanded(
                child: s.messages.isEmpty
                    ? Align(
                        alignment: Alignment.topLeft,
                        child: fit(
                          _rw(0, [
                            _f('--:--', cols[0]),
                            _f('', cols[1]),
                            _f('', cols[2]),
                            _f('', cols[3]),
                            _f('No messages, inbox clear', cols[4]),
                            _f('Clear', cols[5], c: _g),
                          ], gap: _gap),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        physics: const ClampingScrollPhysics(),
                        itemCount: s.messages.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 5),
                        itemBuilder: (context, i) => fit(row(i, s.messages[i])),
                      ),
              ),
            ],
          );
        },
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
    final best = g.bestDay;
    final repos = g.topRepos.take(4).toList();
    // Source switch: same flap buttons as the System page's Laptop / Internet pair.
    final tabs = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, l) in codeSources.indexed) ...[
          if (i > 0) const SizedBox(width: 6),
          DepBtn(label: l, pressed: src == i, onTap: () => ref.read(codeSourceProvider.notifier).set(i)),
        ],
      ],
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        _pg(
          _board([
            _colh(const [('Streak', 7), ('Days', 4), ('Longest', 7), ('Best day', 10), ('This week', 9)]),
            _rw(0, [
              _fl('Current', 7, c: _y),
              _fl('${g.streakCurrent}', 4, c: _g),
              _fl('${g.streakLongest} days', 7),
              _fl(best == null ? '—' : '${best.count} ${month3(best.date)} ${best.date.day}', 10),
              _fl('${g.weekTotal} ${g.weekDelta >= 0 ? '+' : ''}${g.weekDelta}', 9, c: _g),
            ]),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: _lbl('Last year, ${_thousands(g.total)} contributions'),
            ),
            _HeatGrid(g.weeks),
            Padding(padding: const EdgeInsets.only(top: 4), child: _lbl(topReposLabel(ref))),
            for (var i = 0; i < repos.length; i += 2)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _rw(1 + i ~/ 2, [_fl(repos[i].name, 13), _fl('${repos[i].count}', 4, c: _y, right: true)]),
                  if (i + 1 < repos.length) ...[
                    const SizedBox(width: 24),
                    _rw(1 + i ~/ 2, [_fl(repos[i + 1].name, 13), _fl('${repos[i + 1].count}', 4, c: _y, right: true)]),
                  ],
                ],
              ),
          ]),
        ),
        Positioned(top: 0, right: 0, child: tabs),
      ],
    );
  }
}

String _thousands(int n) => n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

/// Contribution calendar as 11 px chips (53 × 7), four greens by level.
class _HeatGrid extends StatelessWidget {
  const _HeatGrid(this.weeks);
  final List<List<ContribDay>> weeks;
  static const cell = 11.0, gap = 2.0;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 53 * (cell + gap) - gap,
    height: 7 * (cell + gap) - gap,
    child: CustomPaint(painter: _HeatGridPainter(weeks)),
  );
}

class _HeatGridPainter extends CustomPainter {
  _HeatGridPainter(this.weeks);
  final List<List<ContribDay>> weeks;
  static const _lv = [_off, Color(0xFF2C5A3A), Color(0xFF3A8452), Color(0xFF4BB16B), _g];

  @override
  void paint(Canvas canvas, Size size) {
    final ws = weeks.length > 53 ? weeks.sublist(weeks.length - 53) : weeks;
    const step = _HeatGrid.cell + _HeatGrid.gap;
    for (var x = 0; x < ws.length; x++) {
      for (final d in ws[x]) {
        final y = d.date.weekday % 7;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x * step, y * step, _HeatGrid.cell, _HeatGrid.cell),
            const Radius.circular(2),
          ),
          Paint()..color = _lv[d.level.clamp(0, 4)],
        );
      }
    }
  }

  @override
  bool shouldRepaint(_HeatGridPainter o) => o.weeks != weeks;
}

// ------------------------------------------------------------------ Keys

class _Keys extends ConsumerWidget {
  const _Keys();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = topicData<ShortcutsData>(ref, 'shortcuts')!;
    final order = ref.watch(settingsProvider.select((x) => x.tileOrder));
    final tiles = orderedTiles(s.tiles, order);
    final rows = <List<Tile>>[];
    for (var i = 0; i < tiles.length; i += 4) {
      rows.add(tiles.sublist(i, math.min(i + 4, tiles.length)));
    }
    return Column(
      children: [
        for (final (ri, row) in rows.indexed) ...[
          if (ri > 0) const SizedBox(height: 10),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: i < row.length ? _key(context, ref, row[i], s.volumePct) : const SizedBox()),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _key(BuildContext context, WidgetRef ref, Tile t, int? vol) {
    final on = t.active;
    final ic = on ? _dark : _y;
    final detail = t.detail ?? (t.id.startsWith('volume') && vol != null ? 'Volume $vol%' : null);
    return Press(
      onTap: () => act(context, ref, 'shortcut.run', {'id': t.id}),
      scale: .985,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: on ? _r : null,
          gradient: on
              ? null
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [DeparturesSkin.flapT, DeparturesSkin.flapT, DeparturesSkin.flapB, DeparturesSkin.flapB],
                  stops: [0, .5, .5, 1],
                ),
          boxShadow: const [BoxShadow(color: Color(0xFF0B0B0C), offset: Offset(0, 2))],
        ),
        child: Stack(
          children: [
            const Positioned.fill(
              child: Center(
                child: SizedBox(
                  height: 1,
                  width: double.infinity,
                  child: ColoredBox(color: Color(0x99000000)),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DpIcon(tileIcon(t), size: 34, color: ic, stroke: 1.7),
                  const SizedBox(height: 10),
                  Text(
                    tileLabel(t).toUpperCase(),
                    style: depText(14, c: on ? _dark : DeparturesSkin.wh, ls: 1.4),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (detail != null)
                    Text(detail.toUpperCase(), style: depText(11, c: ic, ls: 1.1, h: 1.2), maxLines: 1),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
