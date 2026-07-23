## MODIFIED Requirements

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

## ADDED Requirements

### Requirement: Allow work after feeder alarm persisted with safe default

The `t_advanced_settings` row SHALL include app-only field `allowWorkAfterFeederAlarm` (`INTEGER` boolean, default false). Fresh installs and migration from database version 50 SHALL default existing rows to false.

#### Scenario: Migration adds allow work after feeder alarm default off

- **WHEN** the app upgrades database from version 50 to 51
- **THEN** `t_advanced_settings` gains column `allowWorkAfterFeederAlarm` with value false for all existing rows

#### Scenario: Fresh install defaults allow work after feeder alarm off

- **WHEN** the app creates the default `t_advanced_settings` row on first access
- **THEN** `allowWorkAfterFeederAlarm` MUST be false
