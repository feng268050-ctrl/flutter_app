import 'dart:async';

import 'package:cyber_hal/modbus.dart';
import 'package:flutter/foundation.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_ids.dart';
import 'package:lws_hmi/features/process_mode/domain/laser_enable_preflight.dart';
import 'package:lws_hmi/features/settings/application/laser_alarm_policy.dart';
import 'package:lws_hmi/features/warn_alarm/application/warn_alarm_controller.dart';

/// Live laser, gas, and manual wire-control writes.
final class DeviceControlController extends ChangeNotifier {
  DeviceControlController(this.services);

  final AppServices services;

  bool laserEnable = false;
  bool manualGas = false;
  bool autoWireFeed = true;
  bool wireWork = false;
  bool wireRetracting = false;
  bool wireFeedingOn = false;
  bool laserOn = false;
  bool airValveOn = false;
  bool keySwitchOn = false;
  bool emergencyStop = false;
  double gasPressureKpa = 0;
  bool busy = false;
  String? lastError;

  StreamSubscription<List<ModbusAttributeChange>>? _sub;
  bool _started = false;

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    try {
      await services.ensureModbusLive();
      await _refreshSnapshot();
      final stream = await services.modbus.watchAttributes(
        ids: DeviceControlIds.watchIds,
      );
      _sub = stream.listen(applyChanges);
    } catch (e) {
      debugPrint('device-control: modbus watch failed: $e');
      lastError = 'Status watch failed';
      notifyListeners();
    }
  }

  Future<void> _refreshSnapshot() async {
    try {
      final control = await services.modbus.readGroup('control');
      final status = await services.modbus.readGroup('status');
      laserEnable = _isOn(control[DeviceControlIds.laserEnable]);
      manualGas = _isOn(control[DeviceControlIds.manualGas]);
      // lws-ui calls bit4 `autoWireFeedEnable`, despite the HAL's legacy
      // `wire_manual_mode` identifier. Keep its on-wire behavior for parity.
      autoWireFeed = _isOn(control[DeviceControlIds.wireManualMode]);
      wireWork = _isOn(control[DeviceControlIds.wireWork]);
      wireRetracting = _isOn(control[DeviceControlIds.wireDirection]);
      laserOn = _isOn(status[DeviceControlIds.laserOn]);
      airValveOn = _isOn(status[DeviceControlIds.airValveOn]);
      wireFeedingOn = _isOn(status[DeviceControlIds.wireFeedingOn]);
      keySwitchOn = _isOn(status[DeviceControlIds.keySwitchOn]);
      emergencyStop = _isOn(status[DeviceControlIds.emergencyStop]);
      final data = await services.modbus.readGroup('data');
      gasPressureKpa = _asDouble(data[DeviceControlIds.blowPressure]);
      notifyListeners();
    } catch (e) {
      debugPrint('device-control: snapshot failed: $e');
    }
  }

  static bool _isOn(Object? value) => value == true || value == 1;

  static double _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return 0;
  }

  @visibleForTesting
  void applyChanges(List<ModbusAttributeChange> changes) {
    if (changes.isEmpty) {
      return;
    }
    var changed = false;
    for (final c in changes) {
      final on = c.value == true || c.value == 1;
      switch (c.id) {
        case DeviceControlIds.laserEnable:
          if (laserEnable != on) {
            laserEnable = on;
            changed = true;
          }
        case DeviceControlIds.manualGas:
          if (manualGas != on) {
            manualGas = on;
            changed = true;
          }
        case DeviceControlIds.wireManualMode:
          if (autoWireFeed != on) {
            autoWireFeed = on;
            changed = true;
          }
        case DeviceControlIds.wireWork:
          if (wireWork != on) {
            wireWork = on;
            changed = true;
          }
        case DeviceControlIds.wireDirection:
          if (wireRetracting != on) {
            wireRetracting = on;
            changed = true;
          }
        case DeviceControlIds.laserOn:
          if (laserOn != on) {
            laserOn = on;
            changed = true;
          }
        case DeviceControlIds.airValveOn:
          if (airValveOn != on) {
            airValveOn = on;
            changed = true;
          }
        case DeviceControlIds.wireFeedingOn:
          if (wireFeedingOn != on) {
            wireFeedingOn = on;
            changed = true;
          }
        case DeviceControlIds.keySwitchOn:
          if (keySwitchOn != on) {
            keySwitchOn = on;
            changed = true;
          }
        case DeviceControlIds.emergencyStop:
          if (emergencyStop != on) {
            emergencyStop = on;
            changed = true;
          }
        case DeviceControlIds.blowPressure:
          final next = _asDouble(c.value);
          if (gasPressureKpa != next) {
            gasPressureKpa = next;
            changed = true;
          }
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  /// Returns null on success, otherwise a block reason.
  Future<LaserEnableBlockReason?> setManualGas(bool enabled) async {
    if (busy) {
      return LaserEnableBlockReason.busy;
    }
    busy = true;
    lastError = null;
    notifyListeners();
    try {
      final ok = await services.modbus.exclusiveSession(() async {
        if (!await services.modbus.writeAttribute(
          DeviceControlIds.wireWork,
          false,
        )) {
          return false;
        }
        if (enabled) {
          // Mutual exclusion with laser (lws-ui).
          if (!await services.modbus.writeAttribute(
            DeviceControlIds.laserEnable,
            false,
          )) {
            return false;
          }
        }
        return services.modbus.writeAttribute(
          DeviceControlIds.manualGas,
          enabled,
        );
      });
      if (!ok) {
        lastError = 'Manual gas write failed';
        return LaserEnableBlockReason.writeFailed;
      }
      manualGas = enabled;
      wireWork = false;
      if (enabled) {
        laserEnable = false;
      }
      return null;
    } catch (e) {
      lastError = '$e';
      return LaserEnableBlockReason.writeFailed;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Toggle automatic wire-feed enable, first stopping any manual movement.
  Future<LaserEnableBlockReason?> setAutoWireFeed(bool enabled) async {
    if (busy) {
      return LaserEnableBlockReason.busy;
    }
    busy = true;
    lastError = null;
    notifyListeners();
    try {
      final ok = await services.modbus.exclusiveSession(() async {
        if (!await services.modbus.writeAttribute(
          DeviceControlIds.wireWork,
          false,
        )) {
          return false;
        }
        return services.modbus.writeAttribute(
          DeviceControlIds.wireManualMode,
          enabled,
        );
      });
      if (!ok) {
        lastError = 'Auto wire-feed write failed';
        return LaserEnableBlockReason.writeFailed;
      }
      autoWireFeed = enabled;
      wireWork = false;
      return null;
    } catch (e) {
      lastError = '$e';
      return LaserEnableBlockReason.writeFailed;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Begin a manual feed (forward) or retract (reverse) movement.
  Future<LaserEnableBlockReason?> startWire({required bool retract}) async {
    if (busy) {
      return LaserEnableBlockReason.busy;
    }
    busy = true;
    lastError = null;
    notifyListeners();
    try {
      final ok = await services.modbus.exclusiveSession(() async {
        // Any feed/retract first clears continuous latch (lws-ui close then open).
        if (!await services.modbus.writeAttribute(
          DeviceControlIds.wireWork,
          false,
        )) {
          return false;
        }
        // lws-ui's createOpenFeedConfig/createBackFeedConfig force laser off.
        if (!await services.modbus.writeAttribute(
          DeviceControlIds.laserEnable,
          false,
        )) {
          return false;
        }
        if (!await services.modbus.writeAttribute(
          DeviceControlIds.wireDirection,
          retract,
        )) {
          return false;
        }
        return services.modbus.writeAttribute(DeviceControlIds.wireWork, true);
      });
      if (!ok) {
        lastError = 'Wire control write failed';
        return LaserEnableBlockReason.writeFailed;
      }
      laserEnable = false;
      wireRetracting = retract;
      wireWork = true;
      return null;
    } catch (e) {
      lastError = '$e';
      return LaserEnableBlockReason.writeFailed;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Idempotent clear of continuous feed/retract (mode switch / exit prep).
  Future<LaserEnableBlockReason?> clearContinuousWire() => stopWire();

  /// Stop whichever manual wire movement is active.
  Future<LaserEnableBlockReason?> stopWire() async {
    if (busy) {
      return LaserEnableBlockReason.busy;
    }
    busy = true;
    lastError = null;
    notifyListeners();
    try {
      final ok = await services.modbus.exclusiveSession(() async {
        // lws-ui `createCloseFeedOrBackConfig` resets direction to feed.
        if (!await services.modbus.writeAttribute(
          DeviceControlIds.wireDirection,
          false,
        )) {
          return false;
        }
        return services.modbus.writeAttribute(DeviceControlIds.wireWork, false);
      });
      if (!ok) {
        lastError = 'Wire control write failed';
        return LaserEnableBlockReason.writeFailed;
      }
      wireWork = false;
      wireRetracting = false;
      return null;
    } catch (e) {
      lastError = '$e';
      return LaserEnableBlockReason.writeFailed;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Hold-to-enable path: run preflight then write laser_enable=true.
  LaserEnableBlockReason? preflightLaserEnable({
    WarnAlarmController? warnAlarm,
    LaserAlarmPolicySnapshot? policy,
  }) {
    if (busy) {
      return LaserEnableBlockReason.busy;
    }
    if (manualGas) {
      return LaserEnableBlockReason.manualGasOn;
    }

    final machineBlock = LaserEnablePreflight.machineStatusBlock(
      emergencyStop: emergencyStop,
      keySwitchOn: keySwitchOn,
    );
    if (machineBlock != null) {
      lastError = machineBlock.message;
      notifyListeners();
      return machineBlock;
    }

    final snapshot = policy ??
        const LaserAlarmPolicySnapshot(
          keepLaserOnWhileAlarmed: false,
          allowWorkAfterCameraAlarm: false,
          allowWorkAfterGasAlarm: false,
          allowWorkAfterLensContamination: false,
          allowWorkAfterFeederAlarm: false,
        );
    final active = <String>{
      if (warnAlarm != null)
        for (final e in warnAlarm.coordinator.episodes.values)
          if (e.faultActive) e.code,
    };
    final alarm = LaserEnablePreflight.alarmBlock(
      activeAlarmCodes: active,
      policy: snapshot,
    );
    if (alarm != null) {
      lastError = alarm.message;
      notifyListeners();
      return alarm;
    }
    return null;
  }

  Future<LaserEnableBlockReason?> enableLaser({
    WarnAlarmController? warnAlarm,
    LaserAlarmPolicySnapshot? policy,
  }) async {
    final block = preflightLaserEnable(
      warnAlarm: warnAlarm,
      policy: policy,
    );
    if (block != null) {
      return block;
    }

    busy = true;
    lastError = null;
    notifyListeners();
    try {
      final ok = await services.modbus.exclusiveSession(() async {
        // Starting work always cancels stale manual feed/retract state first.
        if (!await services.modbus.writeAttribute(
          DeviceControlIds.wireWork,
          false,
        )) {
          return false;
        }
        return services.modbus.writeAttribute(
          DeviceControlIds.laserEnable,
          true,
        );
      });
      if (!ok) {
        lastError = LaserEnableBlockReason.writeFailed.message;
        return LaserEnableBlockReason.writeFailed;
      }
      laserEnable = true;
      wireWork = false;
      return null;
    } catch (e) {
      lastError = '$e';
      return LaserEnableBlockReason.writeFailed;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<LaserEnableBlockReason?> disableLaser() async {
    if (busy) {
      return LaserEnableBlockReason.busy;
    }
    busy = true;
    lastError = null;
    notifyListeners();
    try {
      final ok = await services.modbus.exclusiveSession(() async {
        // End of work clears continuous feed/retract before laser enable.
        if (!await services.modbus.writeAttribute(
          DeviceControlIds.wireWork,
          false,
        )) {
          return false;
        }
        return services.modbus.writeAttribute(
          DeviceControlIds.laserEnable,
          false,
        );
      });
      if (!ok) {
        lastError = LaserEnableBlockReason.writeFailed.message;
        return LaserEnableBlockReason.writeFailed;
      }
      laserEnable = false;
      wireWork = false;
      return null;
    } catch (e) {
      lastError = '$e';
      return LaserEnableBlockReason.writeFailed;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel() ?? Future<void>.value());
    super.dispose();
  }
}
