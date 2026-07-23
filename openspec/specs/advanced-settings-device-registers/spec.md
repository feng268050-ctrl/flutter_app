## Purpose

Define Advanced Settings device register exposure, Modbus write behavior, scrollable layout, and Sound Effect placement for registers 0x009A through 0x009F.
## Requirements
### Requirement: Advanced Settings exposes registers 0x009A through 0x009F
The Advanced Settings page SHALL provide configurable controls for device setting registers 0x009A through 0x009F: inlet gas pressure threshold, driver temperature alarm threshold, protective lens temperature alarm threshold, collimating/focusing lens temperature alarm threshold, motor temperature alarm threshold, and temperature alarm recovery interval. Persisted values MUST be read from and written to `t_advanced_settings`.

#### Scenario: User views new device setting controls
- **WHEN** the user opens Settings and navigates to Advanced Settings
- **THEN** the page displays controls for all six registers from 0x009A through 0x009F
- **AND** the controls use localized labels consistent with the rest of the Advanced Settings page

#### Scenario: User edits a new device setting
- **WHEN** the user taps a 0x009A-0x009F setting value and enters a valid value
- **THEN** the setting is updated in the page data
- **AND** the value is persisted in `t_advanced_settings`
- **AND** the updated device setting payload is sent to the device

#### Scenario: User enters an invalid value
- **WHEN** the user enters a value outside the allowed range for a 0x009A-0x009F setting
- **THEN** the page rejects the value
- **AND** the persisted setting and device payload remain unchanged for that edit

### Requirement: Device setting writes include registers 0x009A through 0x009F
The system SHALL include registers 0x009A through 0x009F in Advanced Settings device write payloads using the same write flow as existing device settings. Persisted values MUST be read from `t_advanced_settings`.

#### Scenario: Advanced Settings payload is built
- **WHEN** the app builds an Advanced Settings Modbus write payload
- **THEN** the payload includes register addresses 0x009A, 0x009B, 0x009C, 0x009D, 0x009E, and 0x009F
- **AND** each register uses the current value from `t_advanced_settings` or the default value when no persisted value exists

#### Scenario: Existing device settings still write
- **WHEN** a user changes any existing Advanced Settings device parameter
- **THEN** the existing register writes from 0x0090 through 0x0099 remain present and preserve their current behavior
- **AND** the new register writes from 0x009A through 0x009F are included in the same payload
- **AND** all register values are sourced from `t_advanced_settings`

### Requirement: Advanced Settings content remains reachable
The Advanced Settings page SHALL support scrolling when its content is taller than the available viewport.

#### Scenario: Content exceeds one screen
- **WHEN** the Advanced Settings controls do not fit on one screen
- **THEN** the user can scroll the page to reach every setting
- **AND** no setting is clipped or unreachable at the bottom of the page

### Requirement: Sound Effect has a dedicated row after Unit
The Advanced Settings page SHALL place Sound Effect on the row immediately after the Unit row, and that row SHALL contain only Sound Effect.

#### Scenario: User views Sound Effect placement
- **WHEN** the user opens Advanced Settings
- **THEN** Sound Effect appears below the Language and Unit row
- **AND** no other setting appears on the same row as Sound Effect

#### Scenario: User changes Sound Effect
- **WHEN** the user selects a Sound Effect option
- **THEN** the app preserves the existing sound preview behavior
- **AND** the selection is persisted to `t_common_settings.soundEffect`
- **AND** no Modbus device setting write is sent only because the Sound Effect option changed

### Requirement: Advanced Settings register rows follow requested groups
Advanced Settings SHALL organize device-register-backed rows into the requested parameter groups while preserving write behavior for each register.

#### Scenario: Temperature threshold registers are grouped
- **WHEN** the user opens Advanced Settings
- **THEN** Motor Temperature Alarm Threshold, Driver Temperature Alarm Threshold, Protective Lens Temperature Alarm Threshold, Collimating Lens Temperature Alarm Threshold, and Temperature Alarm Recovery Interval appear in the Temperature Thresholds group
- **AND** editing any row still writes the corresponding device register payload

#### Scenario: Power threshold registers are grouped
- **WHEN** the user opens Advanced Settings
- **THEN** Laser Starting Power, Laser Termination Power, and Minimum Gas Pressure Threshold appear in the Power Thresholds group
- **AND** editing any row still writes the corresponding device register payload

