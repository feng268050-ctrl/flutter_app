import 'package:cyber_alarm/cyber_alarm.dart';

/// Product seed for [AlarmCodeCatalog] (join keys match `modbus.json` meta).
abstract final class ProductAlarmCatalog {
  static AlarmSeverity severityFor(String code) {
    if (code.isEmpty) {
      return AlarmSeverity.unknown;
    }
    switch (code[0]) {
      case 'E':
        return AlarmSeverity.critical;
      case 'H':
        return AlarmSeverity.high;
      case 'W':
        return AlarmSeverity.medium;
      case 'A':
        return AlarmSeverity.medium;
      case 'L':
      case 'C':
        return AlarmSeverity.high;
      default:
        return AlarmSeverity.unknown;
    }
  }

  /// High-frequency Modbus-backed codes (labels aligned with modbus meta).
  static AlarmCodeCatalog seed() {
    final catalog = AlarmCodeCatalog();
    for (final e in _entries) {
      catalog.add(
        AlarmCodeEntry(
          code: e.$1,
          severity: severityFor(e.$1),
          title: e.$2,
          body: e.$2,
          label: e.$2,
        ),
      );
    }
    // HMI↔controller Modbus health (HAL watchHealth → rising/falling).
    catalog.add(
      const AlarmCodeEntry(
        code: 'C001',
        severity: AlarmSeverity.high,
        title: 'Controller–Tablet Communication Fault',
        body:
            'Communication between the controller and tablet is abnormal. '
            'Please shut down the device, wait 10 seconds, then power on again. '
            'If the alarm persists after powering on, please contact after-sales service.',
        label: 'Controller–Tablet Communication Fault',
      ),
    );
    return catalog;
  }

  static const _entries = <(String, String)>[
    ('H001', 'Gun head communication'),
    ('H002', 'Sensor channel deviation'),
    ('H003', 'Static / quiescent current abnormal'),
    ('H004', 'Motor cable open circuit'),
    ('H005', 'Sensor abnormal'),
    ('H006', 'FLASH error'),
    ('H007', 'FLASH unencrypted'),
    ('H008', 'Gun motor over-temperature'),
    ('H009', 'Driver over-temperature'),
    ('H010', 'Protective lens over-temperature'),
    ('H011', 'Collimator / focus lens over-temperature'),
    ('H012', '24V undervoltage'),
    ('H013', 'Galvo motor overcurrent'),
    ('H014', 'Galvo motor trajectory abnormal'),
    ('H015', 'Galvo motor stall'),
    ('H016', 'MMI oscillator abnormal'),
    ('H017', 'Hardware bus error'),
    ('H018', 'Memory management abnormal'),
    ('H019', 'Memory access error'),
    ('H020', 'Illegal instruction'),
    ('H021', 'Watchdog reset'),
    ('H022', 'Laser communication'),
    ('H023', 'Laser current'),
    ('H024', 'Red-light current'),
    ('H025', 'Pump source voltage'),
    ('H026', 'Laser driver communication'),
    ('H027', 'AD feedback communication'),
    ('H028', 'Cold-water interlock'),
    ('H029', 'Laser emergency stop'),
    ('H030', 'Positioning light fault'),
    ('H031', 'Narrow-pulse protection'),
    ('H032', 'Driver board overvoltage'),
    ('H033', 'Environment temperature'),
    ('E006', 'Pump board over-temperature'),
    ('E008', 'Water temperature over limit'),
    ('E009', 'Fiber temperature over upper limit'),
    ('E010', 'Laser reflection energy over upper limit'),
    ('E011', 'Laser output energy under lower limit'),
    ('E012', 'Diode short-circuit fault'),
    ('E013', 'Fiber disconnected'),
    ('E014', 'Pump source temperature'),
    ('E015', 'Driver module over-temperature'),
    ('E016', 'Internal humidity over upper limit'),
    ('W001', 'Wire feeder communication'),
    ('W002', 'Wire feeder current'),
    ('A001', 'Blow / outlet gas pressure'),
  ];
}
