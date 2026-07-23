import 'dart:io';

import 'package:cyber_hal/debug/usb.dart';
import 'package:cyber_hal/src/core/errors.dart';
import 'package:cyber_hal/src/linux/lws_trace.dart';

/// Linux USB Debug: optional OTG sysfs (kind A) + optional board helper.
///
/// No ynh960 libexec / PHY defaults — inject [helper] and/or [otgModePath]
/// from BoardProfile. Missing both → [HalUnsupportedException].
class LinuxUsbDebugController implements UsbDebug {
  LinuxUsbDebugController({
    this.helper = const <String>[],
    this.otgModePath = '',
    this.preferencePath = '/var/lib/hal/usb-debug',
  });

  final List<String> helper;
  final String otgModePath;
  final String preferencePath;

  Future<ProcessResult> _run(List<String> cmd) {
    return Process.run(cmd.first, cmd.sublist(1));
  }

  Future<String?> _readOtgMode() async {
    if (otgModePath.isEmpty) {
      return null;
    }
    try {
      final f = File(otgModePath);
      if (!await f.exists()) {
        return null;
      }
      return (await f.readAsString()).trim();
    } catch (_) {
      return null;
    }
  }

  Future<bool> _prefWantsDebug() async {
    try {
      final f = File(preferencePath);
      if (!await f.exists()) {
        return true; // appliance default ON
      }
      final v = (await f.readAsString()).trim().toLowerCase();
      return v != '0' && v != 'off' && v != 'false' && v != 'host';
    } catch (_) {
      return true;
    }
  }

  void _requirePath() {
    if (helper.isEmpty && otgModePath.isEmpty) {
      throw const HalUnsupportedException(
        'USB debug requires board helper or otg_mode_sysfs injection',
      );
    }
  }

  @override
  Future<bool> isEnabled() async {
    _requirePath();
    if (helper.isNotEmpty) {
      final r = await _run([...helper, 'status']);
      final out = '${r.stdout}'.trim().toLowerCase();
      final on = out.contains('usb-debug=on') || r.exitCode == 0;
      lwsTrace('usb-debug: status exit=${r.exitCode} out=$out → $on');
      return on;
    }
    final mode = await _readOtgMode();
    if (mode != null) {
      return mode == 'peripheral';
    }
    return _prefWantsDebug();
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    _requirePath();
    if (helper.isNotEmpty) {
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
      return;
    }
    // Kind-A: write OTG mode + preference only (no plug-ssh orchestration).
    final want = enabled ? 'peripheral' : 'host';
    final f = File(otgModePath);
    if (await f.exists()) {
      await f.writeAsString('$want\n');
    }
    await File(preferencePath).parent.create(recursive: true);
    await File(preferencePath).writeAsString(enabled ? '1\n' : '0\n');
    lwsTrace('usb-debug: sysfs $want (no helper)');
  }
}
