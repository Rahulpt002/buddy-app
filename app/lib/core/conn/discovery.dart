import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nsd/nsd.dart' as nsd;

/// Finds paired agents on the LAN via mDNS (`_deskpanel._tcp`). Keeps a live set of IPv4
/// hosts for the agent id we're paired with.
class AgentDiscovery {
  nsd.Discovery? _d;
  final _hosts = <String, List<String>>{}; // service name -> ips
  String? _agentId;
  void Function()? onChange;

  List<String> get hosts => _hosts.values.expand((e) => e).toSet().toList();

  Future<void> start(String agentId) async {
    if (_d != null && _agentId == agentId) return;
    await stop();
    _agentId = agentId;
    try {
      _d = await nsd.startDiscovery('_deskpanel._tcp',
          ipLookupType: nsd.IpLookupType.v4);
      _d!.addServiceListener((s, status) {
        final txtId = s.txt?['id'];
        final id = txtId == null ? null : utf8.decode(txtId);
        if (id != _agentId || s.name == null) return;
        if (status == nsd.ServiceStatus.found) {
          final ips = (s.addresses ?? const <InternetAddress>[])
              .where((a) => a.type == InternetAddressType.IPv4)
              .map((a) => a.address)
              .toList();
          if (ips.isNotEmpty) _hosts[s.name!] = ips;
          debugPrint('DeskPanel mDNS: found ${s.name} at ${ips.join(', ')}');
        } else {
          _hosts.remove(s.name);
        }
        onChange?.call();
      });
    } catch (_) {
      _d = null; // mDNS unavailable (e.g. no Wi-Fi); USB / last host still work
    }
  }

  Future<void> stop() async {
    final d = _d;
    _d = null;
    _hosts.clear();
    if (d != null) {
      try {
        await nsd.stopDiscovery(d);
      } catch (_) {}
    }
  }
}
