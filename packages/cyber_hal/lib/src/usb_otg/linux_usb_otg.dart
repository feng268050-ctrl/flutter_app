import 'dart:async';
import 'dart:io';

import 'package:cyber_hal/src/core/errors.dart';
import 'package:cyber_hal/src/linux/key_value_conf.dart';
import 'package:cyber_hal/src/linux/lws_trace.dart';
import 'package:cyber_hal/usb_otg/usb_otg.dart';

/// Linux USB OTG via board helper + persisted conf + `/etc/usb-otg.ini`.
///
/// Mode switch only — no cable attach/detach observation.
class LinuxUsbOtg implements UsbOtg {
  LinuxUsbOtg({
    this.helper = const <String>[],
    this.confPath = '/var/lib/hal/usb-otg.conf',
    this.iniPath = '/etc/usb-otg.ini',
  });

  final List<String> helper;
  final String confPath;
  final String iniPath;

  final _updatesCtrl = StreamController<void>.broadcast();

  void _requireHelper() {
    if (helper.isEmpty) {
      throw const HalUnsupportedException(
        'USB OTG requires board helper injection (usb_otg_mode)',
      );
    }
  }

  void _notify() {
    if (!_updatesCtrl.isClosed) {
      _updatesCtrl.add(null);
    }
  }

  Future<ProcessResult> _run(List<String> args) {
    return Process.run(helper.first, [...helper.skip(1), ...args]);
  }

  @override
  Future<UsbOtgMode> getMode() async {
    try {
      final map = await readKeyValueConfFile(confPath);
      return UsbOtgMode.tryParse(map['mode'] ?? '') ?? UsbOtgMode.debug;
    } catch (_) {
      return UsbOtgMode.debug;
    }
  }

  @override
  Future<void> setMode(UsbOtgMode mode) async {
    _requireHelper();
    final r = await _run([mode.confValue]);
    if (r.exitCode != 0) {
      final err = '${r.stderr}'.trim();
      final out = '${r.stdout}'.trim();
      throw StateError(
        'usb-otg setMode(${mode.confValue}) failed (exit ${r.exitCode}): '
        '${err.isNotEmpty ? err : out}',
      );
    }
    lwsTrace('usb-otg: setMode ${mode.confValue} ok');
    _notify();
  }

  @override
  Future<void> apply() async {
    _requireHelper();
    final r = await _run(const ['apply']);
    if (r.exitCode != 0) {
      final err = '${r.stderr}'.trim();
      final out = '${r.stdout}'.trim();
      throw StateError(
        'usb-otg apply failed (exit ${r.exitCode}): '
        '${err.isNotEmpty ? err : out}',
      );
    }
    _notify();
  }

  @override
  Future<UsbOtgSupport> getSupport() async {
    final map = await readKeyValueConfFile(iniPath);
    return UsbOtgSupport.fromIniMap(map);
  }

  @override
  Future<List<UsbOtgMode>> pickerModes() async {
    final s = await getSupport();
    if (s.debugOnly) {
      return const [UsbOtgMode.debug];
    }
    if (s.autoHostSupport) {
      return const [UsbOtgMode.debug, UsbOtgMode.mtp];
    }
    return const [UsbOtgMode.debug, UsbOtgMode.mtp, UsbOtgMode.host];
  }

  @override
  Stream<void> get updates => _updatesCtrl.stream;

  Future<void> dispose() async {
    await _updatesCtrl.close();
  }
}
