import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/demo.dart';
import '../data/topics.dart';
import '../pages.dart';
import '../remote_pointer.dart';
import '../settings.dart';
import 'discovery.dart';
import 'loop.dart';
import 'pairing.dart';
import 'socket_link.dart';

/// Why the laptop couldn't take the mouse-sharing setting (e.g. no Accessibility
/// permission), shown under the setting; null when fine.
final mouseError = ValueNotifier<String?>(null);

enum LinkStatus { loading, unpaired, connecting, connected, offline, authFailed, protoMismatch, demo }

class ConnState {
  const ConnState(this.status,
      {this.transport, this.host, this.agentName, this.retryIn, this.lastConnected, this.pairing});
  final LinkStatus status;
  final Transport? transport;
  final String? host, agentName;
  final Duration? retryIn;
  final DateTime? lastConnected;
  final Pairing? pairing;

  bool get live => status == LinkStatus.connected || status == LinkStatus.demo;

  ConnState copy(LinkStatus s, {Transport? transport, String? host, Duration? retryIn}) =>
      ConnState(s,
          transport: transport,
          host: host,
          agentName: agentName,
          retryIn: retryIn,
          lastConnected: s == LinkStatus.connected ? DateTime.now() : lastConnected,
          pairing: pairing);
}

class ActionResult {
  const ActionResult(this.ok, {this.result = const {}, this.code, this.message});
  final bool ok;
  final Map<String, dynamic> result;
  final String? code, message;
}

class AgentController extends Notifier<ConnState> with WidgetsBindingObserver {
  final _store = PairingStore();
  final _discovery = AgentDiscovery();
  ConnectionLoop? _loop;
  SocketLink? _link;
  StreamSubscription? _frames;
  Set<String> _topics = topicsFor(PageId.home);
  final _pending = <String, Completer<ActionResult>>{};
  final _progress = <String, void Function(Map<String, dynamic>)>{};
  int _reqSeq = 0;
  String? _lastHost, _manualHost;
  List<String> _knownHosts = const [];
  DemoSource? _demo;
  int clockSkewMs = 0;

  @override
  ConnState build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _teardown();
    });
    ref.listen(settingsProvider.select((s) => s.demo), (_, demo) => _start());
    ref.listen(settingsProvider.select((s) => (s.mouseOn, s.mouseRect)), (_, _) => _mouseSetup());
    Future.microtask(_start);
    return const ConnState(LinkStatus.loading);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loop?.kick();
      _mouseSetup();
    }
    if (state == AppLifecycleState.paused) {
      ref.read(topicStoreProvider.notifier).flush();
      _mouseSetup(off: true); // don't send the laptop's mouse to a screen nobody can see
    }
  }

  Future<void> _teardown() async {
    _loop?.stop();
    _loop = null;
    await _frames?.cancel();
    await _link?.close();
    _link = null;
    _demo?.stop();
    _demo = null;
    await _discovery.stop();
    for (final c in _pending.values) {
      if (!c.isCompleted) c.complete(const ActionResult(false, code: 'disconnected'));
    }
    _pending.clear();
  }

  Future<void> _start() async {
    await _teardown();
    if (ref.read(settingsProvider).demo) {
      _demo = DemoSource(ref.read(topicStoreProvider.notifier))..start();
      state = const ConnState(LinkStatus.demo, agentName: 'Demo laptop');
      return;
    }
    var loaded = await _store.load();
    // Debug builds only: `flutter run --dart-define=DESKPANEL_PAIR='deskpanel://pair?...'`
    // pairs without scanning (for development). Ignored in release builds.
    const devPair = String.fromEnvironment('DESKPANEL_PAIR');
    if (loaded == null && kDebugMode && devPair.isNotEmpty) {
      loaded = Pairing.parse(devPair);
      if (loaded != null) await _store.save(loaded);
    }
    if (loaded == null) {
      state = const ConnState(LinkStatus.unpaired);
      return;
    }
    final p = loaded;
    _lastHost = await _store.lastHost();
    _manualHost = await _store.manualHost();
    _knownHosts = await _store.knownHosts();
    state = ConnState(LinkStatus.connecting, agentName: p.name, pairing: p);
    unawaited(_discovery.start(p.agentId));
    _discovery.onChange = () {
      if (state.status == LinkStatus.offline) _loop?.kick();
    };

    final loop = ConnectionLoop(
      connect: (ep, timeout) => SocketLink.connect(ep, p, timeout: timeout, clientName: 'DeskPanel'),
      candidates: () => orderCandidates(
        port: p.port,
        knownHosts: _knownHosts,
        lastHost: _lastHost,
        qrHosts: p.hosts,
        mdnsHosts: _discovery.hosts,
        manualHost: _manualHost,
      ),
      onState: (s) {
        switch (s) {
          case Connecting():
            state = state.copy(LinkStatus.connecting);
          case Waiting(:final retryIn):
            state = state.copy(LinkStatus.offline, retryIn: retryIn);
          case Stopped(:final reason):
            state = state.copy(
                reason == FailKind.auth ? LinkStatus.authFailed : LinkStatus.protoMismatch);
          case Connected(:final endpoint):
            state = state.copy(LinkStatus.connected,
                transport: endpoint.transport, host: endpoint.host);
        }
      },
      onLink: (link, ep) => _adopt(link as SocketLink, ep),
    );
    _loop = loop;
    unawaited(loop.run());
  }

  void _adopt(SocketLink link, Endpoint ep) {
    _frames?.cancel();
    _link = link;
    clockSkewMs = link.clockSkewMs;
    final hosts = link.welcome.hosts;
    if (hosts.isNotEmpty && hosts.join(',') != _knownHosts.join(',')) {
      _knownHosts = hosts;
      _store.setKnownHosts(hosts);
      debugPrint('DeskPanel: laptop LAN addresses now ${hosts.join(', ')}');
    }
    if (ep.transport == Transport.wifi && ep.host != _lastHost) {
      _lastHost = ep.host;
      _store.setLastHost(ep.host);
    }
    final store = ref.read(topicStoreProvider.notifier);
    _frames = link.frames.listen((m) {
      switch (m['t']) {
        case 'evt':
          final d = m['data'];
          if (d is Map<String, dynamic>) store.ingest(m['topic'] as String, d);
        case 'res':
          final c = _pending.remove(m['id']);
          _progress.remove(m['id']);
          final err = m['error'] as Map<String, dynamic>?;
          c?.complete(ActionResult(m['ok'] == true,
              result: (m['result'] as Map<String, dynamic>?) ?? const {},
              code: err?['code'] as String?,
              message: err?['message'] as String?));
        case 'prog':
          _progress[m['id']]?.call((m['data'] as Map<String, dynamic>?) ?? const {});
        case 'ptr':
          remotePointer.add(m);
      }
    });
    link.send({'t': 'sub', 'topics': _topics.toList()});
    _mouseSetup();
    link.done.then((_) {
      if (_link != link) return;
      for (final c in _pending.values) {
        if (!c.isCompleted) c.complete(const ActionResult(false, code: 'disconnected'));
      }
      _pending.clear();
    });
  }

  /// Tells the laptop where the phone sits next to its screen(s) (and the phone screen size), so its mouse can
  /// move over. Sent on connect, on resume and when the setting changes.
  Future<void> _mouseSetup({bool off = false}) async {
    final link = _link;
    if (link == null || !link.isOpen || _demo != null) return;
    final s = ref.read(settingsProvider);
    final rect = s.mouseRect;
    final on = !off && s.mouseOn && rect != null;
    final size = phoneScreenSize();
    if (size == null) return;
    final r = await request('mouse.setup', {
      'on': on,
      if (on) 'rect': rect.toJson(),
      'w': size.width.round(),
      'h': size.height.round(),
    });
    mouseError.value = r.ok || r.code == 'unsupported' || r.code == 'disconnected' ? null : r.message;
  }

  /// Called by the shell whenever the visible page changes.
  void setPage(PageId page) {
    final t = topicsFor(page);
    if (t.length == _topics.length && t.containsAll(_topics)) return;
    _topics = t;
    _link?.send({'t': 'sub', 'topics': _topics.toList()});
  }

  Future<ActionResult> request(String action,
      [Map<String, dynamic> params = const {},
      void Function(Map<String, dynamic>)? onProgress,
      Duration timeout = const Duration(seconds: 10)]) {
    if (_demo != null) return _demo!.request(action, params, onProgress);
    final link = _link;
    if (link == null || !link.isOpen) {
      return Future.value(const ActionResult(false, code: 'disconnected', message: 'Laptop not connected'));
    }
    final id = 'r${++_reqSeq}';
    final c = Completer<ActionResult>();
    _pending[id] = c;
    if (onProgress != null) _progress[id] = onProgress;
    link.send({'t': 'req', 'id': id, 'action': action, 'params': params});
    return c.future.timeout(timeout, onTimeout: () {
      _pending.remove(id);
      _progress.remove(id);
      return const ActionResult(false, code: 'timeout', message: 'The laptop did not answer');
    });
  }

  Future<void> pair(Pairing p) async {
    await _store.clear();
    await _store.save(p);
    if (ref.read(settingsProvider).demo) {
      ref.read(settingsProvider.notifier).update((s) => s.copyWith(demo: false));
    } else {
      await _start();
    }
  }

  Future<void> unpair() async {
    await _store.clear();
    await _start();
  }

  Future<void> setManualHost(String? host) async {
    _manualHost = host;
    await _store.setManualHost(host);
    _loop?.kick();
  }

  void retryNow() => _loop?.kick();
}

final agentProvider = NotifierProvider<AgentController, ConnState>(AgentController.new);

/// The phone's whole screen in logical pixels (not the scaled design canvas).
Size? phoneScreenSize() {
  final views = WidgetsBinding.instance.platformDispatcher.views;
  if (views.isEmpty) return null;
  final v = views.first;
  return v.physicalSize / v.devicePixelRatio;
}
