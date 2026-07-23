## ADDED Requirements

### Requirement: Advanced Settings numeric dialogs enforce supported ranges
Advanced Settings numeric parameter entry dialogs SHALL configure their input controls with the same supported minimum and maximum values used by validation for each setting. Stepper controls MUST NOT increase or decrease beyond the supported range for the edited setting.

#### Scenario: Stepper respects gas pressure range
- **WHEN** the operator opens Minimum Gas Pressure Threshold in Advanced Settings
- **THEN** the numeric dialog stepper MUST NOT allow values below 0
- **AND** MUST NOT allow values above the supported maximum for Minimum Gas Pressure Threshold

#### Scenario: Stepper respects temperature setting range
- **WHEN** the operator opens a temperature alarm setting in Advanced Settings
- **THEN** the numeric dialog stepper MUST use the supported displayed-unit range for that setting
- **AND** typed input validation MUST continue rejecting values outside that same range

## MODIFIED Requirements

### Requirement: Blow pressure threshold maximum is 500

The Advanced Settings validation for blow gas pressure threshold (`blowPressureThreshold`), displayed as Minimum Gas Pressure Threshold, SHALL accept values from 0 through 400 inclusive. Values above 400 MUST be rejected with the same user-facing validation flow as other out-of-range parameter edits.

#### Scenario: User enters 400

- **WHEN** the user enters blow pressure threshold `400`
- **THEN** validation MUST succeed
- **AND** the value MUST be persisted to `t_parameter_settings`

#### Scenario: User enters 401

- **WHEN** the user enters blow pressure threshold `401`
- **THEN** validation MUST fail
- **AND** the persisted value MUST remain unchanged
