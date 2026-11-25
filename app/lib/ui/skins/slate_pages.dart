// Concept 1 — Slate pages. Sizes follow deskpanel-concept-1-slate.html (CSS px = logical px).
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
import '../widgets/anim.dart';
import '../widgets/art.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import 'slate.dart';

const _t = SlateSkin.t;
const _gap = 10.0;
const _track = Color(0xFF262D36);
const _white = Color(0xFFF1F3F5);

Widget slatePage(PageId id) => switch (id) {
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

// ------------------------------------------------------------------ small parts

Widget _card(Widget child, {EdgeInsets? pad, VoidCallback? onTap, Color? border, Color? bg}) {
  Widget c = Container(
    padding: pad ?? const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: BoxDecoration(
      color: bg ?? _t.surface,
      borderRadius: BorderRadius.circular(_t.radius),
      border: Border.all(color: border ?? _t.line),
    ),
    child: child,
  );
  if (onTap != null) c = Press(onTap: onTap, scale: .985, child: c);
  return c;
}

Widget _lb(String s) => Text(s.toUpperCase(), style: _t.label, maxLines: 1, overflow: TextOverflow.ellipsis);

TextStyle _big([Color? c, double size = 30]) => _t.t(size, w: FontWeight.w700, c: c, ls: -.02 * size, h: 1);

Widget _bar(double v, Color c, {double h = 6, Color track = _track}) => DpBar(value: v, color: c, track: track, height: h);

Widget _muted(String s, {double size = 13, int lines = 1, TextAlign? align}) => Text(
  s,
  style: _t.t(size, c: _t.muted, h: 1.35),
  maxLines: lines,
  overflow: TextOverflow.ellipsis,
  textAlign: align,
);

Widget _kv(String k, String v, {double vSize = 13, FontWeight vw = FontWeight.w600}) => Row(
  crossAxisAlignment: CrossAxisAlignment.baseline,
  textBaseline: TextBaseline.alphabetic,
  children: [
    Expanded(
      child: Text(
        k,
        style: _t.t(12.5, c: _t.muted),
        overflow: TextOverflow.ellipsis,
      ),
    ),
    Text(v, style: _t.t(vSize, w: vw)),
  ],
);

Widget _pill(String s, {Color? c}) {
  final col = c ?? _t.accent;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(color: col.withValues(alpha: .16), borderRadius: BorderRadius.circular(99)),
    child: Text(
      s,
      style: _t.t(11.5, w: FontWeight.w600, c: col),
    ),
  );
}

/// Segmented pill control (`.seg`).
class _Seg extends StatelessWidget {
  const _Seg({required this.items, required this.value, required this.onChanged});
  final List<String> items;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: _t.surface,
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: _t.line),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, s) in items.indexed)
          Press(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              decoration: BoxDecoration(
                color: i == value ? _t.accent : const Color(0x00000000),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                s,
                style: _t.t(12, w: FontWeight.w600, c: i == value ? _t.onAccent : _t.muted),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Round control button (`.cb`).
Widget _cb(String icon, VoidCallback onTap, {double size = 50, bool main = false}) => Press(
  onTap: onTap,
  child: Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: main ? _white : _t.surface2),
    alignment: Alignment.center,
    child: DpIcon(icon, size: main ? 26 : 19, color: main ? _t.bg : _t.text),
  ),
);

/// Amber pill button (`.btn`).
Widget _btn(String label, VoidCallback? onTap) => Press(
  onTap: onTap,
  child: Opacity(
    opacity: onTap == null ? .6 : 1,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      decoration: BoxDecoration(color: _t.accent, borderRadius: BorderRadius.circular(99)),
      child: Text(
        label,
        style: _t.t(13, w: FontWeight.w700, c: _t.onAccent),
      ),
    ),
  ),
);

String _ampm(DateTime t, bool h24) => h24 ? '' : ampm(t);

// ------------------------------------------------------------------ Home

class _Home extends ConsumerWidget {
  const _Home();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void go(PageId p) => PageNav.go(context, p);
    return Ticker(
      builder: (context, now) => Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 13, child: _clockCard(ref, now, () => go(PageId.calendar))),
                const SizedBox(width: _gap),
                Expanded(flex: 10, child: _weatherCard(ref, () => go(PageId.weather))),
                const SizedBox(width: _gap),
                Expanded(flex: 10, child: _claudeCard(ref, now, () => go(PageId.claude))),
              ],
            ),
          ),
          const SizedBox(height: _gap),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 13, child: _systemCard(ref, () => go(PageId.system))),
                const SizedBox(width: _gap),
                Expanded(flex: 10, child: _musicCard(context, ref, () => go(PageId.music))),
                const SizedBox(width: _gap),
                Expanded(flex: 10, child: _slackCard(ref, now, () => go(PageId.slack))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _clockCard(WidgetRef ref, DateTime now, VoidCallback onTap) {
    final h24 = ref.watch(settingsProvider.select((s) => s.clock24));
    final events = ref.watch(calendarEventsProvider);
    final n = nextEvent(events, now);
    return _card(
      onTap: onTap,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                clock(now, h24: h24),
                style: _t.t(58, w: FontWeight.w700, ls: -2.3, h: .95),
              ),
              const SizedBox(width: 4),
              Text(
                _ampm(now, h24),
                style: _t.t(18, w: FontWeight.w600, c: _t.muted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(longDate(now), style: _t.t(14, c: _t.muted)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: _t.line)),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: n == null ? _t.faint : hex(n.color, _t.cpu),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          n?.title ?? 'Nothing else today',
                          style: _t.t(14, w: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        _muted(
                          n == null
                              ? 'Free until tomorrow'
                              : '${_inText(n, now)} • ${clockFull(n.start, h24: h24)}${n.location != null ? ' • ${n.location}' : ''}',
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
    );
  }

  Widget _weatherCard(WidgetRef ref, VoidCallback onTap) {
    final w = ref.watch(weatherProvider);
    final f = ref.watch(settingsProvider.select((s) => s.fahrenheit));
    return _card(
      onTap: onTap,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _lb('Weather'),
          const SizedBox(height: 8),
          Row(
            children: [
              DpIcon(w?.now.icon ?? 'cloud', size: 34, color: _t.cloud),
              const SizedBox(width: 8),
              Text(w == null ? '—' : '${temp(w.now.tempC, f)}°', style: _big()),
            ],
          ),
          const SizedBox(height: 6),
          Text(w?.now.condition ?? 'Set a location', style: _t.t(13)),
          if (w != null && w.days.isNotEmpty)
            _muted('${w.place} • H ${temp(w.days.first.hiC, f)}° L ${temp(w.days.first.loC, f)}°'),
        ],
      ),
    );
  }

  Widget _claudeCard(WidgetRef ref, DateTime now, VoidCallback onTap) {
    final c = topicData<ClaudeData>(ref, 'claude');
    final five = limitPct(c?.fiveHour, now), week = limitPct(c?.sevenDay, now);
    final lc = usageColor(five, _t), wc = usageColor(week, _t);
    return _card(
      onTap: onTap,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _lb('Claude'),
          const SizedBox(height: 8),
          Row(
            children: [
              c?.fiveHour == null ? Text('—', style: _big(_t.muted)) : AnimNum(five, style: _big(lc), suffix: '%'),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'of 5-hour\n${resetsIn(c?.fiveHour, now).replaceFirst('Resets', 'resets')}',
                  style: _t.t(12, c: _t.muted, h: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _bar(five / 100, lc),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text('Weekly', style: _t.t(12, c: _t.muted)),
              ),
              Text(
                c?.sevenDay == null ? '—' : '${week.round()}%',
                style: _t.t(12, w: FontWeight.w700, c: wc),
              ),
            ],
          ),
          const SizedBox(height: 5),
          _bar(week / 100, wc),
        ],
      ),
    );
  }

  Widget _systemCard(WidgetRef ref, VoidCallback onTap) {
    final s = topicData<SystemData>(ref, 'system');
    final rows = [
      ('CPU', s?.cpu.pct, _t.cpu),
      ('GPU', s == null || !s.gpu.available ? null : s.gpu.pct, _t.gpu),
      ('RAM', s == null ? null : s.ramUsed / s.ramTotal * 100, _t.ram),
    ];
    return _card(
      onTap: onTap,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _lb('System'),
          const SizedBox(height: 10),
          for (final (l, v, c) in rows) ...[
            Row(
              children: [
                SizedBox(
                  width: 38,
                  child: Text(l, style: _t.t(12, c: _t.muted)),
                ),
                const SizedBox(width: 8),
                Expanded(child: _bar((v ?? 0) / 100, c)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 34,
                  child: Text(
                    v == null ? '—' : '${v.round()}%',
                    textAlign: TextAlign.right,
                    style: _t.t(12, w: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
          ],
        ],
      ),
    );
  }

  Widget _musicCard(BuildContext context, WidgetRef ref, VoidCallback onTap) {
    final m = topicData<MediaData>(ref, 'media');
    final art = topicData<MediaArt>(ref, 'media.art');
    final playing = m?.title != null;
    return _card(
      onTap: onTap,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _lb('Now playing'),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 54,
                height: 54,
                child: AlbumArt(title: m?.title ?? 'DeskPanel', b64: art?.artId == m?.artId ? art?.b64 : null, radius: 9),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m?.title ?? 'Nothing playing',
                      style: _t.t(14, w: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    _muted(m?.artist ?? (m == null ? 'Laptop not connected' : '')),
                  ],
                ),
              ),
              if (playing)
                Press(
                  onTap: () => act(context, ref, 'media.play_pause'),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: _white),
                    alignment: Alignment.center,
                    child: DpIcon(m!.playing ? 'pause' : 'play', size: 15, color: _t.bg),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (playing)
            Ticker(
              period: const Duration(seconds: 1),
              builder: (context, now) {
                final pos = m!.positionNow(now, skewMs: ref.read(agentProvider.notifier).clockSkewMs);
                return _bar((m.durationMs ?? 0) == 0 ? 0 : pos / m.durationMs!, _white, h: 4);
              },
            ),
        ],
      ),
    );
  }

  /// Slack: unread count as the big number, then the newest unread sender and one line of it.
  /// Caught up (or not set up) it's just a calm line, no accent.
  Widget _slackCard(WidgetRef ref, DateTime now, VoidCallback onTap) {
    final s = slackHome(ref);
    final m = s.latest;
    return _card(
      onTap: onTap,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _lb('Slack')),
              DpIcon('slack', size: 16, color: _t.faint),
            ],
          ),
          const SizedBox(height: 8),
          if (m != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                AnimNum(s.unread.toDouble(), style: _big()),
                const SizedBox(width: 6),
                _muted('unread'),
              ],
            )
          else ...[
            Text(
              s.headline == 'Slack' ? '—' : s.headline,
              style: _big(s.headline == 'Slack' ? _t.muted : null, 24),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (s.detail != '—') ...[const SizedBox(height: 7), _muted(s.detail)],
          ],
          if (m != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: _t.line)),
              ),
              child: Row(
                children: [
                  _avatar(m, size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                m.sender,
                                style: _t.t(13.5, w: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(slackTime(m.ts, now), style: _t.t(12, w: FontWeight.w700, c: _t.accent)),
                          ],
                        ),
                        _muted(m.text, size: 12.5),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _inText(CalEvent e, DateTime now) {
  if (!e.start.isAfter(now)) return 'Now';
  final d = e.start.difference(now);
  return d.inMinutes < 1 ? 'Starting now' : 'in ${dur(d)}';
}

// ------------------------------------------------------------------ System

class _System extends ConsumerWidget {
  const _System();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(systemTabProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Seg(items: const ['PC', 'Internet'], value: tab, onChanged: ref.read(systemTabProvider.notifier).set),
        const SizedBox(height: _gap),
        Expanded(child: tab == 0 ? const _Pc() : const _Internet()),
      ],
    );
  }
}

class _Pc extends ConsumerWidget {
  const _Pc();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = topicData<SystemData>(ref, 'system')!;
    final g = s.gpu;
    const gb = 1024 * 1024 * 1024;
    final (down, downU) = rate(s.downBps);
    final (up, upU) = rate(s.upBps);
    Widget gauge(String name, double? pct, Color c, String sub) => Expanded(
      child: _card(
        pad: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        Column(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 116),
              child: ArcGauge(
                value: (pct ?? 0) / 100,
                color: c,
                track: _track,
                child: Column(
                  children: [
                    const Spacer(flex: 37),
                    Text(pct == null ? 'N/A' : '${pct.round()}%', style: _t.t(21, w: FontWeight.w700, h: 1)),
                    const Spacer(flex: 6),
                    Text(name, style: _t.t(11, w: FontWeight.w600, ls: .44, h: 1)),
                    const Spacer(flex: 18),
                  ],
                ),
              ),
            ),
            Transform.translate(offset: const Offset(0, -6), child: _muted(sub, size: 11.5)),
          ],
        ),
      ),
    );
    final vramPct = g.vramUsed != null && (g.vramTotal ?? 0) > 0 ? g.vramUsed! / g.vramTotal! * 100 : null;
    return Column(
      children: [
        Row(
          children: [
            gauge(
              'CPU',
              s.cpu.pct,
              _t.cpu,
              s.cpu.cores != null ? '${s.cpu.cores} cores, ${s.cpu.threads ?? s.cpu.cores} threads' : 'CPU',
            ),
            const SizedBox(width: _gap),
            gauge('GPU', g.available ? g.pct : null, _t.gpu, g.tempC != null ? '${g.tempC!.round()}°C' : (g.model ?? 'GPU')),
            const SizedBox(width: _gap),
            gauge(
              'RAM',
              s.ramUsed / s.ramTotal * 100,
              _t.ram,
              '${(s.ramUsed / gb).toStringAsFixed(1)} / ${(s.ramTotal / gb).round()} GB',
            ),
            const SizedBox(width: _gap),
            gauge(
              g.vramLabel,
              vramPct,
              _t.vram,
              vramPct == null ? 'N/A' : '${(g.vramUsed! / gb).toStringAsFixed(1)} / ${(g.vramTotal! / gb).round()} GB',
            ),
          ],
        ),
        const SizedBox(height: _gap),
        Expanded(
          child: _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _lb('Last minute'),
                    const SizedBox(width: 10),
                    _key('CPU', _t.cpu),
                    const SizedBox(width: 8),
                    _key('GPU', _t.gpu),
                    const Spacer(),
                    DpIcon('down', size: 13, color: _t.text),
                    const SizedBox(width: 4),
                    Text('$down $downU', style: _t.t(13, w: FontWeight.w600)),
                    const SizedBox(width: 12),
                    DpIcon('up', size: 13, color: _t.text),
                    const SizedBox(width: 4),
                    Text('$up $upU', style: _t.t(13, w: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: LineChart(
                    grid: ChartGrid.quarters,
                    series: [if (g.available) LineSeries(s.gpuHistory, _t.gpu), LineSeries(s.cpuHistory, _t.cpu)],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${s.cpu.model}${g.model != null ? ' / ${g.model}' : ''}',
                        style: _t.t(11.5, c: _t.faint),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text('Disk ${s.diskPct.round()}% used', style: _t.t(11.5, c: _t.faint)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _key(String s, Color c) => Row(
    children: [
      Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(shape: BoxShape.circle, color: c),
      ),
      const SizedBox(width: 5),
      Text(
        s,
        style: _t.t(11, w: FontWeight.w600, c: c, ls: .66),
      ),
    ],
  );
}

class _Internet extends ConsumerWidget {
  const _Internet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = topicData<NetworkData>(ref, 'network');
    final live = ref.watch(agentProvider).live;
    if (n == null) {
      return _card(Center(child: _muted('Waiting for network data…', size: 14)));
    }
    final now = DateTime.now();
    final st = n.speedtest;
    final last = st.last;
    final prog = st.progress;
    final shownDown = st.running ? (prog?.downBps ?? 0) : (last?.downBps ?? 0);
    final shownUp = st.running ? (prog?.upBps ?? 0) : (last?.upBps ?? 0);
    final sys = topicData<SystemData>(ref, 'system');
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _card(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _lb('Latency'),
                      const SizedBox(height: 6),
                      n.latencyMs == null
                          ? Text('Timeout', style: _big(_t.bad))
                          : NumUnit(
                              n.latencyMs!,
                              'ms',
                              style: _big(),
                              unitStyle: _t.t(18, w: FontWeight.w600),
                              gap: 6,
                            ),
                      const SizedBox(height: 4),
                      _muted('Jitter ${n.jitterMs?.toStringAsFixed(1) ?? '—'} ms • Loss ${n.lossPct.round()}%', size: 12),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: _gap),
              Expanded(
                child: _card(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _lb('Status'),
                      const SizedBox(height: 6),
                      Text(
                        !live ? 'Unknown' : (n.online ? 'Online' : 'Offline'),
                        style: _big(!live ? _t.bad : (n.online ? _t.ok : _t.bad)),
                      ),
                      const SizedBox(height: 4),
                      _muted(
                        '${n.onlineSince != null ? 'Up ${durLong(now.difference(n.onlineSince!))}' : '—'}'
                        '${n.lastDrop != null ? ' • Last drop ${ago(now.difference(n.lastDrop!))}' : ''}',
                        size: 12,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: _gap),
              Expanded(
                child: _card(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _lb('Data used'),
                      const SizedBox(height: 8),
                      _kv('Today', bytes(n.usageToday), vSize: 17),
                      const SizedBox(height: 4),
                      _kv('This month', bytes(n.usageMonth), vSize: 17),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: _gap),
        Expanded(
          child: _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _lb('Latency, last 2 minutes'),
                    const Spacer(),
                    Text('max 50 ms', style: _t.t(11, c: _t.faint)),
                  ],
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: LineChart(grid: ChartGrid.mid, max: 50, series: [LineSeries(n.latencyHistory, _t.gpu, width: 1.8)]),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: _gap),
        _card(
          Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _speed('Speed test', 'down', shownDown),
                  const SizedBox(width: 22),
                  _speed('', 'up', shownUp),
                  const SizedBox(width: 22),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _muted(
                        '${st.running
                            ? 'Testing now'
                            : last == null
                            ? 'Never tested'
                            : 'Ping ${last.pingMs.round()} ms • tested ${ago(now.difference(last.at))}'}\n'
                        'Now ↓ ${sys == null ? '—' : mbps(sys.downBps)}  ↑ ${sys == null ? '—' : mbps(sys.upBps)} Mbps',
                        size: 12,
                        lines: 2,
                      ),
                    ),
                  ),
                  _btn(
                    st.running ? 'Testing…' : 'Run test',
                    st.running
                        ? null
                        : () => act(context, ref, 'speedtest.run', const {}, null, null, const Duration(seconds: 90)),
                  ),
                ],
              ),
              if (st.running) Positioned(left: 0, right: 0, bottom: -6, child: _bar((prog?.pct ?? 0) / 100, _t.accent, h: 3)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _speed(String label, String icon, double bps) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label.isEmpty ? ' ' : label.toUpperCase(), style: _t.label),
      const SizedBox(height: 4),
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          DpIcon(icon, size: 22, color: _t.sky),
          const SizedBox(width: 6),
          AnimNum(bps * 8 / 1e6, style: _big(null, 28)),
          const SizedBox(width: 6),
          Text(
            'Mbps',
            style: _t.t(15, w: FontWeight.w600, c: _t.muted),
          ),
        ],
      ),
    ],
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
        Widget limit(String label, LimitWindow? w, double pct, String sub) {
          final col = usageColor(pct, _t);
          return Expanded(
            child: _card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _lb(label),
                  const SizedBox(height: 8),
                  w == null ? Text('—', style: _big(_t.muted)) : AnimNum(pct, style: _big(col), suffix: '%'),
                  const SizedBox(height: 8),
                  _bar(pct / 100, col),
                  const SizedBox(height: 8),
                  Text(sub, style: _t.t(13), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          );
        }

        final peak = maxOf(c.days.map((d) => d.tokens));
        final topModel = maxOf(c.modelsToday.map((m) => m.tokens));
        return Column(
          children: [
            SizedBox(
              height: 122,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  limit('5-hour limit', c.fiveHour, five, resetsIn(c.fiveHour, now)),
                  const SizedBox(width: _gap),
                  limit('Weekly limit', c.sevenDay, week, resetsAt(c.sevenDay, now, h24: h24)),
                  const SizedBox(width: _gap),
                  Expanded(
                    child: _card(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _lb('Today'),
                          const Spacer(),
                          _kv('Tokens', compact(c.tokens)),
                          const Spacer(),
                          _kv('Output', compact(c.outputTokens)),
                          const Spacer(),
                          _kv('Messages', '${c.messages}'),
                          const Spacer(),
                          _kv('Last hour', compact(c.lastHourTokens)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: _gap),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 17,
                    child: _card(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _lb('Last 7 days'),
                              const Spacer(),
                              Text('peak ${compact(peak)} tokens', style: _t.t(11.5, c: _t.faint)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: BarTapTip(
                              count: c.days.length,
                              label: (i) => dayTokensLabel(c.days[i], now),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (final (i, d) in c.days.indexed) ...[
                                    if (i > 0) const SizedBox(width: 10),
                                    Expanded(child: _dayBar(d, peak, i == c.days.length - 1, now)),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: _gap),
                  Expanded(
                    flex: 10,
                    child: _card(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _lb('Models today'),
                          const SizedBox(height: 12),
                          if (c.modelsToday.isEmpty) _muted('No messages yet today'),
                          for (final m in c.modelsToday.take(4)) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: Text(modelName(m.family), style: _t.t(12.5, w: FontWeight.w600)),
                                ),
                                Text(compact(m.tokens), style: _t.t(12.5, c: _t.muted)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            _bar(m.tokens / topModel, _t.claude, h: 5),
                            const SizedBox(height: 16),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _dayBar(ClaudeDay d, double peak, bool today, DateTime now) => Column(
    children: [
      Expanded(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: LayoutBuilder(
            builder: (context, c) => TweenAnimationBuilder<double>(
              tween: Tween(end: math.max(3, c.maxHeight * d.tokens / peak)),
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeOutCubic,
              builder: (context, h, _) => Container(
                height: h,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(5), bottom: Radius.circular(2)),
                  color: today ? null : _t.claude,
                  gradient: today
                      ? const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFE5835D), Color(0xFFC9603C)],
                        )
                      : null,
                  boxShadow: today ? const [BoxShadow(color: Color(0x59E5835D), spreadRadius: 1.5)] : null,
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 5),
      Text(dayLabel(d.date, now), style: _t.t(11, c: _t.muted)),
    ],
  );
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
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 145,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Upcoming', style: _t.t(26, w: FontWeight.w700, ls: -.5)),
                  const SizedBox(height: 4),
                  Text(
                    'TODAY • ${longDate(now)}',
                    style: _t.t(12.5, w: FontWeight.w600, c: _t.accent, ls: .25),
                  ),
                  const SizedBox(height: 8),
                  if (split.today.isEmpty) _muted('Nothing on the calendar today.', size: 13),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        for (final e in split.today) ...[_event(e, now, e == n, h24), const SizedBox(height: 8)],
                        if (split.later.isEmpty) Text('No more events in the next 7 days', style: _t.t(12.5, c: _t.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 100,
              child: Padding(
                padding: const EdgeInsets.only(top: 44),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _lb('Later this week'),
                    const SizedBox(height: 8),
                    if (split.later.isNotEmpty)
                      _card(
                        pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        Column(
                          children: [
                            for (final (i, e) in split.later.take(5).indexed)
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                decoration: BoxDecoration(
                                  border: i < math.min(split.later.length, 5) - 1
                                      ? Border(bottom: BorderSide(color: _t.line))
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(shape: BoxShape.circle, color: hex(e.color, _t.cpu)),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            e.title,
                                            style: _t.t(13, w: FontWeight.w600),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          _muted(e.location ?? e.calendar ?? '', size: 12.5),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        _muted(weekday(e.start), size: 12.5),
                                        _muted(e.allDay ? 'All day' : clockFull(e.start, h24: h24), size: 12.5),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      split.later.isEmpty ? 'No other events in the next 7 days' : 'No other events in the next 7 days',
                      style: _t.t(12, c: _t.faint),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _event(CalEvent e, DateTime now, bool isNext, bool h24) {
    final past = e.end.isBefore(now);
    return Opacity(
      opacity: past ? .45 : 1,
      child: _card(
        pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: isNext ? _t.accent.withValues(alpha: .45) : null,
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 3,
                decoration: BoxDecoration(color: hex(e.color, _t.cpu), borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 70,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.allDay ? 'All day' : clockFull(e.start, h24: h24),
                      style: _t.t(12.5, c: _t.muted, h: 1.45),
                    ),
                    if (!e.allDay)
                      Text(
                        clockFull(e.end, h24: h24),
                        style: _t.t(12.5, c: _t.muted, h: 1.45),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            e.title,
                            style: _t.t(15.5, w: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isNext) ...[
                          const SizedBox(width: 8),
                          Text(
                            _inText(e, now),
                            style: _t.t(11, w: FontWeight.w700, c: _t.accent),
                          ),
                        ],
                      ],
                    ),
                    _muted([e.location, e.calendar].whereType<String>().join(' • ')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
    if (w == null) {
      return _card(Center(child: _muted('Set your location in Settings → Weather', size: 14)));
    }
    final f = s.fahrenheit;
    return Column(
      children: [
        _card(
          pad: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          Row(
            children: [
              DpIcon(w.now.icon, size: 70, color: _t.cloud, stroke: 1.4),
              const SizedBox(width: 18),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${temp(w.now.tempC, f)}°', style: _t.t(50, w: FontWeight.w700, ls: -1.5, h: .9)),
                  const SizedBox(height: 6),
                  Text(w.now.condition, style: _t.t(16)),
                  _muted(w.place),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Feels like ${temp(w.now.feelsC, f)}°', style: _t.t(13, h: 1.6)),
                  Text('Humidity ${w.now.humidity}%', style: _t.t(13, h: 1.6)),
                  Text('Wind ${wind(w.now.windKmh, f)}', style: _t.t(13, h: 1.6)),
                  Text(
                    'Updated ${clockFull(w.now.updated, h24: s.clock24)}',
                    style: _t.t(11.5, c: _t.faint, h: 1.6),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: _gap),
        _card(
          pad: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          SizedBox(
            height: 70,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final (i, h) in w.hours.indexed)
                  SizedBox(
                    width: 68,
                    child: Column(
                      children: [
                        Text(
                          i == 0
                              ? 'Now'
                              : (s.clock24
                                    ? '${two(h.time.hour)}:00'
                                    : '${h.time.hour % 12 == 0 ? 12 : h.time.hour % 12} ${ampm(h.time)}'),
                          style: _t.t(11.5, c: _t.muted),
                        ),
                        const SizedBox(height: 4),
                        DpIcon(h.icon, size: 22, color: _t.cloud),
                        const SizedBox(height: 4),
                        Text('${temp(h.tempC, f)}°', style: _t.t(15, w: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: _gap),
        Expanded(
          child: _card(
            pad: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            Center(
              child: Row(
                children: [
                  for (final (i, d) in w.days.indexed)
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(i == 0 ? 'Today' : weekday3(d.date), style: _t.t(12, c: _t.muted)),
                          const SizedBox(height: 4),
                          DpIcon(d.icon, size: 22, color: d.icon == 'rain' ? const Color(0xFF4FD6E8) : _t.cloud),
                          const SizedBox(height: 4),
                          Text('${temp(d.hiC, f)}° / ${temp(d.loC, f)}°', style: _t.t(13, w: FontWeight.w600)),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 15,
                            child: Text(
                              d.precipPct > 0 ? '${d.precipPct}%' : '',
                              style: _t.t(11.5, w: FontWeight.w600, c: _t.sky),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final side = math.min(c.maxHeight, 330.0);
              return Container(
                width: side,
                height: side,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Color(0xCC000000), blurRadius: 40, offset: Offset(0, 20), spreadRadius: -20),
                  ],
                ),
                child: AlbumArt(title: title ?? 'Nothing playing', b64: art?.artId == m.artId ? art?.b64 : null, radius: 16),
              );
            },
          ),
          const SizedBox(width: 30),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (m.source ?? 'Laptop').toUpperCase(),
                  style: _t.t(11, w: FontWeight.w700, c: _t.accent, ls: 1.1),
                ),
                const SizedBox(height: 6),
                Text(
                  title ?? 'Nothing playing',
                  style: _t.t(28, w: FontWeight.w700, ls: -.56, h: 1.15),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (m.artist != null) Text(m.artist!, style: _t.t(18), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (m.album != null) _muted(m.album!),
                const SizedBox(height: 18),
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
                          onSeek: (f) => act(context, ref, 'media.seek', {'position_ms': (f * total).round()}),
                        ),
                        Row(
                          children: [
                            Text(mmss(pos), style: _t.t(11.5, c: _t.muted)),
                            const Spacer(),
                            Text(total == 0 ? '' : mmss(total), style: _t.t(11.5, c: _t.muted)),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _cb('prev', () => act(context, ref, 'media.prev')),
                    const SizedBox(width: 20),
                    _cb(m.playing ? 'pause' : 'play', () => act(context, ref, 'media.play_pause'), size: 70, main: true),
                    const SizedBox(width: 20),
                    _cb('next', () => act(context, ref, 'media.next')),
                  ],
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
  const _SeekBar({required this.value, required this.onSeek, required this.enabled});
  final double value;
  final bool enabled;
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
      final v = _drag ?? widget.value;
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
        child: SizedBox(
          height: 18,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              _bar(v, _white, h: 5, track: const Color(0xFF2A313A)),
              Positioned(
                left: (c.maxWidth * v - 8).clamp(0, c.maxWidth - 16),
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: _white),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// ------------------------------------------------------------------ Hotspot

/// The Hotspot Monitor Overview (the roof phone sharing mobile data).
class _Hotspot extends ConsumerWidget {
  const _Hotspot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = topicData<HotspotData>(ref, 'hotspot')!;
    final f = ref.watch(settingsProvider).fahrenheit;
    return Ticker(
      builder: (context, now) {
        final alert = hsAlert(d, now);
        final note = hsSessionNote(d, now);
        final stateC = hsStateColor(d, _t);
        return LayoutBuilder(
          builder: (context, c) {
            // Body below the 40px header (and the alert strip), split into two card rows.
            final body = c.maxHeight - 40 - _gap - (alert == null ? 0 : 36 + _gap);
            final inner = (body - _gap) / 2 - 22;
            final foot = inner >= 112 ? 2 : (inner >= 96 ? 1 : 0);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 40,
                  child: Row(
                    children: [
                      const SizedBox(width: 4),
                      DpIcon('hotspot', size: 20, color: _t.text),
                      const SizedBox(width: 10),
                      Text('Hotspot', style: _t.t(20, w: FontWeight.w700, ls: -.3)),
                      Expanded(
                        child: Row(
                          children: [
                            if (d.name != null) ...[const SizedBox(width: 8), Flexible(child: _muted(d.name!, size: 14))],
                            const SizedBox(width: 12),
                            _pill(hsStateLabel(d), c: stateC),
                            if (note != null) ...[const SizedBox(width: 8), _pill(note, c: _t.warn)],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _muted(hsSeen(d, now), size: 13),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
                const SizedBox(height: _gap),
                if (alert != null) ...[
                  Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: _t.bad.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(_t.radius),
                      border: Border.all(color: _t.bad.withValues(alpha: .5)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: _t.bad),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            alert,
                            style: _t.t(13.5, w: FontWeight.w600, c: _t.bad),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: _gap),
                ],
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(child: _score(d, foot)),
                                  const SizedBox(width: _gap),
                                  Expanded(child: _speed(d, foot)),
                                  const SizedBox(width: _gap),
                                  Expanded(child: _battery(d, foot)),
                                ],
                              ),
                            ),
                            const SizedBox(height: _gap),
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(child: _temp(d, f, foot)),
                                  const SizedBox(width: _gap),
                                  Expanded(child: _data(d, foot)),
                                  const SizedBox(width: _gap),
                                  Expanded(child: _uptime(d, foot)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: _gap),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _status(d, stateC, model: body > 300),
                            const SizedBox(height: _gap),
                            Expanded(child: _events(d, now)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// A small Overview card: label (+ trailing), the value, and a muted line pinned to the bottom.
  Widget _box(String label, Widget main, String line, int foot, {Widget? trailing}) => _card(
    pad: const EdgeInsets.fromLTRB(14, 10, 14, 10),
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _lb(label)),
            ?trailing,
          ],
        ),
        const SizedBox(height: 8),
        main,
        const Spacer(),
        if (foot > 0) _muted(line, size: 11.5, lines: foot),
      ],
    ),
  );

  Widget _numUnit(String v, String u, {Color? c, double size = 30}) => Row(
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      Flexible(
        child: Text(v, style: _big(c, size), maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      const SizedBox(width: 5),
      Text(u, style: _t.t(size * .5, w: FontWeight.w600, c: _t.muted)),
    ],
  );

  Widget _score(HotspotData d, int foot) {
    final gc = hsGradeColor(d.grade, _t);
    return _box(
      'Signal score',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _numUnit(d.score == null ? '—' : '${d.score!.round()}', '/ 100', c: gc),
          const SizedBox(height: 10),
          _bar((d.score ?? 0) / 100, gc),
        ],
      ),
      hsSignalLine(d),
      foot,
      trailing: _pill(hsGradeLabel(d.grade), c: gc),
    );
  }

  Widget _speed(HotspotData d, int foot) {
    Widget row(String icon, double? bps) {
      final (v, u) = hsBpsParts(bps);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          DpIcon(icon, size: 17, color: _t.sky),
          const SizedBox(width: 6),
          Expanded(child: _numUnit(v, u, size: 23)),
        ],
      );
    }

    return _box(
      'Speed now',
      Column(children: [row('down', d.rxBps), const SizedBox(height: 6), row('up', d.txBps)]),
      hsPingLine(d),
      foot,
    );
  }

  Widget _battery(HotspotData d, int foot) {
    final c = d.lowBattery ? _t.bad : null;
    final ma = d.currentMa;
    return _box(
      'Battery',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(d.batteryPct == null ? '—' : '${d.batteryPct!.round()}%', style: _big(c)),
              const Spacer(),
              Text(
                hsCurrent(ma),
                style: _t.t(13, w: FontWeight.w600, c: ma == null || ma == 0 ? _t.muted : (ma < 0 ? _t.warn : _t.ok)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _bar((d.batteryPct ?? 0) / 100, c ?? _t.ok),
        ],
      ),
      hsPowerLine(d),
      foot,
    );
  }

  Widget _temp(HotspotData d, bool f, int foot) {
    final c = switch (d.heat) {
      HotspotHeat.hot => _t.bad,
      HotspotHeat.warm => _t.warn,
      HotspotHeat.ok => null,
    };
    return _box(
      'Temperature',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(hsTemp(d.batteryC, fahrenheit: f), style: _big(c), maxLines: 1),
          const SizedBox(height: 5),
          Row(
            children: [
              _muted('Battery', size: 12),
              if (d.radioResting) ...[const SizedBox(width: 8), Flexible(child: _pill('Radio resting', c: _t.bad))],
            ],
          ),
        ],
      ),
      hsHeatLine(d, fahrenheit: f),
      foot,
    );
  }

  Widget _data(HotspotData d, int foot) {
    final (v, u) = hsBytesParts(d.cycleUsed);
    final q = d.quotaFrac;
    final qc = q == null ? _t.cpu : (q >= 1 ? _t.bad : (q >= .8 ? _t.warn : _t.cpu));
    return _box(
      'Data this cycle',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _numUnit(v, u),
          const SizedBox(height: 5),
          if (q != null) ...[
            const SizedBox(height: 5),
            _bar(q.clamp(0, 1).toDouble(), qc),
          ] else
            _muted('No quota set', size: 12),
        ],
      ),
      hsTodayLine(d),
      foot,
      trailing: q == null ? null : Text('${(q * 100).round()}%', style: _t.t(12, w: FontWeight.w700, c: qc)),
    );
  }

  Widget _uptime(HotspotData d, int foot) {
    Widget col(String k, double? s) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(hsUptime(s), style: _big(null, 22), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 5),
          _muted(k, size: 12),
        ],
      ),
    );
    return _box(
      'Uptime',
      Row(children: [col('Phone', d.uptimeS), const SizedBox(width: 8), col('Agent', d.agentUptimeS)]),
      hsBootLine(d),
      foot,
    );
  }

  Widget _status(HotspotData d, Color stateC, {required bool model}) => _card(
    pad: const EdgeInsets.fromLTRB(14, 10, 14, 10),
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _lb('Status'),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(shape: BoxShape.circle, color: stateC),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                hsStateLabel(d),
                style: _t.t(20, w: FontWeight.w700, c: stateC, ls: -.3, h: 1.1),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _kv('Network', hsNetwork(d)),
        const SizedBox(height: 3),
        _kv('Operator', d.operator ?? '—'),
        const SizedBox(height: 3),
        _kv('Sharing', hsSharing(d).replaceFirst('Sharing ', '')),
        if (model && d.model != null) ...[const SizedBox(height: 6), _muted(d.model!, size: 11.5)],
      ],
    ),
  );

  Widget _events(HotspotData d, DateTime now) => _card(
    pad: const EdgeInsets.fromLTRB(14, 10, 14, 6),
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _lb('Latest events'),
        const SizedBox(height: 4),
        Expanded(
          child: d.events.isEmpty
              ? Center(child: _muted('No events yet', size: 12.5))
              : LayoutBuilder(
                  builder: (context, c) {
                    const rowH = 25.0;
                    final n = math.min(d.events.length, (c.maxHeight / rowH).floor());
                    return Column(
                      children: [
                        for (final (i, e) in d.events.take(n).indexed)
                          Container(
                            height: rowH,
                            decoration: BoxDecoration(
                              border: i == 0 ? null : Border(top: BorderSide(color: _t.line)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: hsEventColor(e, _t)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    e.message,
                                    style: _t.t(
                                      12.5,
                                      c: switch (e.severity) {
                                        'critical' => _t.bad,
                                        'warning' => _t.warn,
                                        _ => _t.text,
                                      },
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(slackTime(e.ts, now), style: _t.t(11.5, c: _t.faint)),
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

// ------------------------------------------------------------------ Timer

class _Timer extends ConsumerWidget {
  const _Timer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(timerProvider);
    final ctl = ref.read(timerProvider.notifier);
    return Ticker(
      period: const Duration(milliseconds: 250),
      builder: (context, now) {
        final d = st.display(now);
        final digits = d.inHours > 0
            ? '${d.inHours}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}'
            : '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
        final label = st.running ? 'Pause' : (st.pristine ? 'Start' : 'Resume');
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              LayoutBuilder(
                builder: (context, c) {
                  final side = math.min(c.maxHeight, 330.0);
                  return SizedBox(
                    width: side,
                    height: side,
                    child: ArcGauge(
                      value: st.progress(now),
                      color: _t.accent,
                      track: _track,
                      start: 0,
                      end: 359.99,
                      stroke: 7,
                      radius: 52,
                      cx: 60,
                      cy: 60,
                      viewW: 120,
                      viewH: 120,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              child: Text(digits, style: _t.t(side * 25 / 120, w: FontWeight.w700, ls: -1, h: 1)),
                            ),
                            SizedBox(height: side * .04),
                            Text(
                              st.mode.label,
                              style: _t.t(side * 7 / 120 * 1.2, w: FontWeight.w600, c: _t.muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 26),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Timer', style: _t.t(26, w: FontWeight.w700, ls: -.5)),
                    const SizedBox(height: 18),
                    FittedBox(
                      child: _Seg(
                        items: [for (final m in TimerMode.values) m.label],
                        value: st.mode.index,
                        onChanged: (i) => ctl.setMode(TimerMode.values[i]),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        _btn(label, ctl.toggle),
                        const SizedBox(width: 10),
                        _cb('reset', ctl.reset, size: 40),
                        if (st.mode == TimerMode.countdown && !st.running) ...[
                          const SizedBox(width: 18),
                          _cbText('−', () => ctl.adjust(-1)),
                          const SizedBox(width: 8),
                          Text('${st.countdownMin} min', style: _t.t(13, w: FontWeight.w600)),
                          const SizedBox(width: 8),
                          _cbText('+', () => ctl.adjust(1)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (st.mode.isPomodoro) ...[
                      Row(
                        children: [
                          for (var i = 0; i < 4; i++)
                            Container(
                              width: 22,
                              height: 6,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: i < st.sessions ? _t.accent : _track,
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _muted('${st.sessions} of 4 focus sessions today'),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _cbText(String s, VoidCallback onTap) => Press(
    onTap: onTap,
    child: Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(shape: BoxShape.circle, color: _t.surface2),
      alignment: Alignment.center,
      child: Text(s, style: _t.t(18, w: FontWeight.w600, h: 1)),
    ),
  );
}

// ------------------------------------------------------------------ Slack

/// Initials on a circle in the sender's colour.
Widget _avatar(SlackMsg m, {double size = 34}) {
  final c = hex(m.senderColor, _t.cpu);
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: c),
    alignment: Alignment.center,
    child: Text(
      m.initials,
      style: _t.t(size * .38, w: FontWeight.w700, c: c.computeLuminance() > .4 ? _t.bg : _white, h: 1),
    ),
  );
}

class _Slack extends ConsumerWidget {
  const _Slack();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = topicData<SlackData>(ref, 'slack')!;
    final unread = s.unreadMessages;
    final hero = unread.isEmpty ? null : unread.first;
    final rest = s.messages.where((m) => m != hero).toList();
    return Ticker(
      builder: (context, now) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 40,
            child: Row(
              children: [
                const SizedBox(width: 4),
                DpIcon('slack', size: 20, color: _t.text),
                const SizedBox(width: 10),
                Text('Slack', style: _t.t(20, w: FontWeight.w700, ls: -.3)),
                Expanded(
                  child: Row(
                    children: [
                      if (s.team != null) ...[
                        const SizedBox(width: 8),
                        Flexible(child: _muted(s.team!, size: 14)),
                      ],
                      const SizedBox(width: 12),
                      _pill(slackSummary(s), c: s.unread == 0 ? _t.ok : _t.accent),
                    ],
                  ),
                ),
                if (s.unread > 0) ...[
                  const SizedBox(width: 12),
                  _btn('Mark all read', () => slackReadAll(context, ref)),
                ],
              ],
            ),
          ),
          const SizedBox(height: _gap),
          Expanded(
            child: s.messages.isEmpty
                ? _caughtUp(s, wide: true)
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 100, child: hero == null ? _caughtUp(s) : _hero(context, ref, hero, now)),
                      const SizedBox(width: _gap),
                      Expanded(flex: 125, child: _list(context, ref, rest, now, hero != null)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _caughtUp(SlackData s, {bool wide = false}) => _card(
    Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(shape: BoxShape.circle, color: _t.ok.withValues(alpha: .14)),
            alignment: Alignment.center,
            child: DpIcon('slack', size: 26, color: _t.ok),
          ),
          const SizedBox(height: 14),
          Text('All caught up', style: _t.t(20, w: FontWeight.w700)),
          const SizedBox(height: 4),
          _muted(
            wide ? 'No new messages${s.team == null ? '' : ' in ${s.team}'}' : 'No unread messages',
            align: TextAlign.center,
          ),
        ],
      ),
    ),
  );

  Widget _hero(BuildContext context, WidgetRef ref, SlackMsg m, DateTime now) => _card(
    onTap: () => slackOpen(context, ref, m),
    border: _t.accent.withValues(alpha: .45),
    pad: const EdgeInsets.fromLTRB(16, 14, 16, 14),
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(shape: BoxShape.circle, color: _t.accent),
            ),
            const SizedBox(width: 8),
            Expanded(child: _lb('Latest unread')),
            Text(slackTime(m.ts, now), style: _t.t(12, w: FontWeight.w700, c: _t.accent)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _avatar(m, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.sender,
                    style: _t.t(17, w: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  _muted(slackWhere(m), size: 12.5),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              const size = 20.0, lh = 1.4;
              final lines = (c.maxHeight / (size * lh)).floor().clamp(1, 6);
              return Text(
                m.text,
                style: _t.t(size, w: FontWeight.w500, h: lh),
                maxLines: lines,
                overflow: TextOverflow.ellipsis,
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _btn('Open in Slack', () => slackOpen(context, ref, m)),
            const SizedBox(width: 14),
            Flexible(
              child: Press(
                onTap: () => slackMarkRead(context, ref, m),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Text(
                    'Mark read',
                    style: _t.t(13, w: FontWeight.w600, c: _t.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _list(BuildContext context, WidgetRef ref, List<SlackMsg> msgs, DateTime now, bool hasHero) => _card(
    pad: const EdgeInsets.fromLTRB(14, 12, 6, 4),
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Row(
            children: [
              Expanded(child: _lb(hasHero ? 'Earlier' : 'Recent')),
              Text('${msgs.length}', style: _t.t(12, c: _t.faint)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: msgs.isEmpty
              ? Center(child: _muted('Nothing else in Slack'))
              : ListView.builder(
                  padding: const EdgeInsets.only(right: 8),
                  itemCount: msgs.length,
                  itemBuilder: (context, i) => _row(context, ref, msgs[i], now, last: i == msgs.length - 1),
                ),
        ),
      ],
    ),
  );

  Widget _row(BuildContext context, WidgetRef ref, SlackMsg m, DateTime now, {required bool last}) => Press(
    onTap: () => slackOpen(context, ref, m),
    scale: .99,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: _t.line)),
      ),
      child: Opacity(
        opacity: m.unread ? 1 : .5,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _avatar(m, size: 32),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: m.sender,
                                style: _t.t(13.5, w: m.unread ? FontWeight.w700 : FontWeight.w600),
                              ),
                              TextSpan(text: '  ${slackWhere(m)}', style: _t.t(12, c: _t.muted)),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        slackTime(m.ts, now),
                        style: _t.t(12, w: m.unread ? FontWeight.w700 : FontWeight.w400, c: m.unread ? _t.accent : _t.muted),
                      ),
                      const SizedBox(width: 7),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: m.unread ? _t.accent : const Color(0x00000000),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    m.text,
                    style: _t.t(13, c: m.unread ? _t.text : _t.muted, h: 1.35),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SlackReadTick(m, fill: _t.accent),
          ],
        ),
      ),
    ),
  );
}

// ------------------------------------------------------------------ GitHub

class _Github extends ConsumerWidget {
  const _Github();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = topicData<GithubData>(ref, codeTopic(ref))!;
    final now = DateTime.now();
    final today = now.weekday % 7;
    final mx = maxOf([...g.thisWeek, ...g.lastWeek]);
    final topRepo = maxOf(g.topRepos.map((r) => r.count));
    final seg = _Seg(
      items: codeSources,
      value: ref.watch(codeSourceProvider),
      onChanged: ref.read(codeSourceProvider.notifier).set,
    );
    // With the bottom nav bar the page is ~65px shorter: the switch moves into the heatmap
    // card's header instead of taking a row of its own.
    return LayoutBuilder(
      builder: (context, box) {
        final compact = box.maxHeight < 370;
        return Column(
          children: [
            if (!compact) ...[Align(alignment: Alignment.centerLeft, child: seg), const SizedBox(height: _gap)],
            _card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (compact) ...[seg, const SizedBox(width: 12)],
                      _lb('Last year'),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${_thousands(g.total)} contributions • ${g.commits} commits • ${g.private} private • ${g.issues} issue${g.issues == 1 ? '' : 's'}',
                          textAlign: TextAlign.right,
                          style: _t.t(11.5, c: _t.muted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Heatmap(
                    weeks: g.weeks,
                    style: HeatStyle.slate,
                    labelStyle: _t.t(9, c: _t.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: _gap),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 10,
                    child: _card(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _lb('Streak'),
                          const Spacer(),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              AnimNum(g.streakCurrent.toDouble(), style: _big(null, compact ? 38 : 50)),
                              const SizedBox(width: 4),
                              Text(g.streakCurrent == 1 ? 'day' : 'days', style: _t.t(15, c: _t.muted)),
                            ],
                          ),
                          const Spacer(),
                          _kv('Longest', '${g.streakLongest} days', vw: FontWeight.w500),
                          _kv(
                            'Best day',
                            g.bestDay == null ? '—' : '${g.bestDay!.count} on ${month3(g.bestDay!.date)} ${g.bestDay!.date.day}',
                            vw: FontWeight.w500,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: _gap),
                  Expanded(
                    flex: 10,
                    child: _card(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _lb('This week'),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              AnimNum(g.weekTotal.toDouble(), style: _big()),
                              const SizedBox(width: 8),
                              Text(
                                '${g.weekDelta >= 0 ? '+' : ''}${g.weekDelta} vs last week',
                                style: _t.t(12, w: FontWeight.w600, c: g.weekDelta >= 0 ? _t.green : _t.muted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (var i = 0; i < 7; i++)
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Expanded(
                                          child: LayoutBuilder(
                                            builder: (context, c) => Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                _wkBar(
                                                  c.maxHeight * (i < g.lastWeek.length ? g.lastWeek[i] : 0) / mx,
                                                  const Color(0xFF2C333C),
                                                ),
                                                const SizedBox(width: 2),
                                                _wkBar(
                                                  c.maxHeight * ((i < g.thisWeek.length ? g.thisWeek[i] : null) ?? 0) / mx,
                                                  _t.green,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'SMTWTFS'[i],
                                          style: _t.t(
                                            10,
                                            w: i == today ? FontWeight.w700 : FontWeight.w500,
                                            c: i == today ? _t.text : _t.faint,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: _gap),
                  Expanded(
                    flex: 11,
                    child: _card(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _lb(topReposLabel(ref)),
                          const SizedBox(height: 3),
                          // As many repos as fit (4 normally, fewer when the bottom nav bar takes room).
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, c) {
                                // Each repo is ~30.3px (13pt name row, 4 gap, 3 bar, 5 gap); the
                                // last one's trailing gap may be clipped, hence the +5.
                                const rowH = 30.5;
                                final n = ((c.maxHeight + 5) / rowH).floor().clamp(1, 4);
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (final (i, r) in g.topRepos.take(n).indexed) ...[
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              r.name,
                                              style: _t.t(13, w: FontWeight.w600),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Text('${r.count}', style: _t.t(13, c: _t.muted)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      _bar(r.count / topRepo, _t.green, h: 3),
                                      if (i < n - 1) const SizedBox(height: 5),
                                    ],
                                  ],
                                );
                              },
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
        );
      },
    );
  }

  Widget _wkBar(double h, Color c) => TweenAnimationBuilder<double>(
    tween: Tween(end: math.max(2, h)),
    duration: const Duration(milliseconds: 650),
    builder: (context, v, _) => Container(
      width: 7,
      height: v,
      decoration: BoxDecoration(
        color: c,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(3), bottom: Radius.circular(1)),
      ),
    ),
  );
}

String _thousands(int n) => n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

// ------------------------------------------------------------------ Shortcuts

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
    return Column(
      children: [
        for (final (ri, row) in rows.indexed) ...[
          if (ri > 0) const SizedBox(height: _gap),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(width: _gap),
                  Expanded(child: i < row.length ? _tile(context, ref, row[i], s.volumePct) : const SizedBox()),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _tile(BuildContext context, WidgetRef ref, Tile t, int? vol) {
    final on = t.active;
    final c = on ? _t.bad : hex(t.color, const Color(0xFFAEB6C2));
    return Press(
      onTap: () => act(context, ref, 'shortcut.run', {'id': t.id}),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: on ? _t.bad.withValues(alpha: .08) : _t.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: on ? _t.bad.withValues(alpha: .5) : _t.line),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DpIcon(tileIcon(t), size: 40, color: c, stroke: 1.6),
            const SizedBox(height: 10),
            Text(tileLabel(t), style: _t.t(14, w: FontWeight.w600)),
            if (t.detail != null || (t.id.startsWith('volume') && vol != null)) ...[
              const SizedBox(height: 4),
              Text(t.detail ?? 'Volume $vol%', style: _t.t(11, c: _t.muted)),
            ],
          ],
        ),
      ),
    );
  }
}
