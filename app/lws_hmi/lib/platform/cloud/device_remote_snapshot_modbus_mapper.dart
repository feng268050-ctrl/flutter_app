import 'package:cyber_alarm/cyber_alarm.dart';
import 'package:lws_hmi/features/warn_alarm/infrastructure/sqlite_alarm_log_repository.dart';

/// Builds lws-ui `DeviceStatus` / `DeviceData` / `WarnTable` maps for remote
/// snapshot (`device.online` / `command.stat_response`).
abstract final class DeviceRemoteSnapshotModbusMapper {
  /// Reconstruct register words from decoded HAL attribute maps, then emit
  /// camelCase fields matching lws-ui Gson `DeviceStatus`.
  static Map<String, Object?> deviceStatusFromGroup(
    Map<String, Object?> status, {
    required int cameraStatus,
  }) {
    final gunAlarmSeg1 = _bitWord(status, const [
      ('alarm.gun_comm', 0),
    ]);
    var laserAlarmSeg1 = _bitWord(status, const [
      ('alarm.laser_comm', 0),
      ('alarm.pump_board_over_temp', 1),
      ('alarm.pump_source_temp', 2),
      ('alarm.laser_current', 3),
      ('alarm.red_light_current', 4),
      ('alarm.pump_voltage', 5),
    ]);
    var wireFeederAlarmSeg1 = _bitWord(status, const [
      ('alarm.wire_feeder_comm', 0),
      ('alarm.wire_feeder_current', 1),
    ]);
    final machineStatusSeg1 = _bitWord(status, const [
      ('machine.laser_on', 0),
      ('machine.gun_status', 1),
      ('machine.wire_feeding_on', 2),
      ('machine.red_light_on', 3),
      ('machine.air_valve_on', 4),
      ('machine.safety_ground_lock', 5),
      ('machine.key_switch_on', 6),
      ('machine.emergency_stop', 7),
      ('machine.safety_door_closed', 8),
      ('machine.gun_switch_on', 9),
      ('machine.cnc_connected', 10),
    ]);

    // lws-ui ModbusFiledConvert.applyEmergencyStopCommAlarmReset
    if ((machineStatusSeg1 & (1 << 7)) != 0) {
      laserAlarmSeg1 &= ~0x1;
      wireFeederAlarmSeg1 &= ~0x1;
    }

    return {
      'cameraStatus': cameraStatus,
      'deviceType': _asInt(status['device.type']),
      'hardwareVersion': _asInt(status['device.control_hw_version']),
      'softwareVersion': _asInt(status['device.control_card_version']),
      'otaUpgradeCmd': _asInt(status['device.ota_request_command']),
      'reqHardFirmwareVersion': _asInt(status['device.ota_request_fw_hw_version']),
      'reqSoftwareVersion': _asInt(status['device.ota_request_fw_sw_version']),
      'reqFirmwareOffsetHigh': _asInt(status['device.ota_request_offset_high']),
      'reqFirmwareOffsetLow': _asInt(status['device.ota_request_offset_low']),
      'reqFirmwareDataLength': _asInt(status['device.ota_request_data_length']),
      'gunAlarmSeg1': gunAlarmSeg1,
      'gunAlarmSeg3': _bitWord(status, const [
        ('alarm.sensor_channel_diff', 0),
        ('alarm.static_current_abnormal', 1),
        ('alarm.motor_wire_open', 2),
        ('alarm.sensor_abnormal', 3),
        ('alarm.flash_error', 4),
        ('alarm.flash_unencrypted', 5),
      ]),
      'gunAlarmSeg2': _bitWord(status, const [
        ('alarm.gun_motor_over_temp', 0),
        ('alarm.driver_over_temp', 1),
        ('alarm.protective_mirror_over_temp', 2),
        ('alarm.collimator_over_temp', 3),
        ('alarm.undervoltage_24v', 4),
        ('alarm.driver_over_current', 5),
        ('alarm.motor_track_abnormal', 6),
        ('alarm.motor_stall', 7),
      ]),
      'gunAlarmSeg4': _bitWord(status, const [
        ('alarm.mmi_oscillator', 0),
        ('alarm.hardware_bus_error', 1),
        ('alarm.memory_management', 2),
        ('alarm.memory_access', 3),
        ('alarm.illegal_instruction', 4),
        ('alarm.watchdog_reset', 5),
      ]),
      'laserAlarmSeg1': laserAlarmSeg1,
      'laserAlarmSeg2': _bitWord(status, const [
        ('alarm.laser_driver1_comm', 0),
        ('alarm.laser_driver2_comm', 1),
        ('alarm.laser_driver3_comm', 2),
        ('alarm.laser_driver4_comm', 3),
        ('alarm.ad_feedback_comm', 4),
        ('alarm.pump_module_over_temp', 5),
        ('alarm.driver_module_over_temp', 6),
        ('alarm.water_temp_over_limit', 7),
        ('alarm.fiber_temp_over_limit', 8),
        ('alarm.laser_reflection_energy_over', 9),
        ('alarm.laser_output_energy_under', 10),
        ('alarm.diode_short_circuit', 11),
        ('alarm.fiber_disconnected', 12),
        ('alarm.internal_humidity_over', 13),
        ('alarm.cold_water_interlock', 14),
        ('alarm.laser_emergency_stop', 15),
      ]),
      'laserAlarmSeg3': _bitWord(status, const [
        ('alarm.positioning_light_fault', 0),
        ('alarm.narrow_pulse_protection', 1),
        ('alarm.driver_board_overvoltage', 2),
        ('alarm.env_temperature', 3),
      ]),
      'laserAlarmSeg4': 0,
      'wireFeederAlarmSeg1': wireFeederAlarmSeg1,
      'wireFeederAlarmSeg2': 0,
      'controlCardAlarmSeg1': _bitWord(status, const [
        ('alarm.shielding_gas_blow_pressure', 0),
        ('alarm.shielding_gas_inlet_pressure', 1),
        ('alarm.pressure_sensor_comm', 2),
        ('alarm.control_card_ext_flash', 3),
      ]),
      'controlCardAlarmSeg2': 0,
      'machineStatusSeg1': machineStatusSeg1,
      'machineStatusSeg2': 0,
    };
  }

  /// lws-ui Gson `DeviceData` field names from HAL `data` group.
  ///
  /// Only emits keys for attributes present in [data]. Absent attrs must not
  /// become JSON `null` — mobile merges `stat` patches and a null field would
  /// wipe a previously good reading (lws-ui MemoryCache keeps a full object).
  static Map<String, Object?> deviceDataFromGroup(Map<String, Object?> data) {
    final out = <String, Object?>{};
    void putInt(String wireKey, String attrId) {
      if (!data.containsKey(attrId)) return;
      out[wireKey] = _asInt(data[attrId]);
    }

    void putTempRaw(String wireKey, String attrId) {
      if (!data.containsKey(attrId)) return;
      out[wireKey] = _asSignedRaw(data[attrId]);
    }

    putInt('blowAirPressure', 'telemetry.blow_pressure');
    putTempRaw('gunMotorTempRaw', 'telemetry.gun_motor_temp');
    putTempRaw('gunDriverBoardTempRaw', 'telemetry.gun_motor_drive_temp');
    putTempRaw('protectionBoardTempRaw', 'telemetry.protective_cover_temp');
    putTempRaw('collimatorTempRaw', 'telemetry.collimator_temp');
    putInt('gun24vVoltage', 'telemetry.gun_24v_voltage');
    putInt('gun24vCurrent', 'telemetry.gun_24v_current');
    putInt('laserFeedbackPower', 'telemetry.laser_feedback_power');
    putInt('pumpSourceBoardTemperature', 'telemetry.pump_board_temp');
    putInt('pumpSourceTemperature', 'telemetry.pump_source_temp');
    putInt('laserCurrent', 'telemetry.laser_current');
    putInt('laserRedCurrent', 'telemetry.laser_red_current');
    putInt('environmentTemperature', 'telemetry.ambient_temp');
    return out;
  }

  /// Map Modbus `process` + optional preset metadata to lws-ui
  /// `ProcessParametersData` camelCase (subset present on wire).
  static Map<String, Object?> processParametersFromGroup(
    Map<String, Object?> process, {
    int? processType,
    String? name,
    int? materialType,
    String? materialName,
    double? thickness,
  }) {
    return {
      if (name != null) 'name': name,
      if (materialType != null) 'materialType': materialType,
      if (materialName != null) 'materialName': materialName,
      if (thickness != null) 'thickness': thickness,
      if (processType != null) 'processType': processType,
      'laserPower': _asInt(process['process.laser_power']),
      'laserDutyCycle': _asInt(process['process.laser_duty_cycle']),
      'laserFrequency': _asInt(process['process.laser_frequency']),
      'perforationPower': _asInt(process['process.piercing_power']),
      'perforationFrequency': _asInt(process['process.piercing_frequency']),
      'perforationDutyCycle': _asInt(process['process.piercing_duty_cycle']),
      'swingFrequency': _asInt(process['process.swing_frequency']),
      'swingWidth': _asNum(process['process.swing_width']),
      'wireFeedSpeed': _asNum(process['process.wire_feeding_speed']),
      'retractLength': _asNum(process['process.back_draw_length']),
      'retractSpeed': _asNum(process['process.back_draw_speed']),
      'fillLength': _asNum(process['process.wire_filling_length']),
      'fillDelay': _asInt(process['process.wire_filling_delay']),
      'wireFeedingDelay': _asInt(process['process.wire_feeding_delay']),
      'blowDelay': _asInt(process['process.blowing_delay']),
      'closeAirDelay': _asInt(process['process.gas_off_delay']),
      'closeLightDelay': _asInt(process['process.light_off_delay']),
      'powerRampUp': _asInt(process['process.power_ramp_up_duration']),
      'powerRampDown': _asInt(process['process.power_ramp_down_duration']),
      'pointWeldingDuration': _asInt(process['process.spot_welding_duration']),
      'pointWeldingInterval': _asInt(process['process.spot_welding_interval']),
      'perforationDuration': _asNum(process['process.piercing_duration']),
    };
  }

  /// lws-ui `WarnTable` JSON for `payload.*.warns`.
  static List<Map<String, Object?>> warnsFromAlarmLogs(
    List<AlarmLogEntry> rows,
  ) {
    return [
      for (final e in rows) warnTableFromAlarmLog(e),
    ];
  }

  static Map<String, Object?> warnTableFromAlarmLog(AlarmLogEntry e) {
    final local = e.timestamp.toLocal();
    final ms = e.timestamp.toUtc().millisecondsSinceEpoch;
    final y = local.year.toString().padLeft(4, '0');
    final mo = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final mi = local.minute.toString().padLeft(2, '0');
    final s = local.second.toString().padLeft(2, '0');
    return {
      if (e.id != null) 'id': e.id,
      'ymdDate': '$y-$mo-$d',
      'hmDate': '$h:$mi:$s',
      'code': e.code,
      'content': e.displayLabel,
      'time': ms,
      'newTime': ms,
      'level': e.level ?? SqliteAlarmLogRepository.levelForCode(e.code),
    };
  }

  static int _bitWord(
    Map<String, Object?> attrs,
    List<(String id, int bit)> bits,
  ) {
    var w = 0;
    for (final (id, bit) in bits) {
      if (_truthy(attrs[id])) {
        w |= 1 << bit;
      }
    }
    return w;
  }

  static bool _truthy(Object? v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    return false;
  }

  static int? _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is bool) return v ? 1 : 0;
    return null;
  }

  static num? _asNum(Object? v) {
    if (v is num) return v;
    if (v is bool) return v ? 1 : 0;
    return null;
  }

  /// lws-ui / mobile `*TempRaw`: signed register ×10 °C (e.g. 419 → 41.9 °C).
  ///
  /// HAL applies catalog `scale: 0.1`, so attributes arrive as engineering °C
  /// (`double`, or sentinel ≤ -99.9). Re-encode to register raw for the wire.
  /// Plain `int` is treated as already-raw (legacy / tests with -9990).
  static int? _asSignedRaw(Object? v) {
    if (v == null) return null;
    if (v is int) {
      return v;
    }
    if (v is num) {
      if (v <= -99.9) {
        return -9990;
      }
      return (v * 10).round();
    }
    return null;
  }

  /// Builds lws-ui Gson `DeviceInfo` (+ HMI `brand`/`sn`) for remote snapshot.
  ///
  /// Modbus `info` group supplies laser/wire/gun fields (HAL already formats
  /// `u16_pair_be` as hex concat). Firmware prefers status
  /// `device.control_card_version` (same as Settings “Control Board Version”).
  static Map<String, Object?> deviceInfoFromSources({
    required String deviceSn,
    required String model,
    String brand = '',
    String systemVersion = '',
    String cameraIp = '',
    String cameraVersion = '',
    String hostIp = '',
    int focusScaleRef = 0,
    Map<String, Object?>? infoGroup,
    Map<String, Object?>? statusGroup,
    String? processLibVersion,
  }) {
    final info = infoGroup ?? const <String, Object?>{};
    final status = statusGroup ?? const <String, Object?>{};
    final sn = deviceSn.trim();
    final firmware = _decimalOrEmpty(
      status['device.control_card_version'] ??
          info['device.control_card_version'],
    );
    final processLib = (processLibVersion ?? '').trim();
    return {
      'sn': sn,
      'deviceSn': sn,
      'brand': brand,
      'model': model,
      'systemVersion': systemVersion,
      'firmwareVersion': firmware.isEmpty ? '1000' : firmware,
      'gunSn': _stringOrEmpty(info['device.gun_head_sn']),
      'mainControlSn': '',
      'laserVersion': _stringOrEmpty(info['device.laser_sw_version']),
      'laserHardwareVersion': _stringOrEmpty(info['device.laser_hw_version']),
      'wireFeederVersion': _decimalOrEmpty(info['device.wire_feeder_sw_version']),
      'wireFeederHardwareVersion':
          _decimalOrEmpty(info['device.wire_feeder_hw_version']),
      'gunHeadHardwareVersion':
          _decimalOrEmpty(info['device.gun_head_hw_version']),
      'gunHeadSoftwareVersion':
          _decimalOrEmpty(info['device.gun_head_sw_version']),
      'processLibVersion': processLib.isEmpty ? '--' : processLib,
      'aiVersion': '',
      'cameraVersion': cameraVersion,
      'cameraIp': cameraIp,
      'hostIp': hostIp,
      'focusScaleRef': focusScaleRef,
    };
  }

  static String _stringOrEmpty(Object? v) {
    if (v is String) return v;
    if (v is int) return v.toRadixString(16);
    if (v is num) return v.toInt().toRadixString(16);
    return '';
  }

  static String _decimalOrEmpty(Object? v) {
    if (v is int) return v.toString();
    if (v is num) return v.toInt().toString();
    if (v is String && v.trim().isNotEmpty) return v.trim();
    return '';
  }
}
