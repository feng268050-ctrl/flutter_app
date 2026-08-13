import 'dart:async';

import 'package:cyber_hal/cyber_hal.dart' show BoardProfile;
import 'package:cyber_hal/modbus.dart';
import 'package:flutter/foundation.dart';
import 'package:lws_hmi/device/display_value.dart';
import 'package:lws_hmi/hal/hal_assets.dart';

export 'package:cyber_hal/modbus.dart'
    show
        ModbusAlarmTemperaturesSnapshot,
        ModbusAttributeChange,
        ModbusAttributeConfig,
        ModbusAttributeMeta,
        ModbusChangeKind,
        ModbusDeviceInfoSnapshot,
        ModbusHal,
        ModbusHealth,
        Ynh960ModbusReads,
        decimalRegister,
        formatTemperatureDisplay,
        kModbusUnavailableDisplay;

/// Attribute ids the P2 Demo watches for live updates.
const kDemoModbusWatchIds = <String>[
  'device.control_card_version',
  'alarm.laser_comm',
  'alarm.gun_comm',
  'telemetry.gun_motor_temp',
  'telemetry.gun_motor_drive_temp',
  'telemetry.protective_cover_temp',
  'telemetry.collimator_temp',
  'alarm.gun_motor_over_temp',
  'alarm.driver_over_temp',
  'alarm.protective_mirror_over_temp',
  'alarm.collimator_over_temp',
  'alarm.wire_feeder_comm',
];

/// Device Information Modbus-backed rows (continuous + on-demand info).
const kDeviceInfoModbusWatchIds = <String>[
  'device.control_card_version',
  'device.gun_head_sn',
];

/// App façade over [ModbusHal] — attribute ids from `modbus.json`, not addresses.
///
/// Soft-open: missing port → snapshots return [kUnavailableDisplay] fields.
/// Continuous poll is process-wide ([ensurePolling]); each UI surface opens its
/// own [watchAttributes] / [watchHealth] with explicit ids.
class ModbusRtuClient {
  ModbusRtuClient({
    ModbusHal? hal,
    BoardProfile? profile,
    Future<ModbusHal>? halFuture,
  })  : _hal = hal,
        _profile = profile,
        _loading = halFuture;

  ModbusHal? _hal;
  final BoardProfile? _profile;
  Future<ModbusHal>? _loading;
  bool _polling = false;
  Future<void>? _commandChain;
  static final Object _queueZoneKey = Object();

  Future<ModbusHal> _ensureHal() {
    if (_hal != null) {
      return Future<ModbusHal>.value(_hal);
    }
    if (_loading != null) {
      return _loading!.then((h) {
        _hal = h;
        return h;
      });
    }
    final profile = _profile;
    return _loading ??= (profile != null
            ? ModbusHal.fromProfile(profile)
            : ModbusHal.fromAsset(asset: HmiHalAssets.modbus))
        .then((h) {
      _hal = h;
      return h;
    });
  }

  /// Soft-open for tests/subclasses; production paths use attribute reads.
  Future<bool> open() async {
    try {
      await _ensureHal();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> close() async {
    await stopPolling();
    await _hal?.close();
  }

  /// Catalog attributes (for Monitor alarm meta / watch allowlists).
  Future<List<ModbusAttributeConfig>> listAttributes() async {
    final hal = await _ensureHal();
    return hal.listAttributes();
  }

  /// Start continuous group polling (HAL idempotent while already polling).
  Future<void> ensurePolling() async {
    final hal = await _ensureHal();
    await hal.startPolling();
    _polling = true;
  }

  Future<void> stopPolling() async {
    if (!_polling) {
      return;
    }
    _polling = false;
    try {
      await _hal?.stopPolling();
    } catch (_) {}
  }

  /// Attribute ids belonging to [groupIds] (via HAL config group membership).
  Future<List<String>> attributeIdsForGroups(Iterable<String> groupIds) async {
    final hal = await _ensureHal();
    final ids = <String>{};
    for (final g in groupIds) {
      for (final a in hal.config.attributesForGroup(g)) {
        ids.add(a.id);
      }
    }
    return ids.toList(growable: false);
  }

  /// Per-subscriber attribute watch; bind [ids] to this surface's interests.
  Future<Stream<List<ModbusAttributeChange>>> watchAttributes({
    Iterable<String>? ids,
  }) async {
    final hal = await _ensureHal();
    return hal.watchAttributes(ids: ids);
  }

  Future<Stream<ModbusHealth>> watchHealth() async {
    final hal = await _ensureHal();
    return hal.watchHealth();
  }

  /// Apply properties.ini `control_card_comm_alarm_mode` to HAL C001 window.
  Future<void> applyHealthWindowMode(String? mode) async {
    final hal = await _ensureHal();
    hal.applyHealthWindowMode(mode);
  }

  /// On-demand group read (e.g. `info` for gunhead / laser / wire SN).
  Future<Map<String, Object?>> readGroup(String groupId) async {
    final hal = await _ensureHal();
    return hal.readGroup(groupId);
  }

  /// Reads P2 Device Information via attribute ids; failures → `-`.
  Future<ModbusDeviceInfoSnapshot> readDeviceInfo() async {
    try {
      final hal = await _ensureHal();
      return await hal.readDeviceInfo();
    } catch (_) {
      return ModbusDeviceInfoSnapshot.unavailable;
    }
  }

  /// Reads welding-gun sensor temperatures via attribute ids.
  Future<ModbusAlarmTemperaturesSnapshot> readAlarmTemperatures() async {
    try {
      final hal = await _ensureHal();
      return await hal.readAlarmTemperatures();
    } catch (_) {
      return ModbusAlarmTemperaturesSnapshot.unavailable;
    }
  }

  /// One-shot attribute read (boot self-check / on-demand). Soft-fails → null.
  Future<Object?> readAttribute(String id) async {
    try {
      final hal = await _ensureHal();
      return await hal.readAttribute(id);
    } catch (_) {
      return null;
    }
  }

  /// Holding-register write by attribute id. Soft-fails → false.
  Future<bool> writeAttribute(String id, Object? value) async {
    try {
      final hal = await _ensureHal();
      await hal.writeAttribute(id, value);
      return true;
    } catch (e) {
      debugPrint('modbus writeAttribute($id) failed: $e');
      return false;
    }
  }

  /// Contiguous FC16 write (OTA frames). Soft-fails → false.
  Future<bool> writeHoldingRegisters(int address, List<int> words) async {
    try {
      final hal = await _ensureHal();
      await hal.writeHoldingRegisters(address, words);
      return true;
    } catch (e) {
      debugPrint(
        'modbus writeHoldingRegisters(0x${address.toRadixString(16)}, '
        'n=${words.length}) failed: $e',
      );
      return false;
    }
  }

  /// One Modbus function-16 write for a named holding-register group.
  Future<bool> writeGroup(
    String groupId,
    Map<String, Object?> values,
  ) async {
    try {
      final hal = await _ensureHal();
      await hal.writeGroup(groupId, values);
      return true;
    } catch (e) {
      debugPrint('modbus writeGroup($groupId) failed: $e');
      return false;
    }
  }

  /// Serializes Modbus control transactions app-wide (apply + device control).
  Future<T> runCommandQueued<T>(Future<T> Function() body) async {
    // Re-entrant queued call (e.g. controller queue -> exclusiveSession) must
    // execute inline to avoid waiting on itself and deadlocking busy=true.
    if (Zone.current[_queueZoneKey] == true) {
      return body();
    }
    final previous = _commandChain ?? Future<void>.value();
    final completer = Completer<void>();
    _commandChain = completer.future;
    await previous.catchError((_) {});
    try {
      return await runZoned(
        body,
        zoneValues: {_queueZoneKey: true},
      );
    } finally {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }

  /// Pause background polling while [body] performs a control transaction.
  Future<T> exclusiveSession<T>(Future<T> Function() body) async {
    return runCommandQueued(() async {
      final hal = await _ensureHal();
      return hal.exclusiveSession(body);
    });
  }
}

/// Map HAL unavailable token to App display constant (same glyph today).
String modbusDisplayOrDash(String value) =>
    value == kModbusUnavailableDisplay ? kUnavailableDisplay : value;

String modbusAlarmBoolDisplay(Object? value) {
  if (value is bool) {
    return value ? 'ALARM' : 'OK';
  }
  return kUnavailableDisplay;
}

String modbusControlCardDisplay(Object? value) {
  if (value is int) {
    return decimalRegister(value);
  }
  if (value is num) {
    return value.toInt().toString();
  }
  return kUnavailableDisplay;
}

/// Deprecated name — prefer [modbusControlCardDisplay].
String modbusFirmwareDisplay(Object? value) => modbusControlCardDisplay(value);

String modbusVersionStringDisplay(Object? value) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  if (value is int) {
    return decimalRegister(value);
  }
  return kUnavailableDisplay;
}

/// Convert a [readGroup] map into primed [ModbusAttributeChange]s for UI.
List<ModbusAttributeChange> modbusGroupToChanges(Map<String, Object?> group) {
  return [
    for (final e in group.entries)
      ModbusAttributeChange(id: e.key, value: e.value),
  ];
}
