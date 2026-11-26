// Liquid (concept 16) pages. Home and Music live here; the rest are split across
// liquid_pages_a.dart (System, Claude, Calendar, Weather, GitHub) and liquid_pages_b.dart
// (Hotspot, Timer, Slack, Controls). Shared pieces: liquid_kit.dart.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/conn/controller.dart';
import '../../core/pages.dart';
import '../../core/settings.dart';
import '../fmt.dart';
import '../icons.dart';
import '../pages/kit.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import 'liquid_kit.dart';
import 'liquid_pages_a.dart';
import 'liquid_pages_b.dart';

Widget liquidPage(PageId id) => switch (id) {
      PageId.home => const _Home(),
      PageId.music => const _Music(),
      PageId.system => const LqSystemPage(),
      PageId.claude => const LqClaudePage(),
      PageId.calendar => const LqCalendarPage(),
      PageId.weather => const LqWeatherPage(),
      PageId.github => const LqGithubPage(),
      PageId.hotspot => const LqHotspotPage(),
      PageId.timer => const LqTimerPage(),
      PageId.slack => const LqSlackPage(),
      PageId.shortcuts => const LqControlsPage(),
    };

// ------------------------------------------------------------------ Home

/// Concept home: clock + next event (wide), weather, Claude 5-hour ring; now playing
/// (wide), Slack (in the old printer slot), laptop load bars.
class _Home extends ConsumerWidget {
  const _Home();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void go(PageId p) => PageNav.go(context, p);
    return Ticker(
      builder: (context, now) => lqGrid([
        (1, [(44, _clock(ref, now, () => go(PageId.calendar))), (17, _weather(ref, () => go(PageId.weather))), (17, _claude(ref, now, () => go(PageId.claude)))]),
        (1, [(44, _music(context, ref, now, () => go(PageId.music))), (17, _slack(ref, () => go(PageId.slack))), (17, _laptop(ref, () => go(PageId.system)))]),
      ]),
    );
  }

  Widget _clock(WidgetRef ref, DateTime now, VoidCallback onTap) {
    final h24 = ref.watch(settingsProvider.select((s) => s.clock24));
    final n = nextEvent(ref.watch(calendarEventsProvider), now);
    return LqCard(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // The clock takes whatever height is left (78 px at the design size).
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topLeft,
            child: lqBig(clock(now, h24: h24), 78, unit: h24 ? null : ampm(now)),
          ),
        ),
        const SizedBox(height: 4),
        Text(longDate(now), style: lqT(13.5, c: lqMu)),
        const Spacer(),
        Row(children: [
          const DpIcon('calendar', size: 16, color: lqTx),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              n == null
                  ? TextSpan(text: 'Nothing else today', style: lqT(13.5, w: FontWeight.w700))
                  : TextSpan(children: [
                      TextSpan(text: n.title, style: lqT(13.5, w: FontWeight.w700)),
                      TextSpan(
                          text: '  ${lqIn(n, now)}${n.location == null ? '' : ', ${n.location}'}',
                          style: lqT(13.5, c: lqMu)),
                    ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _weather(WidgetRef ref, VoidCallback onTap) {
    final wx = ref.watch(weatherProvider);
    final f = ref.watch(settingsProvider.select((s) => s.fahrenheit));
    return LqCard(
      onTap: onTap,
      child: wx == null
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              lqLab('Weather'),
              const Spacer(),
              Text('Set a location in Settings', style: lqT(13, c: lqMu)),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              lqLab(wx.place),
              const SizedBox(height: 4),
              lqBig('${temp(wx.now.tempC, f)}°', 46),
              const Spacer(),
              Row(children: [
                DpIcon(wx.now.icon, size: 22, color: lqTx),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(wx.now.condition, style: lqT(13.5, w: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('H ${temp(wx.days.first.hiC, f)}° L ${temp(wx.days.first.loC, f)}°',
                        style: lqT(12, c: lqMu), maxLines: 1),
                  ]),
                ),
              ]),
            ]),
    );
  }

  Widget _claude(WidgetRef ref, DateTime now, VoidCallback onTap) {
    final c = topicData<ClaudeData>(ref, 'claude');
    final pct = limitPct(c?.fiveHour, now);
    return LqCard(
      onTap: onTap,
      child: Column(children: [
        Align(alignment: Alignment.centerLeft, child: lqLab('Claude, 5-hour')),
        Expanded(
          child: Center(
            child: LayoutBuilder(
              builder: (context, box) => LqRing(
                value: pct / 100,
                size: box.biggest.shortestSide.clamp(40.0, 88.0),
                child: Text(c == null ? '—' : '${pct.round()}%', style: lqN(24)),
              ),
            ),
          ),
        ),
        Text(c == null ? 'Not connected' : resetsIn(c.fiveHour, now),
            style: lqT(12, c: lqMu), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _music(BuildContext context, WidgetRef ref, DateTime now, VoidCallback onTap) {
    final m = topicData<MediaData>(ref, 'media');
    final art = topicData<MediaArt>(ref, 'media.art');
    final b64 = art != null && art.artId == m?.artId ? art.b64 : null;
    final skew = ref.read(agentProvider.notifier).clockSkewMs;
    final total = m?.durationMs ?? 0;
    final pos = m == null ? 0 : m.positionNow(now, skewMs: skew);
    return LqCard(
      onTap: onTap,
      child: Row(children: [
        AspectRatio(
          aspectRatio: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 86, maxHeight: 86),
            child: AlbumArt(title: m?.title ?? 'Nothing playing', b64: b64, radius: 16),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            lqLab('Now playing'),
            Text(m?.title ?? 'Nothing playing',
                style: lqT(17, w: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(m?.artist ?? (m == null ? 'Laptop not connected' : ''),
                style: lqT(13.5, c: lqMu), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
            LqBar(value: total == 0 ? 0 : pos / total, height: 5),
          ]),
        ),
        const SizedBox(width: 12),
        if (m != null) ...[
          LqButton.icon('prev', () => act(context, ref, 'media.prev'), size: 42, iconSize: 17),
          const SizedBox(width: 6),
          LqButton.icon(m.playing ? 'pause' : 'play', () => act(context, ref, 'media.play_pause'), size: 50),
          const SizedBox(width: 6),
          LqButton.icon('next', () => act(context, ref, 'media.next'), size: 42, iconSize: 17),
        ],
      ]),
    );
  }

  Widget _slack(WidgetRef ref, VoidCallback onTap) {
    final s = slackHome(ref);
    return LqCard(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        lqLab('Slack'),
        const SizedBox(height: 4),
        s.unread > 0
            ? lqBig('${s.unread}', 40, unit: 'unread')
            : Text(s.headline, style: lqT(20, w: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
        const Spacer(),
        Text(s.detail, style: lqT(12, c: lqMu), maxLines: 2, overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _laptop(WidgetRef ref, VoidCallback onTap) {
    final sys = topicData<SystemData>(ref, 'system');
    Widget row(String l, double? pct) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Text(l, style: lqT(12, c: lqMu)),
              const Spacer(),
              Text(pct == null ? '—' : '${pct.round()}%', style: lqT(12, w: FontWeight.w700)),
            ]),
            const SizedBox(height: 3),
            LqBar(value: (pct ?? 0) / 100, height: 6),
          ]),
        );
    return LqCard(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        lqLab('Laptop'),
        const Spacer(),
        // Three rows share what's left; on a short card they squeeze rather than overflow.
        row('CPU', sys?.cpu.pct),
        row('GPU', sys?.gpu.pct),
        row('RAM', sys == null || sys.ramTotal == 0 ? null : sys.ramUsed / sys.ramTotal * 100),
      ]),
    );
  }
}

// ------------------------------------------------------------------ Music

/// Concept music: the album art large on the left (the wallpaper takes its colours), title
/// and source pill, a glass seek slider, big glass controls and a volume row.
class _Music extends ConsumerWidget {
  const _Music();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = topicData<MediaData>(ref, 'media')!;
    final art = topicData<MediaArt>(ref, 'media.art');
    final b64 = art != null && art.artId == m.artId ? art.b64 : null;
    final skew = ref.read(agentProvider.notifier).clockSkewMs;
    final vol = topicData<ShortcutsData>(ref, 'shortcuts')?.volumePct;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(children: [
        AspectRatio(
          aspectRatio: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 290, maxHeight: 290),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                boxShadow: const [BoxShadow(color: Color(0x47000000), offset: Offset(0, 10))],
              ),
              child: AlbumArt(title: m.title ?? 'Nothing playing', b64: b64, radius: 26),
            ),
          ),
        ),
        const SizedBox(width: 28),
        Expanded(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m.title ?? 'Nothing playing',
                      style: lqT(30, w: FontWeight.w700, h: 1.05, ls: -.02), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(m.artist ?? '', style: lqT(18, c: lqMu), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
              const SizedBox(width: 10),
              LqPill(height: 32, fontSize: 12.5, children: const [
                DpIcon('monitor', size: 15, color: lqTx),
                Text('Laptop speakers'),
              ]),
            ]),
            const SizedBox(height: 18),
            Ticker(
              period: const Duration(seconds: 1),
              builder: (context, now) {
                final pos = m.positionNow(now, skewMs: skew);
                final total = m.durationMs ?? 0;
                return Column(children: [
                  LqSlider(
                    value: total == 0 ? 0 : pos / total,
                    onChanged: m.canSeek && total > 0
                        ? (f) => act(context, ref, 'media.seek', {'position_ms': (f * total).round()})
                        : null,
                  ),
                  const SizedBox(height: 2),
                  Row(children: [
                    Text(mmss(pos), style: lqT(12, c: lqMu)),
                    const Spacer(),
                    Text(total == 0 ? '' : '-${mmss((total - pos).clamp(0, total))}', style: lqT(12, c: lqMu)),
                  ]),
                ]);
              },
            ),
            const SizedBox(height: 12),
            _Transport(m: m, volume: vol),
          ]),
        ),
      ]),
    );
  }
}

/// Prev / play / next, with a small speaker button at the end of the row. Tapping the
/// speaker slides the controls to the left and stretches the speaker sideways into a glass
/// volume capsule (− · slider · + · %, the speaker staying at its right end); it shrinks
/// back into the button 5 s after the last touch, or when the speaker is tapped again.
class _Transport extends ConsumerStatefulWidget {
  const _Transport({required this.m, required this.volume});
  final MediaData m;
  final int? volume;
  @override
  ConsumerState<_Transport> createState() => _TransportState();
}

class _TransportState extends ConsumerState<_Transport> {
  bool _open = false;
  Timer? _hide;

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  /// Show the bar (or keep it up) for another 5 s.
  void _touch() {
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _open = false);
    });
    if (!_open) setState(() => _open = true);
  }

  void _toggle() {
    if (_open) {
      _hide?.cancel();
      setState(() => _open = false);
    } else {
      _touch();
    }
  }

  static const _controls = 60 + 18 + 76 + 18 + 60.0; // prev · play · next
  static const _btn = 44.0, _gap = 16.0, _h = 76.0;
  static const _anim = Duration(milliseconds: 420);
  static const _curve = Cubic(.3, 1.25, .45, 1); // a touch of overshoot, like the tab droplet

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    final vol = widget.volume;
    return SizedBox(
      height: _h,
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth;
        // Open: the controls move to the left edge and the capsule takes the rest of the row
        // (or the whole row on a narrow screen, covering the controls).
        final room = w - _controls - _gap;
        final wide = room >= 200;
        final capW = _open ? (wide ? room : w) : _btn;
        return Stack(clipBehavior: Clip.none, children: [
          AnimatedPositioned(
            duration: _anim,
            curve: _curve,
            left: _open ? 0 : (w - _controls) / 2,
            top: 0,
            width: _controls,
            height: _h,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _open && !wide ? 0 : 1,
              child: Row(children: [
                LqButton.icon('prev', () => act(context, ref, 'media.prev'), size: 60, iconSize: 22),
                const SizedBox(width: 18),
                LqButton.icon(m.playing ? 'pause' : 'play', () => act(context, ref, 'media.play_pause'),
                    size: 76, iconSize: 28),
                const SizedBox(width: 18),
                LqButton.icon('next', () => act(context, ref, 'media.next'), size: 60, iconSize: 22),
              ]),
            ),
          ),
          AnimatedPositioned(
            duration: _anim,
            curve: _curve,
            right: 0,
            top: (_h - _btn) / 2,
            width: capW,
            height: _btn,
            child: LqGlass(
              radius: 99,
              fill: _open ? null : const Color(0x1AFFFFFF),
              shadow: false,
              // The full capsule is laid out once at its open width and revealed from the
              // right as the glass grows, so nothing reflows mid-animation.
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: OverflowBox(
                  alignment: Alignment.centerRight,
                  minWidth: wide ? room : w,
                  maxWidth: wide ? room : w,
                  child: Row(children: [
                    Expanded(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 220),
                        opacity: _open ? 1 : 0,
                        child: IgnorePointer(ignoring: !_open, child: _bar(vol)),
                      ),
                    ),
                    Press(
                      onTap: _toggle,
                      scale: 1.08,
                      child: SizedBox(
                        width: _btn,
                        height: _btn,
                        child: Center(child: DpIcon(vol == 0 ? 'speakerOff' : 'speaker', size: 18, color: lqTx)),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ]);
      }),
    );
  }

  /// − · slider · + · %, inside the capsule.
  Widget _bar(int? vol) => Row(children: [
        const SizedBox(width: 6),
        Press(
          onTap: () {
            _touch();
            act(context, ref, 'shortcut.run', {'id': 'volume.down'});
          },
          child: const Padding(padding: EdgeInsets.all(7), child: DpIcon('volDown', size: 17, color: lqTx)),
        ),
        Expanded(
          child: Listener(
            onPointerDown: (_) => _touch(), // dragging keeps it open
            child: LqSlider(
              value: (vol ?? 0) / 100,
              onChanged: (f) {
                _touch();
                act(context, ref, 'volume.set', {'pct': (f * 100).round()});
              },
            ),
          ),
        ),
        Press(
          onTap: () {
            _touch();
            act(context, ref, 'shortcut.run', {'id': 'volume.up'});
          },
          child: const Padding(padding: EdgeInsets.all(7), child: DpIcon('volUp', size: 17, color: lqTx)),
        ),
        SizedBox(
          width: 40,
          child: Text(vol == null ? '—' : '$vol%', textAlign: TextAlign.right, style: lqT(13, w: FontWeight.w700)),
        ),
        Container(width: 1, height: 20, margin: const EdgeInsets.only(left: 10), color: lqSep),
      ]);
}
