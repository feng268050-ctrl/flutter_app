## ADDED Requirements

### Requirement: More Common Specs English label uses Title Case

The English user-visible label for the Engineer Mode More Common Specs entry SHALL read **More Common Specs** (Title Case). Chinese and other locale strings MUST remain unchanged unless they already follow locale conventions.

#### Scenario: English locale More Common Specs label
- **WHEN** the app language is English and the operator views any Engineer Mode process tab
- **THEN** the More Common Specs entry label MUST display `More Common Specs`

### Requirement: Engineer Mode selection popups use fade-only animation

The More Common Specs and Material Type selection popups in Engineer Mode SHALL animate show and dismiss using fade-in and fade-out only. Popup position, focus behavior, and dismiss-on-outside-touch semantics MUST remain unchanged.

#### Scenario: Popup opens with fade in
- **WHEN** the operator opens the More Common Specs or Material Type selector
- **THEN** the popup MUST appear using an alpha fade-in animation
- **AND** MUST NOT use a vertical slide translation as part of the enter animation

#### Scenario: Popup closes with fade out
- **WHEN** the operator dismisses the More Common Specs or Material Type selector
- **THEN** the popup MUST disappear using an alpha fade-out animation
- **AND** MUST NOT use a vertical slide translation as part of the exit animation

### Requirement: Save as Common upserts by process type and name

**Save as Common** SHALL persist the current in-memory engineer session to `t_process_parameters_data` using **`processType` + `name`** as the uniqueness key among engineer-mode rows (`ENGINEER_MODE_DATA` and legacy `ENGINEER_MODE_CUSTOM_DATA`). If a row with the same process type and name exists, the device MUST **update** that row; otherwise it MUST **insert** a new row. Saving MUST NOT implicitly update a different preset solely because it is currently selected in the UI.

#### Scenario: Save with new name inserts
- **WHEN** the operator saves as name `N` under process type `T` and no engineer row exists for `(T, N)`
- **THEN** the device MUST insert a new `ENGINEER_MODE_DATA` row with name `N`
- **AND** the previously selected preset (if any) MUST remain unchanged in the database

#### Scenario: Save with existing name updates
- **WHEN** the operator saves as name `N` under process type `T` and an engineer row already exists for `(T, N)`
- **THEN** the device MUST update that existing row with the current session values
- **AND** MUST NOT create a duplicate row for the same `(T, N)`

### Requirement: Save as Common suggests display-based default name

The Save as Common name dialog SHALL pre-fill a suggested name derived from the **on-screen display labels** of Material Type and Material Thickness (not raw enum codes). Weld Path Clean and Ultra-wide Clean tabs SHALL omit thickness because those screens have no thickness field.

#### Scenario: Welding or cutting default name includes thickness
- **WHEN** the operator opens Save as Common on Continuous Weld, Spot Weld, Hand Cut, or CNC Cut
- **THEN** the dialog default text MUST be `{Material Type display}-{thickness display}{unit}`
- **AND** `unit` MUST match the active length unit shown on the thickness row (`mm` or `in`)

#### Scenario: Cleaning default name is material only
- **WHEN** the operator opens Save as Common on Weld Path Clean or Ultra-wide Clean
- **THEN** the dialog default text MUST be the Material Type display label only

#### Scenario: Custom material uses custom display name
- **WHEN** Material Type is Custom and a custom material name is set
- **THEN** the suggested name MUST use that custom material display text (not the enum label `Custom`)
