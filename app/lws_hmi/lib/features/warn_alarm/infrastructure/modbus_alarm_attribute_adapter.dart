import 'dart:async';

import 'package:cyber_alarm/cyber_alarm.dart';
import 'package:flutter/foundation.dart';
import 'package:lws_hmi/features/monitor/application/monitor_modbus_ids.dart';
import 'package:lws_hmi/features/warn_alarm/infrastructure/estop_comm_alarm_mask.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';

/// Product code for HMI↔controller Modbus read-health faults (lws-ui C001).
const kModbusHealthAlarmCode = 'C001';

/// Maps HAL watches → [AlarmSignalEvent] (+ monitor attribute/health fan-out).
///
/// Applies [EstopCommAlarmMask] so H022/W001/H029 do not rise (popup/history)
/// while `machine.emergency_stop` is active. After e-stop release, masked bits
/// are re-sampled after a short settle (not from the release-edge cache) so
/// de-energize false-positives do not stick and block Laser Enable. Alarm
/// Information / status checks keep raw Modbus bit values.
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
  /// Last **warn-signal** active per alarm attribute (post e-stop mask for
  /// H022/W001/H029; raw for all other codes).
  final Map<String, bool> _activeByAttr = {};
  Map<String, ({String code, String? label})> _meta = {};
  bool _started = false;

  bool _eStopActive = false;
  bool? _rawLaserComm;
  bool? _rawWireFeederComm;
  bool? _rawLaserEmergencyStop;

  /// Bumps when e-stop releases / adapter disposes so delayed resamples cancel.
  int _estopReleaseResampleGen = 0;

  /// Settle time after e-stop release before re-arming masked alarms from
  /// cached raw bits (de-energize false-positives often clear within one poll).
  @visibleForTesting
  static Duration estopMaskedResampleDelay = const Duration(milliseconds: 400);

  /// Last unhealthy latch for C001 edge detection (`null` = not primed).
  bool? _healthFaultActive;

  @override
  Stream<AlarmSignalEvent> get events => _controller.stream;

  /// Temps + alarm bits for Alarm Information UI (raw HAL values).
  Stream<List<ModbusAttributeChange>> get monitorChanges => _monitorCtrl.stream;

  Stream<ModbusHealth> get healthChanges => _healthCtrl.stream;

  /// Attribute ids that carry `meta.alarm_code`.
  List<String> get watchedIds => _meta.keys.toList(growable: false);

  /// Last known machine e-stop latch (test / diagnostics).
  @visibleForTesting
  bool get debugEStopActive => _eStopActive;

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
        EstopCommAlarmMask.emergencyStopAttr,
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

  /// Test hook: apply attribute changes (optionally after seeding [_meta]).
  @visibleForTesting
  void debugApplyChanges(List<ModbusAttributeChange> changes) =>
      _onChanges(changes);

  /// Test hook: seed alarm meta without HAL [listAttributes].
  @visibleForTesting
  void debugSeedMeta(Map<String, ({String code, String? label})> meta) {
    _meta = Map.of(meta);
  }

  void _onChanges(List<ModbusAttributeChange> changes) {
    if (changes.isEmpty) {
      return;
    }

    final wasEStop = _eStopActive;

    // Pass 1: update e-stop latch + raw masked bits from the whole batch.
    for (final c in changes) {
      if (c.id == EstopCommAlarmMask.emergencyStopAttr) {
        _eStopActive = c.value == true;
      } else if (c.id == EstopCommAlarmMask.laserCommAttr) {
        _rawLaserComm = c.value == true;
      } else if (c.id == EstopCommAlarmMask.wireFeederCommAttr) {
        _rawWireFeederComm = c.value == true;
      } else if (c.id == EstopCommAlarmMask.laserEmergencyStopAttr) {
        _rawLaserEmergencyStop = c.value == true;
      }
    }

    final eStopEngaged = !wasEStop && _eStopActive;
    final eStopReleased = wasEStop && !_eStopActive;

    // Pass 2: Alarm Information / status checks — raw values unchanged.
    if (!_monitorCtrl.isClosed) {
      _monitorCtrl.add(changes);
    }

    // Pass 3: e-stop engage forces masked warns inactive. On release, do NOT
    // immediately re-arm from cached raw — that races de-energize false
    // positives (H022/W001/H029) that clear on the next poll and left Laser
    // Enable stuck behind "Alarm blocks laser enable". Resample after a short
    // settle; same-batch raw updates still flow through pass 4.
    if (eStopEngaged) {
      _estopReleaseResampleGen++;
      _syncMaskedEffective(
        EstopCommAlarmMask.laserCommAttr,
        effective: false,
      );
      _syncMaskedEffective(
        EstopCommAlarmMask.wireFeederCommAttr,
        effective: false,
      );
      _syncMaskedEffective(
        EstopCommAlarmMask.laserEmergencyStopAttr,
        effective: false,
      );
    } else if (eStopReleased) {
      _scheduleMaskedResampleAfterEstopRelease();
    }

    // Pass 4: per-attribute signal edges (skip masked on e-stop engage only).
    final skipMaskedSignals = eStopEngaged;
    for (final c in changes) {
      if (c.id == EstopCommAlarmMask.emergencyStopAttr) {
        continue;
      }
      if (EstopCommAlarmMask.isMaskedAttr(c.id)) {
        if (skipMaskedSignals) {
          continue;
        }
        final raw = c.value == true;
        final effective = EstopCommAlarmMask.effectiveActive(
          raw: raw,
          eStopActive: _eStopActive,
        );
        final reminder = c.kind == ModbusChangeKind.reminder;
        _emitEffectiveSignal(
          attributeId: c.id,
          effective: effective,
          reminder: reminder,
        );
        continue;
      }

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

      _addSignal(
        code: meta.code,
        active: active,
        kind: kind,
        attributeId: c.id,
        labelHint: meta.label,
      );
    }
  }

  void _scheduleMaskedResampleAfterEstopRelease() {
    final gen = ++_estopReleaseResampleGen;
    final delay = estopMaskedResampleDelay;
    Future<void>.delayed(delay, () {
      if (gen != _estopReleaseResampleGen || _eStopActive || _controller.isClosed) {
        return;
      }
      _syncMaskedEffective(
        EstopCommAlarmMask.laserCommAttr,
        effective: _rawLaserComm == true,
      );
      _syncMaskedEffective(
        EstopCommAlarmMask.wireFeederCommAttr,
        effective: _rawWireFeederComm == true,
      );
      _syncMaskedEffective(
        EstopCommAlarmMask.laserEmergencyStopAttr,
        effective: _rawLaserEmergencyStop == true,
      );
    });
  }

  void _syncMaskedEffective(String attributeId, {required bool effective}) {
    _emitEffectiveSignal(
      attributeId: attributeId,
      effective: effective,
      reminder: false,
    );
  }

  void _emitEffectiveSignal({
    required String attributeId,
    required bool effective,
    required bool reminder,
  }) {
    final meta = _meta[attributeId];
    if (meta == null) {
      _activeByAttr[attributeId] = effective;
      return;
    }

    final previous = _activeByAttr[attributeId];
    _activeByAttr[attributeId] = effective;

    final AlarmSignalKind kind;
    if (reminder) {
      if (!effective) {
        return;
      }
      kind = AlarmSignalKind.reminder;
    } else if (previous == null) {
      if (!effective) {
        return;
      }
      kind = AlarmSignalKind.rising;
    } else if (effective && !previous) {
      kind = AlarmSignalKind.rising;
    } else if (!effective && previous) {
      kind = AlarmSignalKind.falling;
    } else if (effective) {
      kind = AlarmSignalKind.reminder;
    } else {
      return;
    }

    _addSignal(
      code: meta.code,
      active: effective,
      kind: kind,
      attributeId: attributeId,
      labelHint: meta.label,
    );
  }

  void _addSignal({
    required String code,
    required bool active,
    required AlarmSignalKind kind,
    required String attributeId,
    String? labelHint,
  }) {
    if (_controller.isClosed) {
      return;
    }
    _controller.add(
      AlarmSignalEvent(
        code: code,
        active: active,
        kind: kind,
        attributeId: attributeId,
        labelHint: labelHint,
      ),
    );
  }

  Future<void> dispose() async {
    _estopReleaseResampleGen++;
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
