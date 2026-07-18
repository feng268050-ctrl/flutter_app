import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:cyber_hal/src/linux/lws_trace.dart';

/// Periodically refreshes BlueZ `org.bluez.Battery1` Percentage for HID keyboards.
///
/// Some stacks only update battery while polled; this keeps Demo / UI values fresh
/// without a separate daemon.
class KeyboardBatteryKeepalive {
  KeyboardBatteryKeepalive({
    this.interval = const Duration(seconds: 60),
    Future<int?> Function(String deviceObjectPath)? readPercent,
  }) : _readPercent = readPercent ?? readBluezBatteryPercent;

  final Duration interval;
  final Future<int?> Function(String deviceObjectPath) _readPercent;

  Timer? _timer;

  bool get isActive => _timer != null;

  /// Start periodic [onTick]. Idempotent.
  void start(Future<void> Function() onTick) {
    stop();
    _timer = Timer.periodic(interval, (_) {
      unawaited(onTick());
    });
    unawaited(onTick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Read Percentage for one BlueZ device object path (`/org/bluez/hci0/dev_…`).
  Future<int?> readPercent(String deviceObjectPath) =>
      _readPercent(deviceObjectPath);
}

/// D-Bus Get of `org.bluez.Battery1.Percentage` (byte 0–100).
Future<int?> readBluezBatteryPercent(String deviceObjectPath) async {
  if (deviceObjectPath.isEmpty) {
    return null;
  }
  final bus = DBusClient.system();
  try {
    final obj = DBusRemoteObject(
      bus,
      name: 'org.bluez',
      path: DBusObjectPath(deviceObjectPath),
    );
    final prop = await obj.getProperty(
      'org.bluez.Battery1',
      'Percentage',
      signature: DBusSignature('y'),
    );
    if (prop is DBusByte) {
      return prop.value;
    }
    return null;
  } catch (e) {
    lwsTrace('bt-battery: $deviceObjectPath → $e');
    return null;
  } finally {
    try {
      await bus.close();
    } catch (_) {}
  }
}

/// Test helper: no-op reader that never hits D-Bus.
@visibleForTesting
Future<int?> noopBatteryPercent(String _) async => null;
