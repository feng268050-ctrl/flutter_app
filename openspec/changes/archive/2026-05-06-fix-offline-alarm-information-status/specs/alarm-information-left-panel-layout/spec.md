## MODIFIED Requirements

### Requirement: Alarm bindings and behavior unchanged

The layout SHALL preserve existing data binding expressions, checkbox enabled flags, and online alarm/value semantics for all alarm tiles. The checked state logic SHALL additionally gate normal/healthy evaluation on device readiness, so no tile can present healthy state before valid controller status/data is available.

#### Scenario: No logic regression when ready

- **WHEN** device status and device data are ready and update on the Alarm Information screen
- **THEN** each tile SHALL continue to reflect the same alarm and value semantics as before the readiness gating change.

#### Scenario: Prevent false healthy state before readiness

- **WHEN** the Alarm Information screen is shown while lower-controller status/data is not yet ready
- **THEN** tile check indicators SHALL remain unchecked and SHALL NOT evaluate to healthy state from default status values.
