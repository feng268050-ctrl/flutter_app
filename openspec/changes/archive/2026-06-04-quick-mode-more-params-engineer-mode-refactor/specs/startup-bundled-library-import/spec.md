## MODIFIED Requirements

### Requirement: Process library import reuses pre-refactor OTA behavior

For `process-library`, the import/update logic executed after a positive version comparison SHALL continue to reuse the existing xlsx parsing and persistence behavior (file handling into existing importer, default/quick replacement semantics, and user-visible failure modes), while changing only source selection to:
1) branch by available source shape under `assets/process-library/`:
   - single xlsx: use it directly,
   - multiple xlsx: choose model-specific xlsx (with fallback),
2) pass the selected xlsx into the canonical importer.

When the imported sheet contains **`QUICK_MODE_DATA`** rows but no **`ENGINEER_MODE_DATA`** row for a given **`processType`**, the importer SHALL synthesize exactly **one** engineer common-preset row per **`processType`** by cloning the quick-mode row that matches **median gear** and **median thickness** (for non-clean process types) or **median swing width** (for `WELD_CLEAN` and `WIDTH_CLEAN`), and SHALL set the synthesized row's **`name`** to the English **material** label from the selected quick-mode row (matching the process-library xlsx **材料** column, e.g. `Stainless Steel`, `Carbon Steel`, `Aluminum Alloy`). For custom materials, **`name`** MUST use the row's **`materialName`** when present. The synthesized row MUST have **`dataType`** **`ENGINEER_MODE_DATA`** (`1`).

#### Scenario: Model-specific source still yields canonical DB result

- **WHEN** startup selects `L1 Pro.xlsx` for the active device model
- **THEN** the resulting persisted process data SHALL be equivalent to invoking the legacy importer directly on `L1 Pro.xlsx`, including synthesized engineer common presets per the median-selection rule when applicable

#### Scenario: Single-file source still yields canonical DB result

- **WHEN** startup discovers only one process-library xlsx source file
- **THEN** the resulting persisted process data SHALL be equivalent to invoking the legacy importer directly on that xlsx, including synthesized engineer common presets per the median-selection rule when applicable

#### Scenario: Median gear and thickness selection

- **WHEN** quick-mode rows for `processType` continuous welding have gears `{1,2,3}` and thicknesses `{1.0, 2.0, 3.0}` mm at median gear `2`
- **THEN** the synthesized `ENGINEER_MODE_DATA` row MUST be cloned from the quick-mode row with gear `2` and thickness `2.0` mm (median thickness within that gear subset)

#### Scenario: English name from material

- **WHEN** a synthesized engineer common preset is created from a quick-mode row with `materialType` stainless steel
- **THEN** the row **`name`** MUST be `Stainless Steel`
