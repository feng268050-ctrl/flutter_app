import 'dart:async';

import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_evaluator.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';

/// Bounded one-shot Modbus attribute reads for boot self-check.
abstract final class BootSelfCheckModbusSnapshotReader {
  static const defaultTimeout = Duration(seconds: 3);

  /// Reads [BootSelfCheckModbusIds.all]; soft-fails to [modbusAvailable]=false.
  static Future<BootSelfCheckModbusSnapshot> read(
    ModbusRtuClient modbus, {
    Duration timeout = defaultTimeout,
  }) async {
    final values = <String, Object?>{};
    var anyOk = false;

    try {
      final opened = await modbus.open();
      if (!opened) {
        return const BootSelfCheckModbusSnapshot(
          values: {},
          modbusAvailable: false,
          controllerReady: false,
        );
      }
    } catch (_) {
      return const BootSelfCheckModbusSnapshot(
        values: {},
        modbusAvailable: false,
        controllerReady: false,
      );
    }

    for (final id in BootSelfCheckModbusIds.all) {
      try {
        final v = await modbus.readAttribute(id).timeout(timeout);
        values[id] = v;
        if (v != null) {
          anyOk = true;
        }
      } on TimeoutException {
        values[id] = null;
      } catch (_) {
        values[id] = null;
      }
    }

    final ready = BootSelfCheckModbusSnapshot.isControllerReady(
      values[BootSelfCheckModbusIds.deviceType],
    );
    return BootSelfCheckModbusSnapshot(
      values: values,
      modbusAvailable: anyOk,
      controllerReady: ready,
    );
  }
}
