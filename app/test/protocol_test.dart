import 'dart:convert';
import 'dart:io';

import 'package:deskpanel/core/conn/pairing.dart';
import 'package:deskpanel/core/data/calendar.dart';
import 'package:deskpanel/core/proto/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// shared/fixtures is generated from the agent's pydantic models; parsing every file
/// here keeps the Dart models in sync with the agent.
void main() {
  final dir = Directory('../shared/fixtures');

  group('fixtures parse into typed models', () {
    for (final topic in allTopics) {
      test(topic, () {
        final f = File('${dir.path}/$topic.json');
        expect(f.existsSync(), isTrue, reason: 'missing ${f.path}');
        final data = parseTopic(topic, jsonDecode(f.readAsStringSync()) as Json);
        expect(data.status, TopicStatus.ok);
        expect(data, isNot(isA<StatusOnly>()));
      });
    }
  });

  test('system fixture values', () {
    final s = SystemData(jsonDecode(File('${dir.path}/system.json').readAsStringSync()) as Json);
    expect(s.cpuHistory, hasLength(60));
    expect(s.gpu.available, isTrue);
    expect(s.ramTotal, 32 * 1024 * 1024 * 1024);
  });

  test('non-ok payloads parse to StatusOnly with a message', () {
    final d = parseTopic('github', {'status': 'unconfigured', 'message': 'Add a token'});
    expect(d, isA<StatusOnly>());
    expect(d.status, TopicStatus.unconfigured);
    expect(d.message, 'Add a token');
  });

  test('limit window counts as expired once resets_at passes', () {
    final w = LimitWindow({'used_pct': 90, 'resets_at': 1000});
    expect(w.isExpired(DateTime.fromMillisecondsSinceEpoch(999)), isFalse);
    expect(w.isExpired(DateTime.fromMillisecondsSinceEpoch(1000)), isTrue);
  });

  test('media position interpolates while playing and clamps to duration', () {
    final m = MediaData({
      'status': 'ok', 'playing': true, 'duration_ms': 10000, 'position_ms': 2000, 'position_at': 0,
    });
    expect(m.positionNow(DateTime.fromMillisecondsSinceEpoch(3000)), 5000);
    expect(m.positionNow(DateTime.fromMillisecondsSinceEpoch(60000)), 10000);
    expect(m.positionNow(DateTime.fromMillisecondsSinceEpoch(3000), skewMs: 1000), 6000);
  });

  group('pairing QR', () {
    const fp = 'ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12';
    test('parses a full code', () {
      final p = Pairing.parse(
          'deskpanel://pair?v=1&id=1a2b&n=Laptop&h=192.168.0.5,10.0.0.2&p=8765&t=abcdefghijklmnopqrstuvwxyz0123&fp=$fp')!;
      expect(p.agentId, '1a2b');
      expect(p.hosts, ['192.168.0.5', '10.0.0.2']);
      expect(p.port, 8765);
      expect(p.tls, isTrue);
    });
    test('rejects other QR codes and malformed fingerprints', () {
      expect(Pairing.parse('https://example.com'), isNull);
      expect(Pairing.parse('deskpanel://pair?id=x&p=1&t=short'), isNull);
      expect(Pairing.parse('deskpanel://pair?id=x&p=1&t=abcdefghijklmnopqrstuvwxyz&fp=nothex'), isNull);
    });
    test('round-trips through storage json', () {
      final p = Pairing.parse('deskpanel://pair?id=x&n=L&h=1.2.3.4&p=1&t=abcdefghijklmnopqrstuvwxyz')!;
      final q = Pairing.fromJson(p.toJson());
      expect((q.agentId, q.token, q.fingerprint), (p.agentId, p.token, null));
      expect(q.hosts, p.hosts);
    });
  });

  test('calendar merge: dedupes the same event from phone + ICS, drops past/far, sorts', () {
    final now = DateTime(2026, 11, 23, 15);
    CalEvent ev(String id, String t, DateTime s, [int mins = 30]) =>
        CalEvent(id: id, title: t, start: s, end: s.add(Duration(minutes: mins)));
    final out = mergeEvents([
      ev('a', 'Standup', DateTime(2026, 11, 24, 9)),
      ev('b', 'standup ', DateTime(2026, 11, 24, 9)), // same event via ICS
      ev('c', 'Lunch', DateTime(2026, 11, 23, 13)), // earlier today: kept (today)
      ev('d', 'Old', DateTime(2026, 11, 22, 10)), // yesterday: dropped
      ev('e', 'Far', DateTime(2026, 12, 9, 10)), // beyond 7 days: dropped
    ], now);
    expect(out.map((e) => e.id), ['c', 'a']);
  });
}
