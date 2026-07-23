## ADDED Requirements

### Requirement: Device parameters persisted in dedicated table

The app SHALL persist Advanced Settings device parameters in Room table `t_parameter_settings` via entity `ParameterSettings`. The table SHALL hold at most one application-active row using the same singleton selection pattern as the legacy advanced settings table.

The row SHALL include all device-parameter fields previously stored on `AdvancedSetting`, including at minimum:

- `zeroPointCorrection`, `properSwingWidth`
- `laserStartPower`, `laserEndPower`
- `blowPressureThreshold`
- `redLightOffset`
- `swingSpeedUpperLimit`, `swingSpeedLowerLimit`
- `manualWireFeedSpeed`, `manualDrawStringSpeed`
- `inletGasPressureThreshold`
- `driverTemperatureAlarmThreshold`, `protectiveLensTemperatureAlarmThreshold`, `collimatingLensTemperatureAlarmThreshold`, `motorTemperatureAlarmThreshold`
- `temperatureAlarmRecoveryInterval`

Language, unit, sound effect, and boot self-check fields MUST NOT be stored in `t_parameter_settings`.

#### Scenario: Fresh install parameter defaults

- **WHEN** no row exists in `t_parameter_settings` on first access
- **THEN** the app MUST insert defaults consistent with `DefaultValueUtils.createDefaultAdvancedSetting()` for all parameter columns (excluding migrated preference columns)

#### Scenario: Parameter edit persists to parameter table

- **WHEN** the user saves a valid device parameter on the Advanced Settings page
- **THEN** the value MUST be written to `t_parameter_settings`
- **AND** MUST NOT be written to `t_common_settings`

### Requirement: Legacy advanced-setting parameter columns migrate to parameter settings

On database upgrade, when legacy table `t_advanced_setting` contains a row, the migration SHALL copy all device-parameter columns listed in the parameter-settings requirement into `t_parameter_settings`, preserving numeric values.

Preference columns (`languageSetting`, `unitSetting`, `voiceCheck`, `showBootSelfCheck`) MUST NOT be copied into `t_parameter_settings`.

#### Scenario: Existing device upgrades preserve laser power

- **WHEN** legacy row has `laserStartPower` 15 and `laserEndPower` 20
- **THEN** migrated `t_parameter_settings` MUST have `laserStartPower` 15 and `laserEndPower` 20

### Requirement: Blow pressure threshold maximum is 500

The Advanced Settings validation for blow gas pressure threshold (`blowPressureThreshold`) SHALL accept values from 0 through 500 inclusive. Values above 500 MUST be rejected with the same user-facing validation flow as other out-of-range parameter edits.

#### Scenario: User enters 500

- **WHEN** the user enters blow pressure threshold `500`
- **THEN** validation MUST succeed
- **AND** the value MUST be persisted to `t_parameter_settings`

#### Scenario: User enters 501

- **WHEN** the user enters blow pressure threshold `501`
- **THEN** validation MUST fail
- **AND** the persisted value MUST remain unchanged

### Requirement: Parameter settings excluded from remote snapshot

Device parameters in `t_parameter_settings` MUST NOT be serialized into `command.stat_response` or `device.online` remote snapshots. Remote consumers MUST obtain parameter state through other channels if needed; this change does not add a replacement snapshot field for parameters.

#### Scenario: Stat response has no parameter blob

- **WHEN** the device sends `command.stat_response`
- **THEN** `payload.data` MUST NOT include `advancedSettings`
- **AND** MUST NOT include a root-level object exposing `blowPressureThreshold`, `laserStartPower`, or other parameter-settings fields outside `processParameters`
