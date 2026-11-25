import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// What the phone learns from the agent's QR code.
class Pairing {
  const Pairing({
    required this.agentId,
    required this.name,
    required this.hosts,
    required this.port,
    required this.token,
    this.fingerprint,
  });

  final String agentId, name, token;
  final List<String> hosts;
  final int port;

  /// SHA-256 of the agent's TLS cert (hex). Null = plain ws:// (debug agents only).
  final String? fingerprint;

  bool get tls => fingerprint != null;

  /// Parses `deskpanel://pair?v=1&id=..&n=..&h=ip1,ip2&p=8765&t=..&fp=..`.
  static Pairing? parse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.scheme != 'deskpanel' || uri.host != 'pair') return null;
    final q = uri.queryParameters;
    final id = q['id'], t = q['t'], p = int.tryParse(q['p'] ?? '');
    if (id == null || id.isEmpty || t == null || t.length < 20 || p == null) return null;
    final fp = q['fp'];
    if (fp != null && !RegExp(r'^[0-9a-f]{64}$').hasMatch(fp)) return null;
    return Pairing(
      agentId: id,
      name: q['n'] ?? 'Laptop',
      hosts: (q['h'] ?? '').split(',').where((h) => h.isNotEmpty).toList(),
      port: p,
      token: t,
      fingerprint: fp,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': agentId,
        'n': name,
        'h': hosts,
        'p': port,
        't': token,
        'fp': fingerprint,
      };

  static Pairing fromJson(Map<String, dynamic> j) => Pairing(
        agentId: j['id'] as String,
        name: j['n'] as String,
        hosts: (j['h'] as List).cast<String>(),
        port: j['p'] as int,
        token: j['t'] as String,
        fingerprint: j['fp'] as String?,
      );
}

/// Token lives in the Android Keystore-backed secure storage, never in prefs.
class PairingStore {
  PairingStore([FlutterSecureStorage? s]) : _s = s ?? const FlutterSecureStorage();
  final FlutterSecureStorage _s;
  static const _key = 'pairing.v1';
  static const _lastHost = 'pairing.lastHost';
  static const _manual = 'pairing.manualHost';
  static const _known = 'pairing.knownHosts';

  Future<Pairing?> load() async {
    final raw = await _s.read(key: _key);
    if (raw == null) return null;
    try {
      return Pairing.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(Pairing p) => _s.write(key: _key, value: jsonEncode(p.toJson()));
  Future<void> clear() async {
    await _s.delete(key: _key);
    await _s.delete(key: _lastHost);
    await _s.delete(key: _known);
  }

  Future<String?> lastHost() => _s.read(key: _lastHost);
  Future<void> setLastHost(String h) => _s.write(key: _lastHost, value: h);
  Future<List<String>> knownHosts() async {
    final raw = await _s.read(key: _known);
    return raw == null || raw.isEmpty ? const [] : raw.split(',');
  }

  Future<void> setKnownHosts(List<String> h) => _s.write(key: _known, value: h.join(','));

  Future<String?> manualHost() => _s.read(key: _manual);
  Future<void> setManualHost(String? h) =>
      h == null || h.isEmpty ? _s.delete(key: _manual) : _s.write(key: _manual, value: h);
}
