import 'dart:io';

import 'package:cyber_hal/debug/ssh.dart';
import 'package:cyber_hal/src/core/errors.dart';
import 'package:cyber_hal/src/linux/lws_trace.dart';

/// Linux on-demand LAN/WLAN SSH.
///
/// No portable default helper — inject [enableHelper] from BoardProfile or
/// [setEnabled]/[isEnabled] throw [HalUnsupportedException].
class LinuxSshDebugController implements SshDebug {
  LinuxSshDebugController({
    this.enableHelper = const <String>[],
  });

  final List<String> enableHelper;

  void _requireHelper() {
    if (enableHelper.isEmpty) {
      throw const HalUnsupportedException(
        'SSH debug requires board helper injection (no portable default)',
      );
    }
  }

  Future<ProcessResult> _run(List<String> cmd) {
    return Process.run(cmd.first, cmd.sublist(1));
  }

  @override
  Future<bool> isEnabled() async {
    _requireHelper();
    final r = await _run([...enableHelper, 'status']);
    final out = '${r.stdout}'.trim().toLowerCase();
    final on = r.exitCode == 0 || out.contains('enabled');
    lwsTrace('ssh-debug: status exit=${r.exitCode} out=$out → $on');
    return on;
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    _requireHelper();
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
