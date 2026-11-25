import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

import '../conn/controller.dart';
import '../proto/models.dart';
import 'topics.dart';

/// Built-in demo mode: replays shared/fixtures (copied to assets/fixtures) with live
/// jitter, so the app is fully explorable with no laptop.
class DemoSource {
  DemoSource(this.store);
  final TopicStore store;
  final _r = Random(3);
  Timer? _t;
  final _data = <String, Json>{};
  int _tick = 0;

  static const _topics = [
    'system', 'network', 'claude', 'media', 'media.art', 'hotspot', 'slack', 'github',
    'shortcuts', 'calendar',
  ];

  int? _generatedAt;

  Future<void> start() async {
    try {
      _generatedAt = (jsonDecode(await rootBundle.loadString('assets/fixtures/_meta.json')) as Json)['generated_at'] as int;
    } catch (_) {}
    for (final t in _topics) {
      try {
        _data[t] = jsonDecode(await rootBundle.loadString('assets/fixtures/$t.json')) as Json;
      } catch (_) {}
    }
    _rebase();
    _data.forEach(store.ingest);
    _t = Timer.periodic(const Duration(seconds: 1), (_) => _step());
  }

  void stop() => _t?.cancel();

  void _rebase() => rebaseFixtures(_data, _generatedAt, DateTime.now());

  double _w(num v, double a, double lo, double hi) =>
      (v + (_r.nextDouble() - .5) * a).clamp(lo, hi).toDouble();

  void _step() {
    _tick++;
    final s = _data['system'];
    if (s != null) {
      final cpu = s['cpu'] as Json, gpu = s['gpu'] as Json, h = s['history'] as Json;
      cpu['pct'] = _w(cpu['pct'] as num, 9, 12, 72);
      gpu['pct'] = _w(gpu['pct'] as num, 8, 30, 80);
      gpu['temp_c'] = (44 + (gpu['pct'] as double) * .2).roundToDouble();
      (h['cpu'] as List)
        ..removeAt(0)
        ..add(cpu['pct']);
      (h['gpu'] as List)
        ..removeAt(0)
        ..add(gpu['pct']);
      final net = s['net'] as Json;
      net['down_bps'] = _w(net['down_bps'] as num, 6e5, 2e5, 4.2e6);
      net['up_bps'] = _w(net['up_bps'] as num, 6e4, 6e4, 4.8e5);
      store.ingest('system', s);
    }
    final n = _data['network'];
    if (n != null) {
      final lat = n['latency'] as Json;
      final v = _r.nextDouble() < .03 ? 30 + _r.nextDouble() * 10 : 15 + _r.nextDouble() * 4;
      lat['ms'] = double.parse(v.toStringAsFixed(1));
      ((lat['history'] as Json)['ms'] as List)
        ..removeAt(0)
        ..add(lat['ms']);
      store.ingest('network', n);
    }
    if (_tick % 5 == 0) {
      for (final t in ['claude', 'media', 'hotspot', 'shortcuts']) {
        if (_data[t] != null) store.ingest(t, _data[t]!);
      }
    }
  }

  Future<ActionResult> request(
      String action, Map<String, dynamic> params, void Function(Map<String, dynamic>)? onProgress) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    switch (action) {
      case 'mouse.displays': // a 27" 1440p monitor, for the Phone position screen
        return const ActionResult(true, result: {
          'displays': [
            {'x': 0, 'y': 0, 'w': 2560, 'h': 1440, 'mm_w': 591.1, 'mm_h': 329.5, 'main': true, 'builtin': false},
          ],
        });
      case 'media.play_pause':
        final m = _data['media']!;
        final pos = MediaData(m).positionNow(DateTime.now());
        m
          ..['playing'] = !(m['playing'] as bool)
          ..['position_ms'] = pos
          ..['position_at'] = now;
        store.ingest('media', m);
      case 'media.seek':
        _data['media']!
          ..['position_ms'] = params['position_ms']
          ..['position_at'] = now;
        store.ingest('media', _data['media']!);
      case 'shortcut.run':
        final sc = _data['shortcuts']!;
        for (final t in (sc['tiles'] as List).cast<Json>()) {
          if (t['id'] == params['id'] && (t['id'] as String).endsWith('.toggle')) {
            final st = (t['state'] as Json?) ?? <String, dynamic>{};
            st['active'] = !((st['active'] as bool?) ?? false);
            t['state'] = st;
          }
        }
        store.ingest('shortcuts', sc);
      case 'speedtest.run':
        final n = _data['network']!;
        final sp = n['speedtest'] as Json;
        sp['state'] = 'running';
        for (var i = 1; i <= 30; i++) {
          await Future.delayed(const Duration(milliseconds: 200));
          final p = i / 30;
          sp['progress'] = {
            'phase': p < .1 ? 'ping' : p < .6 ? 'download' : 'upload',
            'pct': p * 100,
            'down_bps': p >= .1 ? 115e6 * min(1, p / .3) : null,
            'up_bps': p >= .6 ? 4.7e6 * min(1, (p - .6) / .25) : null,
          };
          onProgress?.call(sp['progress'] as Json);
          store.ingest('network', n);
        }
        sp
          ..['state'] = 'idle'
          ..['progress'] = null
          ..['last'] = {'down_bps': 117e6, 'up_bps': 4.875e6, 'ping_ms': 8, 'at': now};
        store.ingest('network', n);
    }
    return const ActionResult(true);
  }
}

const _timeKeys = {
  'position_at', 'resets_at', 'updated_at', 'online_since', 'last_drop', 'at', 'session_start', 'start', 'end',
  'fetched_at', 'ts',
  'last_seen', 'updated', 'down_since', 'session_expires', // hotspot
};

/// Fixtures were captured at [generatedAt]; shift every epoch-ms timestamp so the data
/// looks current (resets in 2h 12m, next event in 25 min, ...).
void rebaseFixtures(Map<String, Json> data, int? generatedAt, DateTime now) {
  if (generatedAt == null) return;
  final delta = now.millisecondsSinceEpoch - generatedAt;
  void walk(Object? o) {
    if (o is Map<String, dynamic>) {
      for (final k in o.keys.toList()) {
        final v = o[k];
        if (_timeKeys.contains(k) && v is int && v > 1000000000000) {
          o[k] = v + delta;
        } else {
          walk(v);
        }
      }
    } else if (o is List) {
      o.forEach(walk);
    }
  }

  data.values.forEach(walk);
}
