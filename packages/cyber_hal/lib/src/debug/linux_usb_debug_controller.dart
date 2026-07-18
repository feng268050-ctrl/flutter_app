import 'dart:io';

import 'package:lws_hmi/platform/lws_trace.dart';
import 'package:lws_hmi/platform/usb/usb_debug_controller.dart';

/// Linux USB Debug via `/usr/libexec/hmi/usb-otg-mode.sh` (persisted preference).
class LinuxUsbDebugController implements UsbDebugController {
  LinuxUsbDebugController({
    this.helper = const ['/usr/libexec/hmi/usb-otg-mode.sh'],
  });

  final List<String> helper;

  Future<ProcessResult> _run(List<String> cmd) {
    return Process.run(cmd.first, cmd.sublist(1));
  }

  @override
  Future<bool> isEnabled() async {
    final r = await _run([...helper, 'status']);
    final out = '${r.stdout}'.trim().toLowerCase();
    // status exits 0 when usb-debug=on (pref), even if plug-ssh inactive.
    final on = out.contains('usb-debug=on') || r.exitCode == 0;
    lwsTrace('usb-debug: status exit=${r.exitCode} out=$out → $on');
    return on;
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    final arg = enabled ? 'debug' : 'host';
    final r = await _run([...helper, arg]);
    if (r.exitCode != 0) {
      final err = '${r.stderr}'.trim();
      final out = '${r.stdout}'.trim();
      throw StateError(
        'usb-debug $arg failed (exit ${r.exitCode}): '
        '${err.isNotEmpty ? err : out}',
      );
    }
    lwsTrace('usb-debug: $arg ok');
  }
}
