# frosted-glass-numeric-input-dialog Specification

## Purpose
TBD - created by archiving change frosted-glass-numeric-input-dialog. Update Purpose after archive.
## Requirements
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

### Requirement: Soft keyboard MUST NOT compress background content

While a `FrostedGlassNumericInputDialog` overlay is visible and the soft keyboard is shown, the host Activity background content MUST NOT be resized or vertically compressed by IME layout adjustment.

#### Scenario: Keyboard open preserves background layout height

- **WHEN** the numeric input overlay is showing and the soft keyboard opens
- **THEN** the host Activity content root MUST retain its pre-keyboard layout height
- **AND** the frosted-glass card MUST remain usable (translated or inset-adjusted) without shrinking the underlying engineer or settings page

#### Scenario: Keyboard dismiss restores host window state

- **WHEN** the numeric input overlay is dismissed after the soft keyboard was visible
- **THEN** the host Activity `softInputMode` MUST be restored to its pre-overlay value
- **AND** IME insets MUST be cleared so no residual blank space remains below the background UI

### Requirement: Builder call sites use direct show without DialogFragment

`InputDialogBuilder` and `SettingInputDialogBuilder` numeric builder methods MUST invoke `FrostedGlassNumericInputDialog.show(...)` directly and MUST NOT return or display `InputDialogFragment` via `FragmentManager`.

#### Scenario: Engineer mode fragment opens thickness dialog

- **WHEN** the operator taps welding thickness in engineer mode
- **THEN** `InputDialogBuilder.thicknessBuilder(...)` MUST show the FrostedGlass numeric dialog without `FragmentManager.show()`
- **AND** the thickness validation via `EngineerDataCheck` MUST be preserved

### Requirement: Numeric input dialog EditText uses JetBrains Mono

Frosted Glass numeric input dialogs that host the custom IME for `ImeFieldType.Number` or `SignedDecimal` SHALL apply JetBrains Mono Medium to the input `EditText`.

#### Scenario: Numeric parameter entry

- **WHEN** `FrostedGlassNumericInputDialog` is shown
- **THEN** digits, decimal point, and minus sign in the EditText MUST render in JetBrains Mono

