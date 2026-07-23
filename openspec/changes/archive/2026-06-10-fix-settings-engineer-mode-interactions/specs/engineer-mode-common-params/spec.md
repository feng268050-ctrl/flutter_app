## ADDED Requirements

### Requirement: Material Type selector opens aligned with field
Engineer Mode Material Type selector popups SHALL open aligned to the Material Type field anchor and MUST NOT be vertically shifted downward from the field by an unintended offset. The selector contents, selected-item highlighting, and callback behavior MUST remain unchanged.

#### Scenario: Welding material selector placement
- **WHEN** the operator opens the Material Type selector in the Continuous Weld or Spot Weld Engineer Mode screen
- **THEN** the popup MUST appear directly under the Material Type field anchor
- **AND** selecting a material MUST update the active in-memory engineer session as before

#### Scenario: Cutting and cleaning material selector placement
- **WHEN** the operator opens the Material Type selector in Cutting or Cleaning Engineer Mode screens
- **THEN** the popup MUST appear directly under the Material Type field anchor
- **AND** the material list and selected-item behavior MUST remain unchanged

### Requirement: Cut tab Simplified Chinese label is localized as cutting
The Simplified Chinese Engineer Mode tab or mode label for Cut SHALL display `切割`.

#### Scenario: Chinese locale Cut tab
- **WHEN** the app language is Simplified Chinese and the operator views Engineer Mode process tabs or mode menu entries
- **THEN** the Cut label MUST display `切割`
- **AND** related process routing and stored process type values MUST remain unchanged

## MODIFIED Requirements

### Requirement: Engineer mode text-input prompts use FrostedGlassDialog

Text-input prompts for commonly-used process parameter name and welding material name in engineer mode SHALL use `FrostedGlassDialog` with a shared text-input custom body. Numeric parameter entry dialogs in engineer mode SHALL use `FrostedGlassNumericInputDialog` with the shared numeric custom body. Engineer Mode numeric dialog titles SHALL use the same parameter label text displayed on the active screen, while preserving existing unit display when the field has a unit.

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

#### Scenario: Numeric prompt title matches visible row label

- **WHEN** the user opens a numeric engineer-mode process field whose row label differs from the generic builder label
- **THEN** the dialog title MUST use the visible row label from the current Engineer Mode screen
- **AND** if the field has a unit, the title MUST continue displaying that unit
