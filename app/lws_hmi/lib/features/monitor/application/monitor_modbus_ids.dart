import 'package:cyber_hal/modbus.dart';
import 'package:lws_hmi/features/monitor/domain/active_alarm.dart';

/// Gun Alarm Information + over-temp attribute ids (design D4).
abstract final class MonitorModbusIds {
  static const motorTemp = 'telemetry.gun_motor_temp';
  static const motorDriverTemp = 'telemetry.gun_motor_drive_temp';
  static const protectiveMirrorTemp = 'telemetry.protective_cover_temp';
  static const collimatorTemp = 'telemetry.collimator_temp';

  static const motorOverTemp = 'alarm.gun_motor_over_temp';
  static const driverOverTemp = 'alarm.driver_over_temp';
  static const protectiveMirrorOverTemp = 'alarm.protective_mirror_over_temp';
  static const collimatorOverTemp = 'alarm.collimator_over_temp';

  static const temperatureIds = <String>[
    motorTemp,
    motorDriverTemp,
    protectiveMirrorTemp,
    collimatorTemp,
  ];

  static const overTempIds = <String>[
    motorOverTemp,
    driverOverTemp,
    protectiveMirrorOverTemp,
    collimatorOverTemp,
  ];

  /// Build watch allowlist: gun temps / over-temps + every catalog alarm with
  /// `meta.alarm_code`.
  static List<String> watchIdsFromCatalog(Iterable<ModbusAttributeConfig> attrs) {
    final alarmIds = <String>{};
    for (final a in attrs) {
      if (a.meta?.alarmCode != null) {
        alarmIds.add(a.id);
      }
    }
    return <String>{
      ...temperatureIds,
      ...overTempIds,
      ...alarmIds,
    }.toList(growable: false);
  }

  /// Attributes that appear in the Monitor active-alarm list.
  static Map<String, AlarmCatalogEntry> alarmCatalog(
    Iterable<ModbusAttributeConfig> attrs,
  ) {
    final out = <String, AlarmCatalogEntry>{};
    for (final a in attrs) {
      final code = a.meta?.alarmCode;
      if (code == null || code.isEmpty) {
        continue;
      }
      out[a.id] = AlarmCatalogEntry(
        id: a.id,
        code: code,
        label: a.meta?.label?.trim().isNotEmpty == true
            ? a.meta!.label!.trim()
            : a.id,
      );
    }
    return out;
  }
}
