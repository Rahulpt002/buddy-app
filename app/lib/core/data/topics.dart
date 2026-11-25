import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../proto/models.dart';

class TopicEntry {
  const TopicEntry(this.data, this.raw, this.receivedAt, {this.fromCache = false});
  final TopicData data;
  final Json raw;
  final DateTime receivedAt;

  /// Loaded from disk at launch; not yet refreshed by a live agent.
  final bool fromCache;
}

/// How long until data for a topic counts as stale even while connected.
Duration staleAfter(String topic) => switch (topic) {
      'system' || 'network' => const Duration(seconds: 6),
      'media' || 'shortcuts' || 'claude' => const Duration(seconds: 30),
      'hotspot' => const Duration(minutes: 2), // the agent polls the Server every 30 s
      _ => const Duration(minutes: 40),
    };

/// Latest payload per topic. Persisted so a fresh launch while offline shows the
/// last-known data (marked stale) rather than empty screens.
class TopicStore extends Notifier<Map<String, TopicEntry>> {
  Timer? _saveTimer;
  bool _dirty = false;

  @override
  Map<String, TopicEntry> build() {
    _load();
    _saveTimer = Timer.periodic(const Duration(seconds: 30), (_) => flush());
    ref.onDispose(() => _saveTimer?.cancel());
    return const {};
  }

  void ingest(String topic, Json data, {DateTime? at}) {
    final TopicData parsed;
    try {
      parsed = parseTopic(topic, data);
    } catch (_) {
      return; // malformed payload: keep the previous value rather than blanking
    }
    state = {...state, topic: TopicEntry(parsed, data, at ?? DateTime.now())};
    if (topic != 'media.art' || (data['b64'] != null)) _dirty = true;
  }

  Future<File> _file() async =>
      File('${(await getApplicationSupportDirectory()).path}/last_known.json');

  Future<void> _load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return;
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final restored = <String, TopicEntry>{};
      for (final e in j.entries) {
        final m = e.value as Map<String, dynamic>;
        try {
          restored[e.key] = TopicEntry(parseTopic(e.key, m['data'] as Json), m['data'] as Json,
              DateTime.fromMillisecondsSinceEpoch(m['at'] as int),
              fromCache: true);
        } catch (_) {}
      }
      // Live data that arrived while loading wins.
      state = {...restored, ...state};
    } catch (_) {}
  }

  Future<void> flush() async {
    if (!_dirty) return;
    _dirty = false;
    try {
      final out = {
        for (final e in state.entries)
          e.key: {'at': e.value.receivedAt.millisecondsSinceEpoch, 'data': e.value.raw},
      };
      final f = await _file();
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode(out));
      await tmp.rename(f.path);
    } catch (_) {}
  }
}

final topicStoreProvider =
    NotifierProvider<TopicStore, Map<String, TopicEntry>>(TopicStore.new);

/// Typed access: `ref.watch(topicProvider('system'))`.
final topicProvider = Provider.family<TopicEntry?, String>(
    (ref, topic) => ref.watch(topicStoreProvider.select((m) => m[topic])));
