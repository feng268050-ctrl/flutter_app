## ADDED Requirements

### Requirement: Engineer mode text-input prompts use FrostedGlassDialog

Text-input prompts for commonly-used process parameter name and welding material name in engineer mode SHALL use `FrostedGlassDialog` with a shared text-input custom body. Numeric parameter entry dialogs MUST remain on `InputDialogFragment` and are out of scope for this change.

#### Scenario: Parameter name on FrostedGlass

- **WHEN** the user edits a commonly-used process parameter name
- **THEN** the input dialog MUST use `FrostedGlassDialog` instead of `InputDialogFragment` window chrome
- **AND** validation rules for empty and max-length names MUST be preserved

#### Scenario: Material name on FrostedGlass

- **WHEN** the user edits welding material name text
- **THEN** the input dialog MUST use `FrostedGlassDialog`
- **AND** material validation via `EngineerDataCheck` MUST be preserved
