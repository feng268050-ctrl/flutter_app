## ADDED Requirements

### Requirement: Device Information shows focus scale reference

Settings Device Information SHALL display a **Focus Scale Reference** row whose value is the effective signed integer returned by `DeviceModelConfig.getFocusScaleRef()`.

The displayed value MUST use the same runtime semantics as the ROM model configuration: valid positive, zero, and negative values are shown as their decimal string form, and missing, empty, or invalid ROM values are shown as `0`.

#### Scenario: Valid ROM value is displayed

- **WHEN** `/system/etc/model.properties` contains `focus_scale_ref=-3`
- **AND** the user opens Settings Device Information
- **THEN** the Focus Scale Reference row MUST display `-3`

#### Scenario: Missing ROM value displays default

- **WHEN** `/system/etc/model.properties` does not contain a valid `focus_scale_ref`
- **AND** the user opens Settings Device Information
- **THEN** the Focus Scale Reference row MUST display `0`

#### Scenario: Display value uses existing config source

- **WHEN** `DeviceModelConfig.getFocusScaleRef()` returns `5`
- **AND** the Device Information data model is assembled
- **THEN** the Focus Scale Reference value exposed for data binding MUST be `5`
