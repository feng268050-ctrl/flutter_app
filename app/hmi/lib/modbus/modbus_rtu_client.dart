import 'dart:async';

import 'package:cyber_hal/cyber_hal.dart' show BoardProfile;
import 'package:cyber_hal/modbus.dart';
import 'package:lws_hmi/device/display_value.dart';

export 'package:cyber_hal/modbus.dart'
    show
        ModbusAlarmTemperaturesSnapshot,
        ModbusAttributeChange,
        ModbusChangeKind,
        ModbusDeviceInfoSnapshot,
        ModbusHal,
        ModbusHealth,
        Ynh960ModbusReads,
        decimalRegister,
        formatTemperatureDisplay,
        kModbusUnavailableDisplay,
        kYnh960ModbusAsset;

/// Attribute ids the P2 Demo watches for live updates (HAL poll/watch).
///
/// Alarm Information mirrors lws-ui `fragment_warn_info` minus Camera Comm.
const kDemoModbusWatchIds = <String>[
  'device.control_card_version',
  'alarm.laser_comm',
  'alarm.gun_comm',
  'alarm.gun_motor_temp',
  'alarm.gun_motor_drive_temp',
  'alarm.protective_cover_temp',
  'alarm.collimator_temp',
  'alarm.gun_motor_over_temp',
  'alarm.driver_over_temp',
  'alarm.protective_mirror_over_temp',
  'alarm.collimator_over_temp',
  'alarm.wire_feeder_comm',
];

/// App façade over [ModbusHal] — attribute ids from `modbus.json`, not addresses.
///
/// Soft-open: missing port → snapshots return [kUnavailableDisplay] fields.
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
  StreamSubscription<List<ModbusAttributeChange>>? _watchSub;
  StreamSubscription<ModbusHealth>? _healthSub;
  bool _live = false;

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
            : ModbusHal.fromAsset())
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
    await stopLiveDemo();
    await _hal?.close();
  }

  /// Start continuous poll + change-only watch for Demo attribute ids.
  ///
  /// Also performs a one-shot `info` group read (gunhead / laser / wire) which
  /// is on-demand in config. Invokes [onAttributeChanges] for primes and diffs.
  Future<void> startLiveDemo({
    required void Function(List<ModbusAttributeChange> changes) onAttributeChanges,
    void Function(ModbusHealth health)? onHealth,
    Iterable<String> watchIds = kDemoModbusWatchIds,
  }) async {
    if (_live) {
      return;
    }
    final hal = await _ensureHal();
    _live = true;

    await hal.startPolling();

    // On-demand info block (not in continuous poll).
    try {
      final info = await hal.readGroup('info');
      final changes = <ModbusAttributeChange>[];
      for (final e in info.entries) {
        changes.add(ModbusAttributeChange(id: e.key, value: e.value));
      }
      if (changes.isNotEmpty) {
        onAttributeChanges(changes);
      }
    } catch (_) {
      // Soft-fail: Demo keeps `-` for info fields.
    }

    _watchSub = hal.watchAttributes(ids: watchIds).listen(onAttributeChanges);
    if (onHealth != null) {
      _healthSub = hal.watchHealth().listen(onHealth);
    }
  }

  Future<void> stopLiveDemo() async {
    await _watchSub?.cancel();
    _watchSub = null;
    await _healthSub?.cancel();
    _healthSub = null;
    if (_live) {
      _live = false;
      try {
        await _hal?.stopPolling();
      } catch (_) {}
    }
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
