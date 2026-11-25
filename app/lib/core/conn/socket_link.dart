import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'loop.dart';
import 'pairing.dart';

const protoVersion = 1;

class Welcome {
  Welcome(Map<String, dynamic> j)
      : agentId = j['agent_id'] as String,
        host = j['host'] as String,
        os = j['os'] as String,
        agentVersion = j['agent_version'] as String,
        serverTime = DateTime.fromMillisecondsSinceEpoch(j['server_time'] as int),
        topics = (j['topics'] as List).cast<String>(),
        hosts = ((j['hosts'] as List?) ?? const []).cast<String>(),
        actions = (j['actions'] as List).cast<String>();
  final String agentId, host, os, agentVersion;
  final DateTime serverTime;
  final List<String> topics, actions;

  /// The agent's current LAN IPv4 addresses (newer agents only).
  final List<String> hosts;
}

/// An authenticated WebSocket to the agent with app-level heartbeat.
class SocketLink implements AgentLink {
  SocketLink._(this._ws, this._sub, this.welcome, this.clockSkewMs) {
    _sub
      ..onData(_onData)
      ..onDone(_finish)
      ..onError((_) => _finish());
    _hb = Timer.periodic(const Duration(seconds: 5), (_) {
      if (DateTime.now().difference(_lastIn) > const Duration(seconds: 10)) {
        close(); // yanked cable / dead Wi-Fi: no TCP close ever arrives
        return;
      }
      send({'t': 'ping', 'ts': DateTime.now().millisecondsSinceEpoch});
    });
  }

  final WebSocket _ws;
  final Welcome welcome;

  /// agent clock − phone clock, for interpolating media position etc.
  final int clockSkewMs;
  final StreamSubscription _sub;
  late final Timer _hb;
  DateTime _lastIn = DateTime.now();
  final _frames = StreamController<Map<String, dynamic>>.broadcast();
  final _done = Completer<void>();

  Stream<Map<String, dynamic>> get frames => _frames.stream;
  @override
  Future<void> get done => _done.future;
  bool get isOpen => !_done.isCompleted;

  void send(Map<String, dynamic> frame) {
    if (isOpen) _ws.add(jsonEncode(frame));
  }

  void _onData(dynamic data) {
    _lastIn = DateTime.now();
    if (data is! String) return;
    try {
      final m = jsonDecode(data) as Map<String, dynamic>;
      if (m['t'] == 'ping') {
        send({'t': 'pong', 'ts': m['ts']});
        return;
      }
      _frames.add(m);
    } catch (_) {}
  }

  void _finish() {
    if (_done.isCompleted) return;
    _hb.cancel();
    _frames.close();
    _done.complete();
  }

  @override
  Future<void> close() async {
    _hb.cancel();
    try {
      await _ws.close(1000).timeout(const Duration(seconds: 1));
    } catch (_) {}
    await _sub.cancel();
    _finish();
  }

  static Future<SocketLink> connect(
    Endpoint ep,
    Pairing pairing, {
    required Duration timeout,
    required String clientName,
    String appVersion = '0.1.0',
  }) async {
    final scheme = pairing.tls ? 'wss' : 'ws';
    final client = HttpClient(context: SecurityContext(withTrustedRoots: false))
      ..connectionTimeout = timeout
      // Pin the exact certificate from the QR code; no CA is trusted.
      ..badCertificateCallback = (cert, host, port) =>
          pairing.fingerprint != null && sha256.convert(cert.der).toString() == pairing.fingerprint;
    final WebSocket ws;
    try {
      ws = await WebSocket.connect('$scheme://${ep.host}:${ep.port}/ws', customClient: client)
          .timeout(timeout);
    } catch (e) {
      client.close(force: true);
      throw ConnectFailure(FailKind.unreachable, '$e');
    }

    final first = Completer<Map<String, dynamic>>();
    final tmp = ws.listen((d) {
      if (!first.isCompleted && d is String) {
        try {
          first.complete(jsonDecode(d) as Map<String, dynamic>);
        } catch (e) {
          first.completeError(e);
        }
      }
    }, onDone: () {
      if (!first.isCompleted) first.completeError(StateError('closed ${ws.closeCode}'));
    });
    ws.add(jsonEncode({
      't': 'hello',
      'proto': protoVersion,
      'token': pairing.token,
      'client': {'name': clientName, 'platform': Platform.operatingSystem, 'app_version': appVersion},
    }));
    final sent = DateTime.now();
    Map<String, dynamic> reply;
    try {
      reply = await first.future.timeout(timeout);
    } catch (e) {
      await tmp.cancel();
      await ws.close();
      final code = ws.closeCode;
      if (code == 4401) throw ConnectFailure(FailKind.auth, 'token rejected');
      if (code == 4426) throw ConnectFailure(FailKind.proto, 'protocol mismatch');
      throw ConnectFailure(FailKind.unreachable, '$e');
    }
    // Error frames arrive before the close; classify from the payload.
    if (reply['t'] == 'error') {
      await tmp.cancel();
      await ws.close();
      final kind = switch (reply['code']) {
        'auth_failed' => FailKind.auth,
        'proto_unsupported' => FailKind.proto,
        _ => FailKind.unreachable,
      };
      throw ConnectFailure(kind, '${reply['code']}');
    }
    if (reply['t'] != 'welcome') {
      await tmp.cancel();
      await ws.close();
      throw ConnectFailure(FailKind.unreachable, 'unexpected ${reply['t']}');
    }
    final w = Welcome(reply);
    if (w.agentId != pairing.agentId) {
      await tmp.cancel();
      await ws.close();
      throw ConnectFailure(FailKind.unreachable, 'different agent ${w.agentId}');
    }
    final rtt = DateTime.now().difference(sent).inMilliseconds;
    final skew = w.serverTime.millisecondsSinceEpoch - (sent.millisecondsSinceEpoch + rtt ~/ 2);
    return SocketLink._(ws, tmp, w, skew);
  }
}
