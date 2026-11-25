import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/conn/controller.dart';
import '../../core/conn/pairing.dart';
import '../skin.dart';

Route<void> pairRoute() => MaterialPageRoute(builder: (_) => const PairScreen());

class PairScreen extends ConsumerStatefulWidget {
  const PairScreen({super.key});
  @override
  ConsumerState<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends ConsumerState<PairScreen> {
  final _ctrl = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _done = false;
  String? _error;

  Future<void> _onDetect(BarcodeCapture cap) async {
    if (_done) return;
    for (final b in cap.barcodes) {
      final raw = b.rawValue;
      if (raw == null) continue;
      final p = Pairing.parse(raw);
      if (p == null) {
        setState(() => _error = 'That QR code is not a DeskPanel pairing code.');
        continue;
      }
      _done = true;
      await _ctrl.stop();
      await ref.read(agentProvider.notifier).pair(p);
      if (mounted) Navigator.of(context).pop();
      return;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Row(children: [
        Expanded(
          flex: 3,
          child: Stack(fit: StackFit.expand, children: [
            MobileScanner(
              controller: _ctrl,
              onDetect: _onDetect,
              errorBuilder: (context, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Camera unavailable: ${error.errorCode.name}.\n'
                      'Allow camera access for DeskPanel in Android settings.',
                      textAlign: TextAlign.center, style: t.t(14, c: Colors.white)),
                ),
              ),
            ),
            Center(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  border: Border.all(color: t.accent, width: 3),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ]),
        ),
        Expanded(
          flex: 2,
          child: Container(
            color: t.bg,
            padding: const EdgeInsets.all(28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('Pair with laptop', style: t.d(26)),
              const SizedBox(height: 12),
              Text('1. On the laptop, run:', style: t.t(14, c: t.muted)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: t.surface2, borderRadius: BorderRadius.circular(8)),
                child: Text('deskpanel-agent pair', style: t.t(14, w: FontWeight.w600).copyWith(fontFamily: 'monospace')),
              ),
              const SizedBox(height: 10),
              Text('2. Point the camera at the QR code.', style: t.t(14, c: t.muted)),
              const SizedBox(height: 10),
              Text('The code holds a one-time secret and the laptop\'s certificate fingerprint; '
                  'nothing else can connect without it.',
                  style: t.t(12.5, c: t.faint, h: 1.4)),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, style: t.t(13, c: t.bad)),
              ],
              const Spacer(),
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ]),
          ),
        ),
      ]),
    );
  }
}
