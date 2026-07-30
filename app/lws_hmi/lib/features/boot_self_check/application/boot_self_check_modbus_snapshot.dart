import 'dart:async';

import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_evaluator.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_live_cache_seed.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';

/// Bounded one-shot Modbus group reads for boot self-check.
///
/// Reads continuous `status` + `data` groups (two RTU frames) instead of
/// per-attribute polls, then projects [BootSelfCheckModbusIds] for evaluation.
/// Successful group maps are offered to [BootSelfCheckLiveCacheSeed] so the
/// cloud live cache can skip an immediate re-seed on the same bus.
abstract final class BootSelfCheckModbusSnapshotReader {
  static const defaultTimeout = Duration(seconds: 3);

  /// Soft-fails to [modbusAvailable]=false when neither group yields values.
  static Future<BootSelfCheckModbusSnapshot> read(
    ModbusRtuClient modbus, {
    Duration timeout = defaultTimeout,
  }) async {
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

    Map<String, Object?> status = const {};
    Map<String, Object?> data = const {};
    try {
      status = await modbus.readGroup('status').timeout(timeout);
    } on TimeoutException {
      status = const {};
    } catch (_) {
      status = const {};
    }
    try {
      data = await modbus.readGroup('data').timeout(timeout);
    } on TimeoutException {
      data = const {};
    } catch (_) {
      data = const {};
    }

    final values = <String, Object?>{};
    for (final id in BootSelfCheckModbusIds.all) {
      if (status.containsKey(id)) {
        values[id] = status[id];
      } else if (data.containsKey(id)) {
        values[id] = data[id];
      } else {
        values[id] = null;
      }
    }

    final anyOk = values.values.any((v) => v != null);
    final ready = BootSelfCheckModbusSnapshot.isControllerReady(
      values[BootSelfCheckModbusIds.deviceType],
    );

    if (status.isNotEmpty || data.isNotEmpty) {
      BootSelfCheckLiveCacheSeed.offer(
        status: status.isEmpty ? null : status,
        data: data.isEmpty ? null : data,
      );
    }

    return BootSelfCheckModbusSnapshot(
      values: values,
      modbusAvailable: anyOk,
      controllerReady: ready,
    );
  }
}
