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

  /// How long to keep retrying while the bus / controller is not ready.
  ///
  /// Control-board RTU often comes up a few seconds after HMI Home; a single
  /// early read would mark every item Fault and (with warn gated) show no alarm.
  static const defaultReadyBudget = Duration(seconds: 5);

  static const defaultRetryInterval = Duration(milliseconds: 400);

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

  /// Retries [read] until [BootSelfCheckModbusSnapshot.isUsable] or the budget
  /// elapses / [shouldCancel] returns true.
  ///
  /// Returns the last snapshot (usable or not). Does not treat a ready
  /// controller with real alarm bits as "not ready" — those evaluate as fail.
  static Future<BootSelfCheckModbusSnapshot> readUntilReady(
    ModbusRtuClient modbus, {
    Duration timeout = defaultTimeout,
    Duration readyBudget = defaultReadyBudget,
    Duration retryInterval = defaultRetryInterval,
    bool Function()? shouldCancel,
  }) async {
    final deadline = DateTime.now().add(readyBudget);
    BootSelfCheckModbusSnapshot snapshot = const BootSelfCheckModbusSnapshot(
      values: {},
      modbusAvailable: false,
      controllerReady: false,
    );

    while (true) {
      if (shouldCancel?.call() == true) {
        return snapshot;
      }

      snapshot = await read(modbus, timeout: timeout);
      if (snapshot.isUsable) {
        return snapshot;
      }

      if (shouldCancel?.call() == true) {
        return snapshot;
      }
      if (!DateTime.now().isBefore(deadline)) {
        return snapshot;
      }
      await Future<void>.delayed(retryInterval);
    }
  }
}
