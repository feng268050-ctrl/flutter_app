## MODIFIED Requirements

### Requirement: Advanced settings persisted in dedicated table

The app SHALL persist Advanced Settings page state in Room table `t_advanced_settings` via entity `AdvancedSettings`. The table SHALL hold at most one application-active row using the same singleton selection pattern as the legacy advanced settings and parameter settings tables.

The row SHALL include Modbus-backed device parameters:

| Field | Type | Semantics |
|-------|------|-----------|
| `zeroPointCorrection` | `REAL` | Zero Offset |
| `properSwingWidth` | `REAL` | Scan Width Correction |
| `laserStartPower` | `REAL` | Laser Starting Power |
| `laserEndPower` | `REAL` | Laser Termination Power |
| `blowPressureThreshold` | `REAL` | Minimum Gas Pressure Threshold |
| `inletGasPressureThreshold` | `INTEGER` | Minimum Gas Pressure Threshold register value when required by the existing device protocol |
| `driverTemperatureAlarmThreshold` | `REAL` | Driver Temperature Alarm Threshold |
| `protectiveLensTemperatureAlarmThreshold` | `REAL` | Protective Lens Temperature Alarm Threshold |
| `collimatingLensTemperatureAlarmThreshold` | `REAL` | Collimating Lens Temperature Alarm Threshold |
| `motorTemperatureAlarmThreshold` | `REAL` | Motor Temperature Alarm Threshold |
| `temperatureAlarmRecoveryInterval` | `REAL` | Temperature Alarm Recovery Interval |

The row SHALL also include app-only Advanced Settings fields that are **not** written to Modbus:

| Field | Type | Semantics |
|-------|------|-----------|
| `lensContaminationDetectionEnabled` | `INTEGER` (boolean) | Whether live-weld lens contamination AI assistance runs during laser-on sessions |
| `zeroPointOffsetDetectionEnabled` | `INTEGER` (boolean) | Whether laser-on zero-point offset AI assistance runs during laser-on sessions |
| `allowWorkAfterCameraAlarm` | `INTEGER` (boolean) | Whether laser enable bypasses active C002 camera communication blocking |
| `allowWorkAfterGasAlarm` | `INTEGER` (boolean) | Whether laser enable bypasses active A001 shielding gas blocking |
| `allowWorkAfterLensContamination` | `INTEGER` (boolean) | Whether laser enable bypasses active L001 heavy contamination blocking |

Not every column in `t_advanced_settings` maps to a device register. App-only fields MUST be excluded from Advanced Settings Modbus write payloads.

Language, unit, sound effect, boot self-check, network, display, and date/time fields MUST NOT be stored in `t_advanced_settings`.

#### Scenario: Fresh install advanced settings defaults

- **WHEN** no row exists in `t_advanced_settings` on first access
- **THEN** the app inserts a default row consistent with the existing Advanced Settings parameter defaults
- **AND** `lensContaminationDetectionEnabled` and `zeroPointOffsetDetectionEnabled` default to true
- **AND** `allowWorkAfterCameraAlarm`, `allowWorkAfterGasAlarm`, and `allowWorkAfterLensContamination` default to false
- **AND** Common Settings preferences are not inserted into `t_advanced_settings`

#### Scenario: Parameter edit persists to advanced settings table

- **WHEN** the user saves a valid Advanced Settings parameter, AI assistance toggle, or dangerous-operations toggle
- **THEN** the value is written to `t_advanced_settings`
- **AND** the value is not written to `t_common_settings` for AI assistance or dangerous-operations toggles
- **AND** the app does not write active parameter data to `t_parameter_settings`

#### Scenario: AI assistance toggle does not trigger Modbus write

- **WHEN** the user changes Lens Contamination Detection or Zero Point Offset Detection
- **THEN** only `t_advanced_settings` is updated for that change
- **AND** the Advanced Settings Modbus write payload is not sent solely because the toggle changed

#### Scenario: Dangerous operations toggle does not trigger Modbus write

- **WHEN** the user changes any Dangerous Operations toggle
- **THEN** only `t_advanced_settings` is updated for that change
- **AND** the Advanced Settings Modbus write payload is not sent solely because the toggle changed

## MODIFIED Requirements

### Requirement: App-only advanced settings fields excluded from device writes

Fields in `t_advanced_settings` that have no Modbus register mapping—starting with `lensContaminationDetectionEnabled`, `zeroPointOffsetDetectionEnabled`, and the three dangerous-operations boolean fields—MUST NOT be included in Advanced Settings device write payloads built by `ModbusFiledBuilder` or equivalent write paths.

#### Scenario: Modbus payload omits AI assistance toggles

- **WHEN** the app builds an Advanced Settings Modbus write payload
- **THEN** the payload MUST NOT include `lensContaminationDetectionEnabled` or `zeroPointOffsetDetectionEnabled`
- **AND** existing mapped registers continue to use their current field sources

#### Scenario: Modbus payload omits dangerous operations toggles

- **WHEN** the app builds an Advanced Settings Modbus write payload
- **THEN** the payload MUST NOT include `allowWorkAfterCameraAlarm`, `allowWorkAfterGasAlarm`, or `allowWorkAfterLensContamination`

#### Scenario: AI assistance toggles excluded from remote snapshot

- **WHEN** the device sends `command.stat_response` or `device.online`
- **THEN** `lensContaminationDetectionEnabled` and `zeroPointOffsetDetectionEnabled` MUST NOT appear in the remote snapshot JSON

#### Scenario: Dangerous operations toggles excluded from remote snapshot

- **WHEN** the device sends `command.stat_response` or `device.online`
- **THEN** dangerous-operations toggle fields MUST NOT appear in the remote snapshot JSON
