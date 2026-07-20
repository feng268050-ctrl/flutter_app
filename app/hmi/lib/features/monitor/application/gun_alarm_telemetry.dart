import 'dart:async';

import 'package:cyber_hal/modbus.dart';
import 'package:flutter/foundation.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/home/application/temp_series.dart';
import 'package:lws_hmi/features/monitor/application/monitor_modbus_ids.dart';
import 'package:lws_hmi/features/monitor/domain/active_alarm.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';

/// Shared gun temperature + active-alarm state driven by HAL attribute watches.
///
/// Used by Monitor → Alarm Information. Call [start] after first frame
/// (optionally delayed); dispose with [dispose].
final class GunAlarmTelemetry {
  GunAlarmTelemetry();

  final TempSeries motor = TempSeries();
  final TempSeries motorDriver = TempSeries();
  final TempSeries protectiveMirror = TempSeries();
  final TempSeries collimator = TempSeries();

  bool gunMotorOverTemp = false;
  bool driverOverTemp = false;
  bool protectiveMirrorOverTemp = false;
  bool collimatorOverTemp = false;

  /// Comm faults (`true` = alarm active). `null` = not yet primed.
  bool? laserCommFault;
  bool? gunCommFault;
  bool? wireFeederCommFault;

  /// Active alarms keyed by attribute id (stable order via [activeAlarms]).
  final Map<String, ActiveAlarm> _active = {};
  Map<String, AlarmCatalogEntry> _catalog = {};

  /// Test hook: install alarm catalog without [start] / AppServices.
  @visibleForTesting
  void debugSetCatalog(Map<String, AlarmCatalogEntry> catalog) {
    _catalog = Map<String, AlarmCatalogEntry>.from(catalog);
  }

  bool healthOk = true;
  String? healthMessage;

  StreamSubscription<List<ModbusAttributeChange>>? _modbusSub;
  StreamSubscription<ModbusHealth>? _healthSub;
  Timer? _startDelay;
  Timer? _uiGate;
  bool _dirty = false;
  void Function()? _onUpdate;

  List<ActiveAlarm> get activeAlarms {
    final list = _active.values.toList(growable: false);
    list.sort((a, b) => a.code.compareTo(b.code));
    return list;
  }

  /// Apply attribute changes (also used by unit tests).
  void applyChanges(List<ModbusAttributeChange> changes) {
    if (changes.isEmpty) {
      return;
    }
    for (final c in changes) {
      switch (c.id) {
        case MonitorModbusIds.motorTemp:
          motor.setCelsius(
            modbusTempCelsius(c.value),
            overTemp: gunMotorOverTemp,
          );
        case MonitorModbusIds.motorDriverTemp:
          motorDriver.setCelsius(
            modbusTempCelsius(c.value),
            overTemp: driverOverTemp,
          );
        case MonitorModbusIds.protectiveMirrorTemp:
          protectiveMirror.setCelsius(
            modbusTempCelsius(c.value),
            overTemp: protectiveMirrorOverTemp,
          );
        case MonitorModbusIds.collimatorTemp:
          collimator.setCelsius(
            modbusTempCelsius(c.value),
            overTemp: collimatorOverTemp,
          );
        case MonitorModbusIds.motorOverTemp:
          gunMotorOverTemp = c.value == true;
          motor.setOverTemp(gunMotorOverTemp);
        case MonitorModbusIds.driverOverTemp:
          driverOverTemp = c.value == true;
          motorDriver.setOverTemp(driverOverTemp);
        case MonitorModbusIds.protectiveMirrorOverTemp:
          protectiveMirrorOverTemp = c.value == true;
          protectiveMirror.setOverTemp(protectiveMirrorOverTemp);
        case MonitorModbusIds.collimatorOverTemp:
          collimatorOverTemp = c.value == true;
          collimator.setOverTemp(collimatorOverTemp);
        case 'alarm.laser_comm':
          laserCommFault = c.value == true;
          _applyAlarmChange(c);
        case 'alarm.gun_comm':
          gunCommFault = c.value == true;
          _applyAlarmChange(c);
        case 'alarm.wire_feeder_comm':
          wireFeederCommFault = c.value == true;
          _applyAlarmChange(c);
        default:
          _applyAlarmChange(c);
      }
    }
    _dirty = true;
  }

  void applyHealth(ModbusHealth health) {
    healthOk = health.ok;
    healthMessage = health.message;
    _dirty = true;
  }

  void _applyAlarmChange(ModbusAttributeChange c) {
    final entry = _catalog[c.id];
    if (entry == null) {
      return;
    }
    if (c.value == true) {
      _active[c.id] = ActiveAlarm(
        id: entry.id,
        code: entry.code,
        label: entry.label,
      );
    } else {
      _active.remove(c.id);
    }
  }

  /// Load catalog meta, ensure Modbus live, subscribe. Soft-fails silently.
  Future<void> start(
    AppServices services, {
    required void Function() onUpdate,
    Duration startDelay = const Duration(milliseconds: 1200),
    Duration uiGate = const Duration(milliseconds: 500),
  }) async {
    _onUpdate = onUpdate;
    _startDelay?.cancel();
    _startDelay = Timer(startDelay, () {
      unawaited(_startNow(services, uiGate: uiGate));
    });
  }

  Future<void> _startNow(
    AppServices services, {
    required Duration uiGate,
  }) async {
    try {
      final attrs = await services.modbus.listAttributes();
      _catalog = MonitorModbusIds.alarmCatalog(attrs);
      await services.ensureModbusLive(
        watchIds: MonitorModbusIds.watchIdsFromCatalog(attrs),
      );
      await _modbusSub?.cancel();
      await _healthSub?.cancel();
      _modbusSub = services.modbusAttributeChanges.listen(applyChanges);
      _healthSub = services.modbusHealthChanges.listen(applyHealth);
      _uiGate?.cancel();
      _uiGate = Timer.periodic(uiGate, (_) {
        if (!_dirty) {
          return;
        }
        _dirty = false;
        _onUpdate?.call();
      });
    } catch (_) {
      // Soft-fail: UI keeps `-` / empty alarm list.
    }
  }

  Future<void> dispose() async {
    _startDelay?.cancel();
    _uiGate?.cancel();
    await _modbusSub?.cancel();
    await _healthSub?.cancel();
    _modbusSub = null;
    _healthSub = null;
    _onUpdate = null;
  }
}
