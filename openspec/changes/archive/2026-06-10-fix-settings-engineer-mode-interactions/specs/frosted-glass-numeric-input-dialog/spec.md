## MODIFIED Requirements

### Requirement: Numeric parameter input uses FrostedGlassNumericInputDialog

Engineer-mode and Advanced Settings numeric parameter entry dialogs SHALL use `FrostedGlassNumericInputDialog` mounted on `FrostedGlassDialog.prompt(...).customBodyView(...)` with shared body layout `frosted_glass_body_numeric_input.xml`. The wrapper MUST preserve pre-migration validation, confirm/cancel semantics, default value formatting, optional description text, optional ± stepper controls, min/max stepper clamping, and title-with-unit formatting.

#### Scenario: Integer parameter entry on FrostedGlass

- **WHEN** the operator opens a numeric process parameter dialog configured for integer input (for example spot welding interval)
- **THEN** the dialog MUST render inside `FrostedGlassDialog` with a numeric EditText in the custom body slot
- **AND** confirming with a valid value MUST invoke the same validation callback and dismiss the overlay
- **AND** confirming with an invalid value MUST keep the overlay open with the same rejection behavior as before migration

#### Scenario: Decimal parameter entry with stepper

- **WHEN** the operator opens a decimal numeric dialog with stepper enabled (for example welding thickness)
- **THEN** the body MUST show ± controls that adjust the value by 0.1 per tap
- **AND** the displayed value MUST respect the same min/max clamping as `InputDialogFragment`

#### Scenario: Signed integer entry in advanced settings

- **WHEN** the operator edits a signed-integer advanced setting (for example zero point correction)
- **THEN** the dialog MUST accept only valid signed integer input
- **AND** validation and persistence MUST remain equivalent to the pre-migration `SettingInputDialogBuilder` behavior

#### Scenario: Advanced Settings stepper clamps to configured setting range

- **WHEN** an Advanced Settings numeric dialog is configured with a minimum and maximum value
- **THEN** tapping the decrement control at the minimum MUST keep the displayed input at the minimum
- **AND** tapping the increment control at the maximum MUST keep the displayed input at the maximum

#### Scenario: Engineer Mode title keeps visible label and unit

- **WHEN** the operator opens an Engineer Mode numeric parameter dialog for a field that has a unit
- **THEN** the dialog title MUST include the same label text displayed for that field on the Engineer Mode screen
- **AND** MUST continue to show the unit using the existing title-with-unit format
