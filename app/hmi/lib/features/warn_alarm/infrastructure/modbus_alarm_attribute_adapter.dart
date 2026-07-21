import 'dart:async';

import 'package:cyber_alarm/cyber_alarm.dart';
import 'package:flutter/foundation.dart';
import 'package:lws_hmi/features/monitor/application/monitor_modbus_ids.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';

/// Product code for HMI↔controller Modbus read-health faults (lws-ui C001).
const kModbusHealthAlarmCode = 'C001';

/// Maps HAL watches → [AlarmSignalEvent] (+ monitor attribute/health fan-out).
final class ModbusAlarmAttributeAdapter implements AlarmSignalSource {
  ModbusAlarmAttributeAdapter({
    required this.modbus,
    this.ensureLive,
  });

  final ModbusRtuClient modbus;
  final Future<void> Function()? ensureLive;

  // sync: deliver rising/falling in the same turn as HAL/health samples so
  // coordinator edges are not lost to microtask scheduling.
  final _controller = StreamController<AlarmSignalEvent>.broadcast(sync: true);
  final _monitorCtrl =
      StreamController<List<ModbusAttributeChange>>.broadcast();
  final _healthCtrl = StreamController<ModbusHealth>.broadcast();

  StreamSubscription<List<ModbusAttributeChange>>? _sub;
  StreamSubscription<ModbusHealth>? _healthSub;
  final Map<String, bool> _activeByAttr = {};
  Map<String, ({String code, String? label})> _meta = {};
  bool _started = false;

  /// Last unhealthy latch for C001 edge detection (`null` = not primed).
  bool? _healthFaultActive;

  @override
  Stream<AlarmSignalEvent> get events => _controller.stream;

  /// Temps + alarm bits for Alarm Information UI.
  Stream<List<ModbusAttributeChange>> get monitorChanges => _monitorCtrl.stream;

  Stream<ModbusHealth> get healthChanges => _healthCtrl.stream;

  /// Attribute ids that carry `meta.alarm_code`.
  List<String> get watchedIds => _meta.keys.toList(growable: false);

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    try {
      await ensureLive?.call();
      final attrs = await modbus.listAttributes();
      _meta = {};
      for (final a in attrs) {
        final code = a.meta?.alarmCode;
        if (code == null || code.isEmpty) {
          continue;
        }
        _meta[a.id] = (
          code: code,
          label: a.meta?.label,
        );
      }
      final ids = <String>{
        ...MonitorModbusIds.temperatureIds,
        ...MonitorModbusIds.overTempIds,
        ..._meta.keys,
      }.toList(growable: false);
      if (ids.isNotEmpty) {
        final stream = await modbus.watchAttributes(ids: ids);
        _sub = stream.listen(_onChanges);
      }
      final healthStream = await modbus.watchHealth();
      _healthSub = healthStream.listen(_onHealth);
    } catch (_) {
      // Soft-fail: no signal stream.
    }
  }

  void _onHealth(ModbusHealth health) {
    if (!_healthCtrl.isClosed) {
      _healthCtrl.add(health);
    }
    _emitHealthAlarm(health);
  }

  /// Maps aggregate Modbus health → C001 rising/falling (edge only).
  void _emitHealthAlarm(ModbusHealth health) {
    final unhealthy = !health.ok;
    final previous = _healthFaultActive;
    if (previous == null) {
      _healthFaultActive = unhealthy;
      if (!unhealthy) {
        return;
      }
    } else if (previous == unhealthy) {
      return;
    } else {
      _healthFaultActive = unhealthy;
    }

    if (_controller.isClosed) {
      return;
    }
    _controller.add(
      AlarmSignalEvent(
        code: kModbusHealthAlarmCode,
        active: unhealthy,
        kind: unhealthy ? AlarmSignalKind.rising : AlarmSignalKind.falling,
        attributeId: 'health.modbus',
        labelHint: health.message,
      ),
    );
  }

  /// Test hook: apply a health sample without starting HAL watches.
  @visibleForTesting
  void debugApplyHealth(ModbusHealth health) => _onHealth(health);

  void _onChanges(List<ModbusAttributeChange> changes) {
    if (changes.isEmpty) {
      return;
    }
    if (!_monitorCtrl.isClosed) {
      _monitorCtrl.add(changes);
    }
    for (final c in changes) {
      final meta = _meta[c.id];
      if (meta == null) {
        continue;
      }
      final active = c.value == true;
      final previous = _activeByAttr[c.id];
      _activeByAttr[c.id] = active;

      final AlarmSignalKind kind;
      if (c.kind == ModbusChangeKind.reminder) {
        kind = AlarmSignalKind.reminder;
      } else if (previous == null) {
        if (!active) {
          continue;
        }
        kind = AlarmSignalKind.rising;
      } else if (active && !previous) {
        kind = AlarmSignalKind.rising;
      } else if (!active && previous) {
        kind = AlarmSignalKind.falling;
      } else if (active) {
        kind = AlarmSignalKind.reminder;
      } else {
        continue;
      }

      if (!_controller.isClosed) {
        _controller.add(
          AlarmSignalEvent(
            code: meta.code,
            active: active,
            kind: kind,
            attributeId: c.id,
            labelHint: meta.label,
          ),
        );
      }
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _healthSub?.cancel();
    _sub = null;
    _healthSub = null;
    await _controller.close();
    await _monitorCtrl.close();
    await _healthCtrl.close();
    _started = false;
  }
}
