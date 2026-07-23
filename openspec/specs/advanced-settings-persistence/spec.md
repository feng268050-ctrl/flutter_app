# advanced-settings-persistence Specification

## Purpose
TBD - created by archiving change refactor-welder-app-settings-page. Update Purpose after archive.
## Requirements
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

Not every column in `t_advanced_settings` maps to a device register. App-only fields MUST be excluded from Advanced Settings Modbus write payloads.

Language, unit, sound effect, boot self-check, network, display, and date/time fields MUST NOT be stored in `t_advanced_settings`.

#### Scenario: Fresh install advanced settings defaults

- **WHEN** no row exists in `t_advanced_settings` on first access
- **THEN** the app inserts a default row consistent with the existing Advanced Settings parameter defaults
- **AND** `lensContaminationDetectionEnabled` and `zeroPointOffsetDetectionEnabled` default to true
- **AND** Common Settings preferences are not inserted into `t_advanced_settings`

#### Scenario: Parameter edit persists to advanced settings table

- **WHEN** the user saves a valid Advanced Settings parameter or AI assistance toggle
- **THEN** the value is written to `t_advanced_settings`
- **AND** the value is not written to `t_common_settings` for AI assistance toggles
- **AND** the app does not write active parameter data to `t_parameter_settings`

#### Scenario: AI assistance toggle does not trigger Modbus write

- **WHEN** the user changes Lens Contamination Detection or Zero Point Offset Detection
- **THEN** only `t_advanced_settings` is updated for that change
- **AND** the Advanced Settings Modbus write payload is not sent solely because the toggle changed

### Requirement: Parameter settings migrate to advanced settings
On database upgrade, when legacy table `t_parameter_settings` contains a row, the migration SHALL copy supported device-parameter columns into `t_advanced_settings`, preserving numeric values.

#### Scenario: Existing device upgrades with threshold values
- **WHEN** `t_parameter_settings` contains `laserStartPower` 15, `laserEndPower` 20, and `blowPressureThreshold` 300
- **THEN** migrated `t_advanced_settings` contains `laserStartPower` 15, `laserEndPower` 20, and `blowPressureThreshold` 300

#### Scenario: Existing device upgrades with temperature values
- **WHEN** `t_parameter_settings` contains motor, driver, protective lens, collimating lens, and recovery interval values
- **THEN** migrated `t_advanced_settings` preserves those values in the matching columns

### Requirement: Advanced settings numeric validation is preserved
Advanced Settings numeric parameter entry dialogs SHALL enforce the same supported minimum and maximum values used by validation for each setting. Stepper controls MUST NOT increase or decrease beyond the supported range for the edited setting.

Minimum Gas Pressure Threshold SHALL accept values from 0 through 400 inclusive. Values above 400 MUST be rejected with the same user-facing validation flow as other out-of-range parameter edits.

#### Scenario: Stepper respects gas pressure range
- **WHEN** the operator opens Minimum Gas Pressure Threshold in Advanced Settings
- **THEN** the numeric dialog stepper does not allow values below 0
- **AND** does not allow values above 400

#### Scenario: User enters gas pressure above range
- **WHEN** the user enters Minimum Gas Pressure Threshold `401`
- **THEN** validation fails
- **AND** the persisted value in `t_advanced_settings` remains unchanged

#### Scenario: Stepper respects temperature setting range
- **WHEN** the operator opens a temperature alarm setting in Advanced Settings
- **THEN** the numeric dialog stepper uses the supported displayed-unit range for that setting
- **AND** typed input validation rejects values outside that same range

### Requirement: Advanced settings sliders update value boxes while dragging
Advanced Settings parameter sliders SHALL update the paired value box in the same card in real time while the operator drags the thumb. The app SHALL update in-memory parameter values during the drag and SHALL persist to `t_advanced_settings` and send device register writes only after the drag ends.

#### Scenario: Dragging zero offset updates the value box immediately
- **WHEN** the operator drags the Zero Offset slider
- **THEN** the Zero Offset value box updates on each thumb movement
- **AND** the persisted value and Modbus write occur after the operator releases the slider

#### Scenario: Dragging a temperature threshold updates the displayed unit value immediately
- **WHEN** the operator drags a temperature alarm threshold slider
- **THEN** the paired value box updates on each thumb movement using the current Common Settings unit
- **AND** the persisted Celsius value and Modbus write occur after the operator releases the slider

### Requirement: Advanced settings excluded from remote snapshot
Device parameters in `t_advanced_settings` MUST NOT be serialized into `command.stat_response` or `device.online` remote snapshots. Remote consumers MUST obtain parameter state through other channels if needed; this change does not add a replacement snapshot field for Advanced Settings parameters.

#### Scenario: Stat response has no advanced settings parameter blob
- **WHEN** the device sends `command.stat_response`
- **THEN** `payload.data` does not include `advancedSettings`
- **AND** it does not include a root-level object exposing `blowPressureThreshold`, `laserStartPower`, or other Advanced Settings fields outside `processParameters`

### Requirement: App-only advanced settings fields excluded from device writes

Fields in `t_advanced_settings` that have no Modbus register mapping—starting with `lensContaminationDetectionEnabled`, `zeroPointOffsetDetectionEnabled`, and the five dangerous-operations boolean fields (`keepLaserOnWhileAlarmed`, `allowWorkAfterCameraAlarm`, `allowWorkAfterGasAlarm`, `allowWorkAfterLensContamination`, `allowWorkAfterFeederAlarm`)—MUST NOT be included in Advanced Settings device write payloads built by `ModbusFiledBuilder` or equivalent write paths.

#### Scenario: Modbus payload omits AI assistance toggles

- **WHEN** the app builds an Advanced Settings Modbus write payload
- **THEN** the payload MUST NOT include `lensContaminationDetectionEnabled` or `zeroPointOffsetDetectionEnabled`
- **AND** existing mapped registers continue to use their current field sources

#### Scenario: Modbus payload omits dangerous operations toggles

- **WHEN** the app builds an Advanced Settings Modbus write payload
- **THEN** the payload MUST NOT include `keepLaserOnWhileAlarmed`, `allowWorkAfterCameraAlarm`, `allowWorkAfterGasAlarm`, `allowWorkAfterLensContamination`, or `allowWorkAfterFeederAlarm`

#### Scenario: AI assistance toggles excluded from remote snapshot

- **WHEN** the device sends `command.stat_response` or `device.online`
- **THEN** `lensContaminationDetectionEnabled` and `zeroPointOffsetDetectionEnabled` MUST NOT appear in the remote snapshot JSON

#### Scenario: Dangerous operations toggles excluded from remote snapshot

- **WHEN** the device sends `command.stat_response` or `device.online`
- **THEN** dangerous-operations toggle fields MUST NOT appear in the remote snapshot JSON

### Requirement: Keep laser on while alarmed persisted with safe default

The `t_advanced_settings` row SHALL include app-only field `keepLaserOnWhileAlarmed` (`INTEGER` boolean, default false). Fresh installs and migration from database version 48 SHALL default existing rows to false.

#### Scenario: Migration adds keep laser on while alarmed default off

- **WHEN** the app upgrades database from version 48 to 49
- **THEN** `t_advanced_settings` gains column `keepLaserOnWhileAlarmed` with value false for all existing rows

#### Scenario: Fresh install defaults keep laser on while alarmed off

- **WHEN** the app creates the default `t_advanced_settings` row on first access
- **THEN** `keepLaserOnWhileAlarmed` MUST be false

### Requirement: Allow work after feeder alarm persisted with safe default

The `t_advanced_settings` row SHALL include app-only field `allowWorkAfterFeederAlarm` (`INTEGER` boolean, default false). Fresh installs and migration from database version 50 SHALL default existing rows to false.

#### Scenario: Migration adds allow work after feeder alarm default off

- **WHEN** the app upgrades database from version 50 to 51
- **THEN** `t_advanced_settings` gains column `allowWorkAfterFeederAlarm` with value false for all existing rows

#### Scenario: Fresh install defaults allow work after feeder alarm off

- **WHEN** the app creates the default `t_advanced_settings` row on first access
- **THEN** `allowWorkAfterFeederAlarm` MUST be false

