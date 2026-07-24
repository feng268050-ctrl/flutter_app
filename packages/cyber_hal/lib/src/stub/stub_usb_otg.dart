import 'dart:async';

import 'package:cyber_hal/usb_otg/usb_otg.dart';

/// In-memory [UsbOtg] for host tests / stub backend.
class StubUsbOtg implements UsbOtg {
  StubUsbOtg({
    this.mode = UsbOtgMode.debug,
    this.support = const UsbOtgSupport(),
  });

  UsbOtgMode mode;
  UsbOtgSupport support;

  final _updatesCtrl = StreamController<void>.broadcast();

  void _notify() {
    if (!_updatesCtrl.isClosed) {
      _updatesCtrl.add(null);
    }
  }

  @override
  Future<UsbOtgMode> getMode() async => mode;

  @override
  Future<void> setMode(UsbOtgMode mode) async {
    this.mode = mode;
    _notify();
  }

  @override
  Future<void> apply() async {
    if (support.debugOnly) {
      mode = UsbOtgMode.debug;
    }
    _notify();
  }

  @override
  Future<UsbOtgSupport> getSupport() async => support;

  @override
  Future<List<UsbOtgMode>> pickerModes() async {
    if (support.debugOnly) {
      return const [UsbOtgMode.debug];
    }
    if (support.autoHostSupport) {
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
