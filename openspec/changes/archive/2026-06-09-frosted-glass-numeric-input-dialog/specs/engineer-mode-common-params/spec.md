## MODIFIED Requirements

### Requirement: Engineer mode text-input prompts use FrostedGlassDialog

Text-input prompts for commonly-used process parameter name and welding material name in engineer mode SHALL use `FrostedGlassDialog` with a shared text-input custom body. Numeric parameter entry dialogs in engineer mode SHALL use `FrostedGlassNumericInputDialog` with the shared numeric custom body.

#### Scenario: Parameter name on FrostedGlass

- **WHEN** the user edits a commonly-used process parameter name
- **THEN** the input dialog MUST use `FrostedGlassDialog` instead of `InputDialogFragment` window chrome
- **AND** validation rules for empty and max-length names MUST be preserved

#### Scenario: Material name on FrostedGlass

- **WHEN** the user edits welding material name text
- **THEN** the input dialog MUST use `FrostedGlassDialog`
- **AND** material validation via `EngineerDataCheck` MUST be preserved

#### Scenario: Numeric process parameter on FrostedGlass

- **WHEN** the user edits any numeric engineer-mode process field opened via `InputDialogBuilder` (for example laser power, swing width, or spot welding interval)
- **THEN** the input dialog MUST use `FrostedGlassNumericInputDialog` on the FrostedGlass shell
- **AND** MUST NOT use `InputDialogFragment`
- **AND** field validation via `EngineerDataCheck` and ViewModel updates MUST be preserved
