import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/conn/controller.dart';
import '../../core/conn/loop.dart';
import '../../core/data/open_meteo.dart';
import '../../core/data/topics.dart';
import '../../core/data/weather.dart';
import '../../core/proto/models.dart';
import '../../core/pages.dart';
import '../../core/platform/notify_sound.dart';
import '../../core/settings.dart';
import '../fmt.dart';
import '../icons.dart';
import '../skin.dart';
import '../widgets/common.dart';
import 'mouse_arrange_screen.dart';
import 'pair_screen.dart';

Route<void> settingsRoute(BuildContext context) =>
    MaterialPageRoute(builder: (_) => const SettingsScreen());

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final s = ref.watch(settingsProvider);
    final set = ref.read(settingsProvider.notifier).update;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Left column: connection + theme
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(24, 18, 12, 24), children: [
              Row(children: [
                Press(
                  onTap: () => Navigator.of(context).pop(),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(Icons.arrow_back, color: t.text, size: 22),
                  ),
                ),
                Text('Settings', style: t.d(26)),
              ]),
              const SizedBox(height: 18),
              const _ConnectionSection(),
              const SizedBox(height: 22),
              _Label('THEME'),
              LayoutBuilder(builder: (context, c) {
                final w = (c.maxWidth - 20) / 3;
                return Wrap(spacing: 10, runSpacing: 10, children: [
                  for (final id in SkinId.values)
                    SizedBox(
                      width: w,
                      child: _ThemeCard(id: id, selected: s.skin == id, onTap: () => set((x) => x.copyWith(skin: id))),
                    ),
                ]);
              }),
              if (s.skin == SkinId.slate) ...[
                const SizedBox(height: 14),
                _Row(
                  title: 'Navigation',
                  trailing: _Segmented<NavStyle>(
                    value: s.navStyle,
                    items: const {NavStyle.rail: 'Side rail', NavStyle.bottom: 'Bottom bar'},
                    onChanged: (v) => set((x) => x.copyWith(navStyle: v)),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              _Label('WEATHER'),
              _Row(
                title: 'Location',
                subtitle: s.autoLocation
                    ? 'Automatic (phone location) · ${s.place?.name ?? 'locating…'}'
                    : (s.place?.name ?? 'Not set: tap to choose'),
                onTap: () => _pickPlace(context, ref),
                trailing: Icon(Icons.chevron_right, color: t.muted),
              ),
              const SizedBox(height: 22),
              _Label('DISPLAY'),
              _Row(
                title: 'Temperature',
                trailing: _Segmented<bool>(
                  value: s.fahrenheit,
                  items: const {true: '°F', false: '°C'},
                  onChanged: (v) => set((x) => x.copyWith(fahrenheit: v)),
                ),
              ),
              _Row(
                title: 'Clock',
                trailing: _Segmented<bool>(
                  value: s.clock24,
                  items: const {false: '12-hour', true: '24-hour'},
                  onChanged: (v) => set((x) => x.copyWith(clock24: v)),
                ),
              ),
              const SizedBox(height: 22),
              _Label('BURN-IN PROTECTION'),
              _Row(
                title: 'Pixel shift',
                subtitle: 'Moves the whole screen slightly so nothing stays in one place',
                trailing: _Segmented<ShiftLevel>(
                  value: s.shift,
                  items: const {ShiftLevel.off: 'Off', ShiftLevel.gentle: 'Gentle', ShiftLevel.strong: 'Strong'},
                  onChanged: (v) => set((x) => x.copyWith(shift: v)),
                ),
              ),
              _Row(
                title: 'Dim when idle',
                subtitle: 'Darkens the screen until you touch it',
                trailing: _Segmented<int>(
                  value: s.idleDimMin,
                  items: const {0: 'Off', 5: '5m', 10: '10m', 30: '30m'},
                  onChanged: (v) => set((x) => x.copyWith(idleDimMin: v)),
                ),
              ),
              _Row(
                title: 'Screensaver',
                subtitle: 'Black screen with a small moving clock; tap to wake',
                trailing: _Segmented<int>(
                  value: s.saverMin,
                  items: const {0: 'Off', 15: '15m', 30: '30m', 60: '1h'},
                  onChanged: (v) => set((x) => x.copyWith(saverMin: v)),
                ),
              ),
              _Row(
                title: 'Rotate pages',
                subtitle: 'Cycles through your pages while idle',
                trailing: _Segmented<int>(
                  value: s.rotateMin,
                  items: const {0: 'Off', 2: '2m', 5: '5m', 10: '10m'},
                  onChanged: (v) => set((x) => x.copyWith(rotateMin: v)),
                ),
              ),
              _Row(
                title: 'Night dim',
                subtitle: '${_hm(s.nightStartMin, s.clock24)} – ${_hm(s.nightEndMin, s.clock24)}',
                onTap: s.nightDim ? () => _pickDim(context, ref, s) : null,
                trailing: Switch(value: s.nightDim, onChanged: (v) => set((x) => x.copyWith(nightDim: v))),
              ),
              const SizedBox(height: 22),
              _Label('SLACK'),
              _Row(
                title: 'Sound for new messages',
                subtitle: s.slackSound ? "Your phone's notification sound. Tap to hear it" : 'Off',
                onTap: s.slackSound ? playNotificationSound : null,
                trailing: Switch(value: s.slackSound, onChanged: (v) => set((x) => x.copyWith(slackSound: v))),
              ),
              const SizedBox(height: 22),
              _Label('LAPTOP MOUSE'),
              _Row(
                title: 'Move the laptop mouse onto the phone',
                subtitle: s.mouseOn && s.mouseRect != null
                    ? 'Push it off your screen where the phone touches. Esc brings it back'
                    : 'Like a second screen: place the phone next to yours',
                trailing: Switch(
                  value: s.mouseOn,
                  onChanged: (v) {
                    set((x) => x.copyWith(mouseOn: v));
                    if (v && s.mouseRect == null) Navigator.of(context).push(mouseArrangeRoute());
                  },
                ),
              ),
              _Row(
                title: 'Phone position',
                subtitle: s.mouseRect == null ? 'Not placed yet' : 'Drag the phone next to your screen(s)',
                onTap: () => Navigator.of(context).push(mouseArrangeRoute()),
                trailing: _Chip('Arrange…', () => Navigator.of(context).push(mouseArrangeRoute())),
              ),
              ValueListenableBuilder<String?>(
                valueListenable: mouseError,
                builder: (context, err, _) => err == null || !s.mouseOn
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(err, style: context.tk.t(12, c: context.tk.bad)),
                      ),
              ),
              const SizedBox(height: 22),
              _Label('OTHER'),
              _Row(
                title: 'Demo mode',
                subtitle: 'Sample data, no laptop needed',
                trailing: Switch(value: s.demo, onChanged: (v) => set((x) => x.copyWith(demo: v))),
              ),
            ]),
          ),
          // Right column: pages
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 18, 24, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 44),
                _Label('PAGES · DRAG TO REORDER'),
                Expanded(
                  child: ReorderableListView(
                    buildDefaultDragHandles: false,
                    onReorderItem: (a, b) => set((x) {
                      final l = [...x.pages];
                      final p = l.removeAt(a);
                      l.insert(b, p);
                      return x.copyWith(pages: l);
                    }),
                    children: [
                      for (final (i, p) in s.pages.indexed)
                        Container(
                          key: ValueKey(p),
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: t.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: t.line),
                          ),
                          child: Row(children: [
                            ReorderableDragStartListener(
                              index: i,
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Icon(Icons.drag_indicator, color: t.faint, size: 20),
                              ),
                            ),
                            const SizedBox(width: 6),
                            DpIcon(p.icon, size: 18, color: p == PageId.claude ? t.claude : t.text),
                            const SizedBox(width: 12),
                            Expanded(child: Text(p.label, style: t.t(14, w: FontWeight.w600))),
                            Switch(
                              value: !s.hidden.contains(p),
                              onChanged: p == PageId.home
                                  ? null
                                  : (v) => set((x) => x.copyWith(
                                      hidden: v ? ({...x.hidden}..remove(p)) : {...x.hidden, p})),
                            ),
                          ]),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _Label('SHORTCUT TILES · DRAG TO REORDER'),
                const Expanded(child: _TileOrder()),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _pickPlace(BuildContext context, WidgetRef ref) async {
    final hit = await showDialog<Object>(context: context, builder: (_) => const _PlaceSearch());
    if (hit == null) return;
    if (hit == _PlaceSearch.auto) {
      ref.read(settingsProvider.notifier).update((x) => x.copyWith(autoLocation: true));
      await ref.read(weatherProvider.notifier).locate();
      final issue = ref.read(weatherIssueProvider);
      if (issue != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(issue)));
      }
      return;
    }
    final h = hit as PlaceHit;
    ref.read(settingsProvider.notifier).update((x) => x.copyWith(place: h.place, autoLocation: false));
  }

  static String _hm(int m, bool h24) => clockFull(DateTime(2000, 1, 1, m ~/ 60, m % 60), h24: h24);

  Future<void> _pickDim(BuildContext context, WidgetRef ref, AppSettings s) async {
    final a = await showTimePicker(
        context: context,
        helpText: 'Dim from',
        initialTime: TimeOfDay(hour: s.nightStartMin ~/ 60, minute: s.nightStartMin % 60));
    if (a == null || !context.mounted) return;
    final b = await showTimePicker(
        context: context,
        helpText: 'Until',
        initialTime: TimeOfDay(hour: s.nightEndMin ~/ 60, minute: s.nightEndMin % 60));
    if (b == null) return;
    ref.read(settingsProvider.notifier).update(
        (x) => x.copyWith(nightStartMin: a.hour * 60 + a.minute, nightEndMin: b.hour * 60 + b.minute));
  }
}

class _ConnectionSection extends ConsumerWidget {
  const _ConnectionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final c = ref.watch(agentProvider);
    final ctl = ref.read(agentProvider.notifier);
    final sum = connSummary(c);
    final detail = switch (c.status) {
      LinkStatus.connected =>
        '${c.agentName ?? 'Laptop'} · ${c.transport == Transport.usb ? 'USB cable (adb reverse)' : 'Wi-Fi ${c.host}'}',
      LinkStatus.offline => 'Retrying${c.retryIn != null ? ' in ${c.retryIn!.inSeconds}s' : ''}'
          '${c.lastConnected != null ? ' · last connected ${ago(DateTime.now().difference(c.lastConnected!))}' : ''}',
      LinkStatus.demo => 'Showing sample data',
      LinkStatus.unpaired => 'Scan the QR code from deskpanel-agent pair',
      LinkStatus.authFailed => 'The laptop no longer accepts this phone\'s token',
      _ => c.agentName ?? '',
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Label('LAPTOP'),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            DpIcon('monitor', size: 18, color: sum.ok ? t.ok : t.bad),
            const SizedBox(width: 6),
            DpIcon(sum.icon, size: 18, color: sum.ok ? t.ok : t.bad),
            const SizedBox(width: 10),
            Text(sum.text, style: t.t(15, w: FontWeight.w700)),
          ]),
          const SizedBox(height: 4),
          Text(detail, style: t.t(12.5, c: t.muted)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _Chip(c.pairing == null ? 'Pair' : 'Re-pair', () => Navigator.of(context).push(pairRoute())),
            if (c.status == LinkStatus.offline) _Chip('Retry now', ctl.retryNow),
            if (c.pairing != null) _Chip('Manual IP…', () => _manualIp(context, ctl)),
            if (c.pairing != null) _Chip('Forget laptop', ctl.unpair),
          ]),
        ]),
      ),
    ]);
  }

  Future<void> _manualIp(BuildContext context, AgentController ctl) async {
    final ctrl = TextEditingController();
    final ip = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Laptop IP address'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: '192.168.1.20'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, ''), child: const Text('Clear')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (ip != null) await ctl.setManualHost(ip.isEmpty ? null : ip);
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.id, required this.selected, required this.onTap});
  final SkinId id;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final preview = Skin.of(id).tokens;
    return Press(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? t.accent : t.line, width: selected ? 2 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(colors: [preview.bg, preview.surface2]),
              border: Border.all(color: preview.line),
            ),
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              Text('38', style: preview.d(24, c: preview.dark ? preview.text : preview.accent)),
              const Spacer(),
              for (final c in [preview.cpu, preview.gpu, preview.ram])
                Container(
                    width: 6, height: 20, margin: const EdgeInsets.only(left: 3),
                    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
            ]),
          ),
          const SizedBox(height: 8),
          Text(id.label, style: t.t(14, w: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(id.blurb, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.t(11, c: t.muted, h: 1.3)),
        ]),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(bottom: 8, left: 2), child: Text(text, style: context.tk.label));
}

class _Row extends StatelessWidget {
  const _Row({required this.title, this.subtitle, required this.trailing, this.onTap});
  final String title;
  final String? subtitle;
  final Widget trailing;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Press(
      onTap: onTap,
      scale: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: t.t(14, w: FontWeight.w600)),
              if (subtitle != null) Text(subtitle!, style: t.t(12, c: t.muted)),
            ]),
          ),
          trailing,
        ]),
      ),
    );
  }
}

class _Segmented<T> extends StatelessWidget {
  const _Segmented({required this.value, required this.items, required this.onChanged});
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: t.line),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final e in items.entries)
          Press(
            onTap: () => onChanged(e.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: e.key == value ? t.accent : const Color(0x00000000),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(e.value,
                  style: t.t(12, w: FontWeight.w600, c: e.key == value ? t.onAccent : t.muted)),
            ),
          ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Press(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: t.muted.withValues(alpha: .45)),
        ),
        child: Text(label, style: t.t(12.5, w: FontWeight.w600)),
      ),
    );
  }
}

/// Reorders the shortcut tiles the agent offers. Only order is stored on the phone; what a
/// tile does is defined on the laptop (built-ins + [[shortcuts.custom]] allowlist).
class _TileOrder extends ConsumerWidget {
  const _TileOrder();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final d = ref.watch(topicProvider('shortcuts'))?.data;
    final s = ref.watch(settingsProvider);
    if (d is! ShortcutsData) {
      return Text('Connect the laptop to see its shortcut tiles.', style: t.t(12.5, c: t.muted));
    }
    final idx = {for (final (i, id) in s.tileOrder.indexed) id: i};
    final tiles = [...d.tiles]..sort((a, b) => (idx[a.id] ?? 999).compareTo(idx[b.id] ?? 999));
    return ReorderableListView(
      buildDefaultDragHandles: false,
      onReorderItem: (a, b) => ref.read(settingsProvider.notifier).update((x) {
        final l = tiles.map((e) => e.id).toList();
        final id = l.removeAt(a);
        l.insert(b, id);
        return x.copyWith(tileOrder: l);
      }),
      children: [
        for (final (i, tile) in tiles.indexed)
          Container(
            key: ValueKey(tile.id),
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: t.line),
            ),
            child: Row(children: [
              ReorderableDragStartListener(
                index: i,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.drag_indicator, color: t.faint, size: 20),
                ),
              ),
              const SizedBox(width: 6),
              DpIcon(tile.icon, size: 18, color: hex(tile.color, t.text)),
              const SizedBox(width: 12),
              Expanded(child: Text(tile.label, style: t.t(14, w: FontWeight.w600))),
            ]),
          ),
      ],
    );
  }
}

/// City search via Open-Meteo geocoding.
class _PlaceSearch extends StatefulWidget {
  const _PlaceSearch();

  /// Returned when the user chooses automatic (phone) location.
  static const auto = 'auto';
  @override
  State<_PlaceSearch> createState() => _PlaceSearchState();
}

class _PlaceSearchState extends State<_PlaceSearch> {
  final _ctrl = TextEditingController();
  List<PlaceHit> _hits = const [];
  String? _error;
  bool _busy = false;
  int _seq = 0;

  Future<void> _search(String q) async {
    final mine = ++_seq;
    if (q.trim().length < 2) {
      setState(() => _hits = const []);
      return;
    }
    setState(() => _busy = true);
    try {
      final hits = await searchPlaces(q);
      if (mine != _seq || !mounted) return;
      setState(() {
        _hits = hits;
        _error = hits.isEmpty ? 'No places found' : null;
        _busy = false;
      });
    } catch (_) {
      if (mine != _seq || !mounted) return;
      setState(() {
        _error = 'Search failed. Check the phone has internet.';
        _busy = false;
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Weather location'),
        content: SizedBox(
          width: 420,
          height: 260,
          child: Column(children: [
            ListTile(
              dense: true,
              leading: const Icon(Icons.my_location),
              title: const Text('Use phone location'),
              subtitle: const Text('Automatic, approximate (city level)'),
              onTap: () => Navigator.pop(context, _PlaceSearch.auto),
            ),
            TextField(
              controller: _ctrl,
              decoration: InputDecoration(
                hintText: 'City, e.g. Kochi',
                suffixIcon: _busy ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))) : null,
              ),
              onChanged: _search,
              onSubmitted: _search,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _error != null && _hits.isEmpty
                  ? Center(child: Text(_error!))
                  : ListView(children: [
                      for (final h in _hits)
                        ListTile(
                          dense: true,
                          title: Text(h.place.name),
                          subtitle: Text(h.detail),
                          onTap: () => Navigator.pop(context, h),
                        ),
                    ]),
            ),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))],
      );
}

