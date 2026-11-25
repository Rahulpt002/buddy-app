// Transport selection and reconnection, independent of sockets and timers so it can be
// unit-tested with fakes (see test/connection_loop_test.dart).
import 'dart:async';
import 'dart:math';

enum Transport { usb, wifi }

class Endpoint {
  const Endpoint(this.host, this.port, this.transport, this.source);
  final String host;
  final int port;
  final Transport transport;

  /// usb | last | qr | mdns | manual
  final String source;

  @override
  bool operator ==(Object other) => other is Endpoint && other.host == host && other.port == port;
  @override
  int get hashCode => Object.hash(host, port);
  @override
  String toString() => '$source:$host:$port';
}

/// Why a connection attempt failed.
enum FailKind {
  /// Not reachable / timed out / TLS pin mismatch — try the next endpoint.
  unreachable,

  /// Agent rejected our token. Stop and ask the user to re-pair.
  auth,

  /// Agent speaks a different protocol version. Stop.
  proto,
}

class ConnectFailure implements Exception {
  ConnectFailure(this.kind, [this.message = '']);
  final FailKind kind;
  final String message;
  @override
  String toString() => 'ConnectFailure($kind, $message)';
}

/// A live, authenticated connection. [done] completes when it drops for any reason.
abstract class AgentLink {
  Future<void> get done;
  Future<void> close();
}

typedef Connector = Future<AgentLink> Function(Endpoint ep, Duration timeout);
typedef Sleeper = Future<void> Function(Duration d);

sealed class LoopState {
  const LoopState();
}

class Connecting extends LoopState {
  const Connecting(this.attempt);
  final int attempt;
}

class Connected extends LoopState {
  const Connected(this.endpoint);
  final Endpoint endpoint;
}

class Waiting extends LoopState {
  const Waiting(this.retryIn, this.attempt);
  final Duration retryIn;
  final int attempt;
}

class Stopped extends LoopState {
  const Stopped(this.reason);
  final FailKind reason;
}

/// Ordered candidates: USB first (cheap: refused instantly with no cable), then the
/// addresses the agent reported on the last connection (freshest truth), the last host
/// that worked over Wi-Fi, mDNS results, QR hosts, manual IP. De-duplicated.
List<Endpoint> orderCandidates({
  required int port,
  List<String> knownHosts = const [],
  String? lastHost,
  List<String> qrHosts = const [],
  List<String> mdnsHosts = const [],
  String? manualHost,
}) {
  final out = <Endpoint>[Endpoint('127.0.0.1', port, Transport.usb, 'usb')];
  void add(String? h, String src) {
    if (h == null || h.isEmpty) return;
    final ep = Endpoint(h, port, Transport.wifi, src);
    if (!out.contains(ep)) out.add(ep);
  }

  for (final h in knownHosts) {
    add(h, 'agent');
  }
  add(lastHost, 'last');
  for (final h in mdnsHosts) {
    add(h, 'mdns');
  }
  for (final h in qrHosts) {
    add(h, 'qr');
  }
  add(manualHost, 'manual');
  return out;
}

/// 1s, 2s, 4s, 8s, 15s, 15s... (+ up to 20% jitter when [rng] is given).
Duration backoff(int attempt, {Random? rng}) {
  final base = min(15000, 1000 * pow(2, min(attempt, 10)).toInt());
  final jitter = rng == null ? 0 : (base * 0.2 * rng.nextDouble()).round();
  return Duration(milliseconds: base + jitter);
}

class ConnectionLoop {
  ConnectionLoop({
    required this.connect,
    required this.candidates,
    required this.onState,
    required this.onLink,
    Sleeper? sleep,
    this.usbProbeEvery = const Duration(seconds: 5),
    this.usbTimeout = const Duration(milliseconds: 1500),
    this.wifiTimeout = const Duration(seconds: 4),
    Random? rng,
  })  : _sleep = sleep ?? ((d) => Future.delayed(d)),
        _rng = rng; // ignore: prefer_initializing_formals

  final Connector connect;
  final List<Endpoint> Function() candidates;
  final void Function(LoopState) onState;

  /// Called with each new active link. The previous link (if any) is closed right
  /// after, so the consumer should switch over immediately (make-before-break).
  final void Function(AgentLink link, Endpoint ep) onLink;
  final Duration usbProbeEvery, usbTimeout, wifiTimeout;
  final Sleeper _sleep;
  final Random? _rng;

  bool _stopped = false;
  Completer<void>? _kick;
  AgentLink? _current;

  void stop() {
    _stopped = true;
    kick();
    _current?.close();
  }

  /// Skip the remaining backoff (e.g. app resumed, network changed, user tapped retry).
  void kick() {
    if (_kick != null && !_kick!.isCompleted) _kick!.complete();
  }

  Future<void> _wait(Duration d) {
    _kick = Completer<void>();
    return Future.any([_sleep(d), _kick!.future]);
  }

  Future<void> run() async {
    var attempt = 0;
    while (!_stopped) {
      onState(Connecting(attempt));
      AgentLink? link;
      Endpoint? ep;
      for (final c in candidates()) {
        if (_stopped) return;
        try {
          link = await connect(c, c.transport == Transport.usb ? usbTimeout : wifiTimeout);
          ep = c;
          break;
        } on ConnectFailure catch (e) {
          if (e.kind != FailKind.unreachable) {
            _stopped = true;
            onState(Stopped(e.kind));
            return;
          }
        }
      }
      if (_stopped) {
        await link?.close();
        return;
      }
      if (link == null || ep == null) {
        final d = backoff(attempt, rng: _rng);
        onState(Waiting(d, attempt));
        attempt++;
        await _wait(d);
        continue;
      }
      attempt = 0;
      await _hold(link, ep);
    }
  }

  /// Stay on [link] until it drops. While on Wi-Fi, probe USB and switch when it appears.
  Future<void> _hold(AgentLink link, Endpoint ep) async {
    _current = link;
    onLink(link, ep);
    onState(Connected(ep));
    while (!_stopped) {
      if (ep.transport == Transport.usb) {
        await link.done;
        return;
      }
      final dropped = await Future.any([
        link.done.then((_) => true),
        _sleep(usbProbeEvery).then((_) => false),
      ]);
      if (dropped || _stopped) return;
      final usb = candidates().firstWhere((c) => c.transport == Transport.usb,
          orElse: () => const Endpoint('', 0, Transport.usb, 'none'));
      if (usb.host.isEmpty) continue;
      try {
        final u = await connect(usb, usbTimeout);
        final old = link;
        link = u;
        ep = usb;
        _current = u;
        onLink(u, usb);
        onState(Connected(usb));
        await old.close();
      } on ConnectFailure {
        // no cable; keep Wi-Fi
      }
    }
  }
}
