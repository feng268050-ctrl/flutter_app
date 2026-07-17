import 'dart:io';

import 'package:lws_hmi/platform/lws_trace.dart';
import 'package:lws_hmi/platform/ssh/ssh_debug_controller.dart';

/// Linux on-demand LAN/WLAN SSH via `/usr/libexec/hmi/enable-ssh-debug.sh`.
class LinuxSshDebugController implements SshDebugController {
  LinuxSshDebugController({
    this.enableHelper = const ['/usr/libexec/hmi/enable-ssh-debug.sh'],
  });

  final List<String> enableHelper;

  Future<ProcessResult> _run(List<String> cmd) {
    return Process.run(cmd.first, cmd.sublist(1));
  }

  @override
  Future<bool> isEnabled() async {
    final r = await _run([...enableHelper, 'status']);
    final out = '${r.stdout}'.trim().toLowerCase();
    final on = r.exitCode == 0 || out.contains('enabled');
    lwsTrace('ssh-debug: status exit=${r.exitCode} out=$out → $on');
    return on;
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    final arg = enabled ? 'enable' : 'disable';
    final r = await _run([...enableHelper, arg]);
    if (r.exitCode != 0) {
      final err = '${r.stderr}'.trim();
      final out = '${r.stdout}'.trim();
      throw StateError(
        'ssh-debug $arg failed (exit ${r.exitCode}): '
        '${err.isNotEmpty ? err : out}',
      );
    }
    lwsTrace('ssh-debug: $arg ok');
  }
}
