## ADDED Requirements

### Requirement: Engineer mode common parameters data type

Process library rows selectable in engineer mode SHALL use **`ProcessDataType.ENGINEER_MODE_DATA`** (integer value **`1`**). This type represents **commonly used** engineer-mode presets. **`ProcessDataType.ENGINEER_MODE_CUSTOM_DATA`** (value **`2`**) is **deprecated**; the application MUST NOT insert new rows with `dataType` **`2`**.

#### Scenario: New preset from engineer UI

- **WHEN** the operator saves or creates a process preset from engineer mode
- **THEN** the persisted row MUST have `dataType` equal to **`1`** (`ENGINEER_MODE_DATA`)

#### Scenario: Legacy custom rows readable

- **WHEN** the database contains existing rows with `dataType` **`2`**
- **THEN** the application MUST treat them as engineer-mode selectable presets (equivalent to **`1`**) until a migration normalizes them to **`1`**

### Requirement: Reset to default restores session baseline

The engineer-mode **Reset to Default** action SHALL restore the **session baseline**—the parameter snapshot captured when the current editing session started (either the selected common preset or parameters carried from quick mode)—and MUST NOT reload a separate database "built-in default" engineer preset.

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

When engineer mode is opened from quick mode More Parameters entry, the system SHALL establish a session baseline from the carried quick-mode parameter snapshot and SHALL make that snapshot the active editable preset following the same Modbus publish path as a normal engineer-mode selection.

#### Scenario: Baseline established on entry

- **WHEN** Engineer Mode opens from More Parameters with quick-mode snapshot S
- **THEN** `sessionBaseline` (or equivalent) MUST be initialized to a deep copy of S before the operator edits any field

#### Scenario: Engineer tab matches process type

- **WHEN** snapshot S has `processType` equal to spot welding
- **THEN** Engineer Mode MUST display the spot-welding engineer tab as active
