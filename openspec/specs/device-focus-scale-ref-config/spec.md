# device-focus-scale-ref-config Specification

## Purpose
TBD - created by archiving change add-focus-scale-ref. Update Purpose after archive.
## Requirements
### Requirement: ROM model.properties SHALL declare focus_scale_ref

The file `/system/etc/model.properties` SHALL support optional integer property `focus_scale_ref` (signed integer, e.g. `-3`, `0`, `7`).

When the key is absent, empty, or not parseable as a signed integer, the App MUST treat the device as **`0`**.

#### Scenario: Missing key defaults to zero

- **WHEN** `model.properties` exists but has no `focus_scale_ref` key
- **THEN** `DeviceModelConfig.getFocusScaleRef()` MUST return `0`

#### Scenario: Valid positive value loads

- **WHEN** `model.properties` contains `focus_scale_ref=5`
- **THEN** `DeviceModelConfig.getFocusScaleRef()` MUST return `5`

#### Scenario: Valid negative value loads

- **WHEN** `model.properties` contains `focus_scale_ref=-2`
- **THEN** `DeviceModelConfig.getFocusScaleRef()` MUST return `-2`

#### Scenario: Invalid value falls back with warning

- **WHEN** `model.properties` contains `focus_scale_ref=abc`
- **THEN** `DeviceModelConfig.getFocusScaleRef()` MUST return `0`
- **AND** the App MUST log a warning that the value was invalid

### Requirement: DeviceModelConfig SHALL expose focus scale reference

The App SHALL load `focus_scale_ref` once at startup (same lifecycle as other `DeviceModelConfig` keys) and expose `DeviceModelConfig.getFocusScaleRef()` returning an `int`.

#### Scenario: Preload loads focus scale ref before laser enable

- **WHEN** `LaserApplication` calls `DeviceModelConfig.preload()`
- **THEN** subsequent `getFocusScaleRef()` MUST not block on file I/O
- **AND** MUST reflect the ROM value or default `0`

### Requirement: Device Information shows focus scale reference
Settings Device Information SHALL display a **Focus Scale Reference** row in the third untitled Device Information group. The row value SHALL be the effective signed integer returned by `DeviceModelConfig.getFocusScaleRef()`.

The displayed value MUST use the same runtime semantics as the ROM model configuration: valid positive, zero, and negative values are shown as their decimal string form, and missing, empty, or invalid ROM values are shown as `0`.

#### Scenario: Valid ROM value is displayed
- **WHEN** `/system/etc/model.properties` contains `focus_scale_ref=-3`
- **AND** the user opens Settings Device Information
- **THEN** the Focus Scale Reference row MUST display `-3`
- **AND** the row appears in the third untitled Device Information group

#### Scenario: Missing ROM value displays default
- **WHEN** `/system/etc/model.properties` does not contain a valid `focus_scale_ref`
- **AND** the user opens Settings Device Information
- **THEN** the Focus Scale Reference row MUST display `0`
- **AND** the row appears in the third untitled Device Information group

#### Scenario: Display value uses existing config source
- **WHEN** `DeviceModelConfig.getFocusScaleRef()` returns `5`
- **AND** the Device Information data model is assembled
- **THEN** the Focus Scale Reference value exposed for data binding MUST be `5`

