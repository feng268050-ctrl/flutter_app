import 'package:cyber_alarm/cyber_alarm.dart';

/// Product seed for [AlarmCodeCatalog] (join keys match `modbus.json` meta
/// where present; non-Modbus codes mirror lws-ui `AlarmCodeEnums` for demo /
/// future adapters).
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
      case 'A':
      case 'X':
        return AlarmSeverity.medium;
      case 'L':
      case 'C':
        return AlarmSeverity.high;
      default:
        return AlarmSeverity.unknown;
    }
  }

  /// Full product catalog for warn dialogs + `make alarm CODE=…`.
  static AlarmCodeCatalog seed() {
    final catalog = AlarmCodeCatalog();
    for (final e in _modbusAligned) {
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
    for (final e in _nonModbusAligned) {
      catalog.add(
        AlarmCodeEntry(
          code: e.code,
          severity: severityFor(e.code),
          title: e.title,
          body: e.body,
          label: e.title,
        ),
      );
    }
    return catalog;
  }

  /// Codes with `meta.alarm_code` in `assets/hal/modbus.json` (short labels).
  static const _modbusAligned = <(String, String)>[
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

  /// Non-Modbus (or not yet mapped) codes from lws-ui `AlarmCodeEnums`.
  ///
  /// Copy aligned with lws-ui `values/strings.xml`. Signal adapters may land
  /// later; catalog entries enable `make alarm` / future sources today.
  static const _nonModbusAligned = <_CatalogCopy>[
    _CatalogCopy(
      code: 'H034',
      title: 'Zero Point Offset Alarm',
      body: 'Zero offset is off center — please correct it promptly.',
    ),
    _CatalogCopy(
      code: 'L001',
      title: 'Lens Contamination Alarm',
      body:
          'Protective lens is heavily contaminated; clean or replace the '
          'protective lens.',
    ),
    _CatalogCopy(
      code: 'C001',
      title: 'Controller–Tablet Communication Fault',
      body:
          'Communication between the controller and tablet is abnormal. '
          'Please shut down the device, wait 10 seconds, then power on again. '
          'If the alarm persists after powering on, please contact after-sales '
          'service.',
    ),
    _CatalogCopy(
      code: 'C002',
      title: 'Camera Communication Alarm',
      body:
          'Communication with the built-in camera is abnormal. Please shut '
          'down the device, wait 10 seconds, then power on again. If the alarm '
          'persists after powering on, please contact after-sales service.',
    ),
    _CatalogCopy(
      code: 'C003',
      title: 'Main Controller–Temperature Board Communication Fault',
      body:
          'Communication between the main controller and temperature-control '
          'board is abnormal. Please shut down the device, wait 10 seconds, '
          'then power on again. If the alarm persists after powering on, please '
          'contact after-sales service.',
    ),
    _CatalogCopy(
      code: 'C004',
      title: 'Temperature Board–Refrigeration Communication Fault',
      body:
          'Communication between the temperature-control board and '
          'refrigeration system is abnormal. Please shut down the device, wait '
          '10 seconds, then power on again. If the alarm persists after '
          'powering on, please contact after-sales service.',
    ),
    // Clearance / recovery titles (lws-ui X* codes) — demo parity only.
    _CatalogCopy(
      code: 'X006',
      title: 'Pump module over-temperature cleared',
      body: 'Please contact Cyber after-sales if the issue persists.',
    ),
    _CatalogCopy(
      code: 'X008',
      title: 'Water temperature limit cleared',
      body: 'Please contact Cyber after-sales if the issue persists.',
    ),
    _CatalogCopy(
      code: 'X009',
      title: 'Fiber temperature upper limit cleared',
      body: 'Please contact Cyber after-sales if the issue persists.',
    ),
    _CatalogCopy(
      code: 'X010',
      title: 'Laser reflected energy upper limit cleared',
      body: 'Please contact Cyber after-sales if the issue persists.',
    ),
    _CatalogCopy(
      code: 'X011',
      title: 'Laser output energy lower limit cleared',
      body: 'Please contact Cyber after-sales if the issue persists.',
    ),
    _CatalogCopy(
      code: 'X012',
      title: 'Diode short-circuit error cleared',
      body: 'Please contact Cyber after-sales if the issue persists.',
    ),
    _CatalogCopy(
      code: 'X013',
      title: 'Fiber disconnection cleared',
      body: 'Please contact Cyber after-sales if the issue persists.',
    ),
  ];
}

final class _CatalogCopy {
  const _CatalogCopy({
    required this.code,
    required this.title,
    required this.body,
  });

  final String code;
  final String title;
  final String body;
}
