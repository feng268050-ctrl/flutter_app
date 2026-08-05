import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_modbus_ids.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_store.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_threshold_codec.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';

/// Owns Advanced Settings numeric thresholds: cache + Modbus watch/write.
///
/// App JSON / product defaults are the source of truth for UI (lws-ui Room +
/// `DefaultValueUtils` parity). On start we push the cached values to the
/// controller — we do **not** let a fresh settings-group read of register
/// zeros clobber laser/temp defaults.
final class AdvancedSettingsThresholdsController extends ChangeNotifier {
  AdvancedSettingsThresholdsController({
    required this.store,
    required this.services,
  });

  final AdvancedSettingsStore store;
  final AppServices services;

  AdvancedSettingsThresholdValues _values =
      const AdvancedSettingsThresholdValues();
  StreamSubscription<List<ModbusAttributeChange>>? _sub;
  bool _started = false;
  bool _committing = false;

  AdvancedSettingsThresholdValues get values => _values;

  void warmFromStore() {
    store.warmRead();
    _values = store.thresholds;
    notifyListeners();
  }

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    warmFromStore();
    try {
      await services.ensureModbusLive();
      // Push App cache → device first (lws-ui LaserApplication openSerialPort
      // callback writes the full device-setting block). Then watch for
      // post-write echoes / external changes — never prime UI from a blank
      // settings group that would overwrite product defaults with 0.
      await _pushAll(_values);
      final stream = await services.modbus.watchAttributes(
        ids: AdvancedSettingsModbusIds.watchIds,
      );
      _sub = stream.listen(_onChanges);
      notifyListeners();
    } catch (e) {
      debugPrint('advanced-thresholds: start failed: $e');
    }
  }

  Future<void> stop() async {
    _started = false;
    await _sub?.cancel();
    _sub = null;
  }

  void preview(AdvancedSettingsThresholdValues next) {
    _values = next;
    notifyListeners();
  }

  Future<void> commit(AdvancedSettingsThresholdValues next) async {
    _values = next;
    notifyListeners();
    await store.setThresholds(next);
    await _pushAll(next);
  }

  Future<void> commitField(
    String attributeId,
    AdvancedSettingsThresholdValues next,
  ) async {
    // lws-ui `updateAndSendData` always writes the full device-setting block
    // on slider release — keep the same shape so sibling defaults stay on the
    // controller even when only one slider moved.
    debugPrint('advanced-thresholds: commitField $attributeId');
    await commit(next);
  }

  /// lws-ui `syncAndSendLaserTerminationPower`:
  /// `laserEndPower = laserPower × 0.97`, persist, then write thresholds.
  ///
  /// When [laserPower] is null, still re-commits current values (enable-laser
  /// path still pushes advanced settings).
  Future<void> syncAndSendLaserTerminationPower(double? laserPower) async {
    final next = laserPower == null
        ? _values
        : _values.copyWith(
            laserEndPower:
                AdvancedSettingsThresholdValues.laserEndPowerFromProcess(
              laserPower,
            ),
          );
    await commit(next);
  }

  void _onChanges(List<ModbusAttributeChange> changes) {
    if (_committing) {
      return;
    }
    var changed = false;
    for (final c in changes) {
      if (!AdvancedSettingsModbusIds.watchIds.contains(c.id)) {
        continue;
      }
      final ui = AdvancedSettingsThresholdCodec.fromWire(c.id, c.value);
      if (ui == null) {
        continue;
      }
      // Ignore blank settings-group zeros for product-defaulted fields so a
      // failed / unread register cannot wipe laser/temp defaults again.
      if (_isBlankDeviceValue(c.id, ui)) {
        continue;
      }
      _applyId(c.id, ui, notify: false);
      changed = true;
    }
    if (changed) {
      notifyListeners();
      unawaited(store.setThresholds(_values));
    }
  }

  /// Device holding registers power up at 0; treat that as "unset" for fields
  /// whose lws-ui product default is non-zero. Offset / pressure defaults are
  /// already 0, so zeros there remain meaningful.
  bool _isBlankDeviceValue(String id, double ui) {
    if (ui != 0) {
      return false;
    }
    switch (id) {
      case AdvancedSettingsModbusIds.laserStartPower:
      case AdvancedSettingsModbusIds.laserEndPower:
      case AdvancedSettingsModbusIds.motorTempAlarmThreshold:
      case AdvancedSettingsModbusIds.driverTempAlarmThreshold:
      case AdvancedSettingsModbusIds.protectiveLensTempAlarmThreshold:
      case AdvancedSettingsModbusIds.collimatingLensTempAlarmThreshold:
      case AdvancedSettingsModbusIds.tempAlarmRecoveryInterval:
        return true;
      default:
        return false;
    }
  }

  void _applyId(String id, double ui, {required bool notify}) {
    switch (id) {
      case AdvancedSettingsModbusIds.zeroPointCorrection:
        _values = _values.copyWith(zeroPointCorrection: ui);
      case AdvancedSettingsModbusIds.swingWidthCorrection:
        _values = _values.copyWith(properSwingWidth: ui);
      case AdvancedSettingsModbusIds.laserStartPower:
        _values = _values.copyWith(laserStartPower: ui);
      case AdvancedSettingsModbusIds.laserEndPower:
        _values = _values.copyWith(laserEndPower: ui);
      case AdvancedSettingsModbusIds.blowingPressureThreshold:
        _values = _values.copyWith(blowPressureThreshold: ui);
      case AdvancedSettingsModbusIds.inletGasPressureThreshold:
        _values = _values.copyWith(inletGasPressureThreshold: ui);
      case AdvancedSettingsModbusIds.motorTempAlarmThreshold:
        _values = _values.copyWith(motorTempAlarm: ui);
      case AdvancedSettingsModbusIds.driverTempAlarmThreshold:
        _values = _values.copyWith(driverTempAlarm: ui);
      case AdvancedSettingsModbusIds.protectiveLensTempAlarmThreshold:
        _values = _values.copyWith(protectiveLensTempAlarm: ui);
      case AdvancedSettingsModbusIds.collimatingLensTempAlarmThreshold:
        _values = _values.copyWith(collimatingLensTempAlarm: ui);
      case AdvancedSettingsModbusIds.tempAlarmRecoveryInterval:
        _values = _values.copyWith(tempAlarmRecoveryInterval: ui);
    }
    if (notify) {
      notifyListeners();
    }
  }

  double _uiForId(String id, AdvancedSettingsThresholdValues v) {
    switch (id) {
      case AdvancedSettingsModbusIds.zeroPointCorrection:
        return v.zeroPointCorrection;
      case AdvancedSettingsModbusIds.swingWidthCorrection:
        return v.properSwingWidth;
      case AdvancedSettingsModbusIds.laserStartPower:
        return v.laserStartPower;
      case AdvancedSettingsModbusIds.laserEndPower:
        return v.laserEndPower;
      case AdvancedSettingsModbusIds.blowingPressureThreshold:
        return v.blowPressureThreshold;
      case AdvancedSettingsModbusIds.inletGasPressureThreshold:
        return v.inletGasPressureThreshold;
      case AdvancedSettingsModbusIds.motorTempAlarmThreshold:
        return v.motorTempAlarm;
      case AdvancedSettingsModbusIds.driverTempAlarmThreshold:
        return v.driverTempAlarm;
      case AdvancedSettingsModbusIds.protectiveLensTempAlarmThreshold:
        return v.protectiveLensTempAlarm;
      case AdvancedSettingsModbusIds.collimatingLensTempAlarmThreshold:
        return v.collimatingLensTempAlarm;
      case AdvancedSettingsModbusIds.tempAlarmRecoveryInterval:
        return v.tempAlarmRecoveryInterval;
      default:
        return 0;
    }
  }

  Future<void> _pushAll(AdvancedSettingsThresholdValues v) async {
    if (_committing) {
      return;
    }
    _committing = true;
    try {
      final values = <String, Object?>{
        for (final id in AdvancedSettingsModbusIds.watchIds)
          id: AdvancedSettingsThresholdCodec.toWire(id, _uiForId(id, v)),
      };
      // One FC16 for the settings holding block (lws-ui writeRegisters list /
      // process-library writeGroup pattern), under exclusiveSession so the
      // continuous poll cannot interleave and drop frames.
      final ok = await services.modbus.exclusiveSession(() async {
        return services.modbus.writeGroup('settings', values);
      });
      if (!ok) {
        debugPrint('advanced-thresholds: writeGroup(settings) failed');
        // Soft-fallback: per-attribute writes still try to land what we can.
        for (final entry in values.entries) {
          final one = await services.modbus.writeAttribute(
            entry.key,
            entry.value,
          );
          if (!one) {
            debugPrint('advanced-thresholds: write ${entry.key} failed');
          }
        }
      }
    } finally {
      _committing = false;
    }
  }

  @override
  void dispose() {
    unawaited(stop());
    super.dispose();
  }
}
