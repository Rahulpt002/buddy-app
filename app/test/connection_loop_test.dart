import 'dart:async';

import 'package:deskpanel/core/conn/loop.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeLink implements AgentLink {
  FakeLink(this.ep);
  final Endpoint ep;
  final _done = Completer<void>();
  bool closed = false;
  void drop() {
    if (!_done.isCompleted) _done.complete();
  }

  @override
  Future<void> get done => _done.future;
  @override
  Future<void> close() async {
    closed = true;
    drop();
  }
}

/// Scripted network: which hosts are reachable right now.
class FakeNet {
  final reachable = <String>{};
  FailKind? failAllWith;
  final attempts = <String>[];
  final links = <FakeLink>[];

  Future<AgentLink> connect(Endpoint ep, Duration timeout) async {
    attempts.add(ep.host);
    await Future<void>.delayed(Duration.zero);
    if (failAllWith != null) throw ConnectFailure(failAllWith!);
    if (!reachable.contains(ep.host)) throw ConnectFailure(FailKind.unreachable);
    final l = FakeLink(ep);
    links.add(l);
    return l;
  }
}

/// Sleeps resolve only when the test releases them, so timing is deterministic.
class FakeClock {
  final pending = <(Duration, Completer<void>)>[];
  Future<void> sleep(Duration d) {
    final c = Completer<void>();
    pending.add((d, c));
    return c.future;
  }

  /// Complete every outstanding sleep.
  Future<void> tick() async {
    final now = [...pending];
    pending.clear();
    for (final (_, c) in now) {
      c.complete();
    }
    await pump();
  }
}

Future<void> pump() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeNet net;
  late FakeClock clock;
  late List<LoopState> states;
  late List<Endpoint> adopted;
  late ConnectionLoop loop;

  List<Endpoint> candidates() =>
      orderCandidates(port: 8765, lastHost: '10.0.0.5', qrHosts: ['10.0.0.5', '10.0.0.9']);

  setUp(() {
    net = FakeNet();
    clock = FakeClock();
    states = [];
    adopted = [];
    loop = ConnectionLoop(
      connect: net.connect,
      candidates: candidates,
      onState: states.add,
      onLink: (l, ep) => adopted.add(ep),
      sleep: clock.sleep,
    );
  });

  tearDown(() => loop.stop());

  test('candidate order: USB, agent-reported, last host, mDNS, QR, manual; deduped', () {
    final c = orderCandidates(
        port: 1, knownHosts: ['k', 'a'], lastHost: 'a', mdnsHosts: ['b', 'a'], qrHosts: ['c', 'b'], manualHost: 'd');
    expect(c.map((e) => '${e.source}:${e.host}'),
        ['usb:127.0.0.1', 'agent:k', 'agent:a', 'mdns:b', 'qr:c', 'manual:d']);
    expect(c.first.transport, Transport.usb);
  });

  test('backoff grows 1,2,4,8 and caps at 15s', () {
    expect([for (var i = 0; i < 7; i++) backoff(i).inSeconds], [1, 2, 4, 8, 15, 15, 15]);
  });

  test('prefers USB when the cable is connected', () async {
    net.reachable.addAll(['127.0.0.1', '10.0.0.5']);
    unawaited(loop.run());
    await pump();
    expect(adopted.single.transport, Transport.usb);
    expect(net.attempts, ['127.0.0.1']);
  });

  test('falls back to Wi-Fi hosts in order when USB is unavailable', () async {
    net.reachable.add('10.0.0.9');
    unawaited(loop.run());
    await pump();
    expect(net.attempts, ['127.0.0.1', '10.0.0.5', '10.0.0.9']);
    expect(adopted.single.host, '10.0.0.9');
    expect(states.last, isA<Connected>());
  });

  test('switches to USB when the cable is plugged in while on Wi-Fi (make-before-break)', () async {
    net.reachable.add('10.0.0.5');
    unawaited(loop.run());
    await pump();
    expect(adopted.single.transport, Transport.wifi);
    final wifiLink = net.links.single;

    await clock.tick(); // probe: still no cable
    expect(adopted.length, 1);

    net.reachable.add('127.0.0.1'); // plug in
    await clock.tick();
    expect(adopted.map((e) => e.transport), [Transport.wifi, Transport.usb]);
    expect(wifiLink.closed, isTrue, reason: 'old Wi-Fi link closed after USB is adopted');
    expect((states.last as Connected).endpoint.transport, Transport.usb);
  });

  test('reconnects with growing backoff, resets after success', () async {
    unawaited(loop.run());
    await pump();
    expect(states.last, isA<Waiting>());
    expect((states.last as Waiting).retryIn, const Duration(seconds: 1));
    await clock.tick();
    expect((states.last as Waiting).retryIn, const Duration(seconds: 2));
    await clock.tick();
    expect((states.last as Waiting).retryIn, const Duration(seconds: 4));

    net.reachable.add('127.0.0.1');
    await clock.tick();
    expect(states.last, isA<Connected>());

    // Cable yanked and agent unreachable: backoff restarts at 1s.
    net.reachable.clear();
    net.links.last.drop();
    await pump();
    expect((states.last as Waiting).retryIn, const Duration(seconds: 1));
  });

  test('USB drop falls back to Wi-Fi immediately', () async {
    net.reachable.addAll(['127.0.0.1', '10.0.0.5']);
    unawaited(loop.run());
    await pump();
    net.reachable.remove('127.0.0.1');
    net.links.single.drop();
    await pump();
    expect(adopted.map((e) => e.transport), [Transport.usb, Transport.wifi]);
  });

  test('kick() skips the remaining backoff', () async {
    unawaited(loop.run());
    await pump();
    expect(states.last, isA<Waiting>());
    net.reachable.add('10.0.0.5');
    loop.kick();
    await pump();
    expect(states.last, isA<Connected>());
  });

  test('auth failure stops the loop (no retry storm) and reports it', () async {
    net.failAllWith = FailKind.auth;
    unawaited(loop.run());
    await pump();
    expect(states.last, isA<Stopped>());
    expect((states.last as Stopped).reason, FailKind.auth);
    expect(net.attempts.length, 1);
    expect(clock.pending, isEmpty);
  });
}
