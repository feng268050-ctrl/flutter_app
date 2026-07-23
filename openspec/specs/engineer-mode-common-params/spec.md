## Purpose

Engineer Mode process presets use unified `ENGINEER_MODE_DATA`, in-memory editing sessions with session baseline reset, and DB persistence only on explicit save.
## Requirements
### Requirement: Engineer mode common parameters data type

Process library rows selectable in engineer mode SHALL use **`ProcessDataType.ENGINEER_MODE_DATA`** (integer value **`1`**). This type represents **commonly used** engineer-mode presets. **`ProcessDataType.ENGINEER_MODE_CUSTOM_DATA`** (value **`2`**) is **deprecated**; the application MUST NOT insert new rows with `dataType` **`2`**.

#### Scenario: New preset from engineer UI

- **WHEN** the operator saves or creates a process preset from engineer mode
- **THEN** the persisted row MUST have `dataType` equal to **`1`** (`ENGINEER_MODE_DATA`)

#### Scenario: Legacy custom rows readable

- **WHEN** the database contains existing rows with `dataType` **`2`**
- **THEN** the application MUST treat them as engineer-mode selectable presets (equivalent to **`1`**) until a migration normalizes them to **`1`**

### Requirement: In-memory editing session without auto-persist

While the operator edits process parameters in Engineer Mode, changes SHALL remain in an in-memory session (`sessionLiveData` or equivalent) and MUST NOT be written to `t_process_parameters_data` until the operator explicitly saves via **Set as commonly used parameter** (设为常用参数).

#### Scenario: Edits stay in memory

- **WHEN** the operator modifies any process field in Engineer Mode without saving
- **THEN** the database MUST NOT be updated for that session

#### Scenario: Only explicit save writes DB

- **WHEN** the operator taps **Set as commonly used parameter**
- **THEN** the device MUST insert or update the engineer-mode row in the database

### Requirement: Reset to default restores session baseline

The engineer-mode **Reset to Default** action SHALL restore the **session baseline**—the parameter snapshot captured when the current editing session started (either the selected common preset or parameters carried from quick mode)—from memory and MUST NOT reload from the database or a separate built-in default engineer preset.

#### Scenario: Reset after edits from quick-mode entry

- **WHEN** the operator opened engineer mode via More Parameters with quick-mode row Q, modified fields on the UI, then taps Reset to Default
- **THEN** all editable process fields MUST revert to the values from snapshot Q at session start

#### Scenario: Reset after edits on selected common preset

- **WHEN** the operator selected an existing `ENGINEER_MODE_DATA` preset P, modified fields, then taps Reset to Default
- **THEN** all editable process fields MUST revert to the values of P at selection time

#### Scenario: Reset does not query deprecated built-in default row

- **WHEN** the operator taps Reset to Default
- **THEN** the system MUST NOT load a replacement row solely because `dataType` was previously **`1`** built-in vs **`2`** custom; behavior MUST depend only on the session baseline

### Requirement: Apply quick-mode payload in engineer session

When engineer mode is opened from quick mode More Parameters entry, the system SHALL load the full quick-mode row by database id on a background thread, establish a session baseline from that snapshot, and SHALL make that snapshot the active in-memory editable preset following the same Modbus publish path as a normal engineer-mode selection, without writing to the engineer-mode database table.

#### Scenario: Baseline established on entry

- **WHEN** Engineer Mode opens from More Parameters with quick-mode snapshot S
- **THEN** `sessionBaseline` (or equivalent) MUST be initialized to a deep copy of S before the operator edits any field

#### Scenario: Engineer tab matches process type

- **WHEN** snapshot S has `processType` equal to spot welding
- **THEN** Engineer Mode MUST display the spot-welding engineer tab as active

#### Scenario: Quick-mode entry does not auto-persist engineer row

- **WHEN** Engineer Mode opens from More Parameters with a valid quick-mode row
- **THEN** the system MUST NOT insert or update an engineer-mode database row until the operator explicitly saves

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

### Requirement: Engineer parameter panels use the global scrollbar baseline

Engineer Mode parameter panels SHALL use the global vertical scrollbar style as their scrollbar baseline while preserving the current Engineer Mode behavior that hides the scrollbar until the user scrolls. The panel MUST use the unified white rounded thumb, `insideOverlay`, fading behavior, and no default visible track.

#### Scenario: Engineer parameter panel initially hides scrollbar

- **WHEN** the operator opens an Engineer Mode parameter tab such as cutting, wash, or welding
- **THEN** the parameter panel MUST NOT show a vertical scrollbar before the operator scrolls

#### Scenario: Engineer parameter panel reveals unified scrollbar on scroll

- **WHEN** the operator scrolls an Engineer Mode parameter panel vertically
- **THEN** the panel MUST show the same global vertical scrollbar thumb used by other scrollable pages
- **AND** the panel MUST continue using overlay/fade behavior without a separate visible track

#### Scenario: Engineer parameter layout is preserved

- **WHEN** the Engineer Mode parameter panels adopt the global scrollbar style or container
- **THEN** their existing parameter rows, click targets, validation entry points, and save/reset controls MUST remain unchanged

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

