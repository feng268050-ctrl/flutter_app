/// Modbus attribute ids for Quick/Engineer device controls (holding 0x0058).
abstract final class DeviceControlIds {
  /// Whole CONTROL_FIELD_1 word (0x0058) — lws-ui single-register halt write.
  static const controlField1 = 'control.field_1';

  static const laserEnable = 'control.laser_enable';
  static const manualGas = 'control.manual_gas';
  static const wireWork = 'control.wire_work';
  static const wireDirection = 'control.wire_direction';
  static const wireManualMode = 'control.wire_manual_mode';

  /// Holding 0x0098 — manual Feed/Retract speed (not process library wire speed).
  static const manualWireFeedSpeed = 'setting.manual_wire_feed_speed';

  /// lws-ui `DefaultValueUtils` / Advanced Settings default (mm/s).
  static const manualWireFeedSpeedMmPerS = 80;

  /// Job-switch bits in [controlField1] (laser/gas/wire/dir/auto).
  static const controlField1JobBitsMask = 0x1F;

  static const laserOn = 'machine.laser_on';
  static const airValveOn = 'machine.air_valve_on';
  static const wireFeedingOn = 'machine.wire_feeding_on';
  static const keySwitchOn = 'machine.key_switch_on';
  static const emergencyStop = 'machine.emergency_stop';
  static const blowPressure = 'telemetry.blow_pressure';

  static const watchIds = <String>[
    laserEnable,
    manualGas,
    wireWork,
    wireDirection,
    wireManualMode,
    laserOn,
    airValveOn,
    wireFeedingOn,
    keySwitchOn,
    emergencyStop,
    blowPressure,
  ];
}

/// Why laser enable was blocked (shown in UI).
enum LaserEnableBlockReason {
  statusUnavailable,
  emergencyStop,
  keySwitchOff,
  manualGasOn,
  alarmBlocked,
  writeFailed,
  busy,
}

extension LaserEnableBlockReasonMessage on LaserEnableBlockReason {
  String get message {
    switch (this) {
      case LaserEnableBlockReason.statusUnavailable:
        return 'Check equipment status';
      case LaserEnableBlockReason.emergencyStop:
        return 'Release E-Stop first';
      case LaserEnableBlockReason.keySwitchOff:
        return 'Turn key switch on';
      case LaserEnableBlockReason.manualGasOn:
        return 'Turn off Manual Gas first';
      case LaserEnableBlockReason.alarmBlocked:
        return 'Alarm blocks laser enable';
      case LaserEnableBlockReason.writeFailed:
        return 'Laser enable write failed';
      case LaserEnableBlockReason.busy:
        return 'Control busy';
    }
  }
}

/// Hold-to-enable timing (lws-ui FrostHoldConfirmController fill).
abstract final class DeviceControlTiming {
  static const Duration laserHoldToEnable = Duration(milliseconds: 300);

  /// Manual Feed/Retract gesture timings (lws-ui wire pulse / hold / latch).
  static const Duration wireHoldToRun = Duration(milliseconds: 500);
  static const Duration wirePulseDuration = Duration(milliseconds: 500);
  static const Duration wireFeedLatchDelay = Duration(milliseconds: 3000);
}
