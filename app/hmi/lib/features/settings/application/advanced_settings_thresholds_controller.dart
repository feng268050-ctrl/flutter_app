import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_modbus_ids.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_store.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_threshold_codec.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';

/// Owns Advanced Settings numeric thresholds: cache + Modbus watch/write.
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
      // `settings` is on_demand — continuous poll never refreshes it.
      // Prime via readGroup (Device Information pattern), then watch for
      // post-write cache updates from HAL.
      final stream = await services.modbus.watchAttributes(
        ids: AdvancedSettingsModbusIds.watchIds,
      );
      _sub = stream.listen(_onChanges);
      await _primeFromSettingsGroup();
      notifyListeners();
    } catch (e) {
      debugPrint('advanced-thresholds: start failed: $e');
    }
  }

  Future<void> _primeFromSettingsGroup() async {
    try {
      final group = await services.modbus.readGroup('settings');
      _onChanges(modbusGroupToChanges(group));
      return;
    } catch (e) {
      debugPrint('advanced-thresholds: readGroup(settings) failed: $e');
    }
    for (final id in AdvancedSettingsModbusIds.watchIds) {
      final raw = await services.modbus.readAttribute(id);
      final ui = AdvancedSettingsThresholdCodec.fromWire(id, raw);
      if (ui != null) {
        _applyId(id, ui, notify: false);
      }
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
    if (_committing) {
      return;
    }
    _committing = true;
    try {
      await _writeAll(next);
    } finally {
      _committing = false;
    }
  }

  Future<void> commitField(
    String attributeId,
    AdvancedSettingsThresholdValues next,
  ) async {
    _values = next;
    notifyListeners();
    await store.setThresholds(next);
    final wire = AdvancedSettingsThresholdCodec.toWire(
      attributeId,
      _uiForId(attributeId, next),
    );
    final ok = await services.modbus.writeAttribute(attributeId, wire);
    if (!ok) {
      debugPrint('advanced-thresholds: write $attributeId failed');
    }
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
      _applyId(c.id, ui, notify: false);
      changed = true;
    }
    if (changed) {
      notifyListeners();
      unawaited(store.setThresholds(_values));
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

  Future<void> _writeAll(AdvancedSettingsThresholdValues v) async {
    for (final id in AdvancedSettingsModbusIds.watchIds) {
      final wire = AdvancedSettingsThresholdCodec.toWire(id, _uiForId(id, v));
      await services.modbus.writeAttribute(id, wire);
    }
  }

  @override
  void dispose() {
    unawaited(stop());
    super.dispose();
  }
}
