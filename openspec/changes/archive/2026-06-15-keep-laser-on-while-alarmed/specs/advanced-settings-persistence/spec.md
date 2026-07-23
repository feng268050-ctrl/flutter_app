## MODIFIED Requirements

### Requirement: App-only advanced settings fields excluded from device writes

Fields in `t_advanced_settings` that have no Modbus register mapping—starting with `lensContaminationDetectionEnabled`, `zeroPointOffsetDetectionEnabled`, and the four dangerous-operations boolean fields (`keepLaserOnWhileAlarmed`, `allowWorkAfterCameraAlarm`, `allowWorkAfterGasAlarm`, `allowWorkAfterLensContamination`)—MUST NOT be included in Advanced Settings device write payloads built by `ModbusFiledBuilder` or equivalent write paths.

#### Scenario: Modbus payload omits AI assistance toggles

- **WHEN** the app builds an Advanced Settings Modbus write payload
- **THEN** the payload MUST NOT include `lensContaminationDetectionEnabled` or `zeroPointOffsetDetectionEnabled`
- **AND** existing mapped registers continue to use their current field sources

#### Scenario: Modbus payload omits dangerous operations toggles

- **WHEN** the app builds an Advanced Settings Modbus write payload
- **THEN** the payload MUST NOT include `keepLaserOnWhileAlarmed`, `allowWorkAfterCameraAlarm`, `allowWorkAfterGasAlarm`, or `allowWorkAfterLensContamination`

#### Scenario: AI assistance toggles excluded from remote snapshot

- **WHEN** the device sends `command.stat_response` or `device.online`
- **THEN** `lensContaminationDetectionEnabled` and `zeroPointOffsetDetectionEnabled` MUST NOT appear in the remote snapshot JSON

#### Scenario: Dangerous operations toggles excluded from remote snapshot

- **WHEN** the device sends `command.stat_response` or `device.online`
- **THEN** dangerous-operations toggle fields MUST NOT appear in the remote snapshot JSON

## ADDED Requirements

### Requirement: Keep laser on while alarmed persisted with safe default

The `t_advanced_settings` row SHALL include app-only field `keepLaserOnWhileAlarmed` (`INTEGER` boolean, default false). Fresh installs and migration from database version 48 SHALL default existing rows to false.

#### Scenario: Migration adds keep laser on while alarmed default off

- **WHEN** the app upgrades database from version 48 to 49
- **THEN** `t_advanced_settings` gains column `keepLaserOnWhileAlarmed` with value false for all existing rows

#### Scenario: Fresh install defaults keep laser on while alarmed off

- **WHEN** the app creates the default `t_advanced_settings` row on first access
- **THEN** `keepLaserOnWhileAlarmed` MUST be false
