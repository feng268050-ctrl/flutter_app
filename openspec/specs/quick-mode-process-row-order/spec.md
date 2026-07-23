## Purpose

Quick Mode process library rows and the dashboard right dimension picker (thickness / scan width) use a single canonical row order so wheel display and hidden Modbus parameters stay aligned.

## Requirements

### Requirement: Quick-mode process rows have canonical sort order

Quick-mode process library rows (`ProcessDataType.QUICK_MODE_DATA`) SHALL be ordered canonically by:

1. `materialType` ascending (null last),
2. primary dimension ascending — `thickness` (null as 0) for welding/cutting process types, `swingWidth` (null as 0) for `WELD_CLEAN` and `WIDTH_CLEAN`,
3. `gear` ascending (null last).

This ordering SHALL be applied when rows are persisted after xlsx import and when rows are loaded for Quick Mode UI (`listAllMaterials` or equivalent).

#### Scenario: Import stores rows in canonical order

- **WHEN** a process-library xlsx is imported and quick-mode rows are written to Room
- **THEN** persisted rows for a given `processType` SHALL be retrievable in canonical sort order

#### Scenario: Existing database read uses canonical order

- **WHEN** Quick Mode loads process rows from Room without a new import
- **THEN** the list returned to `GeneralOperationsFragment` SHALL be in canonical sort order

### Requirement: Right dimension picker derives order from sorted rows

The Quick Mode right dimension picker (`ThicknessPickV2`) SHALL be built by iterating canonically sorted rows for the active material and inserting distinct thickness or swing-width keys into an **ordered** map (`LinkedHashMap` or equivalent) so entry order matches ascending dimension values.

The implementation SHALL NOT rely on a separate display-only sort of wheel items after deduplication.

#### Scenario: Thickness wheel ascending from row order

- **WHEN** Continuous Welding rows for a material include thicknesses 3.0, 1.0, and 2.0 mm in arbitrary xlsx order
- **THEN** after load the right wheel SHALL list 1.0, 2.0, 3.0 mm in that order
- **AND** each entry SHALL be backed by the process row that is first in canonical order for that thickness value

#### Scenario: Scan width wheel ascending from row order

- **WHEN** Weld Path Clean rows for a material include swing widths 4.0, 1.0, and 2.5 mm in arbitrary xlsx order
- **THEN** after load the right wheel SHALL list 1.0, 2.5, 4.0 mm in that order
- **AND** each entry SHALL be backed by the process row that is first in canonical order for that swing-width value

### Requirement: Process lookup uses same row order

`findNowProcessParametersData` (or equivalent Quick Mode matcher) SHALL scan the canonically ordered row list and return the first row matching active material, gear, and thickness or swing width.

#### Scenario: Modbus send uses row from canonical order

- **WHEN** the operator selects a thickness or scan width on the right wheel and a gear on the left wheel
- **THEN** the row sent to Modbus SHALL be the first canonical-order row matching material, gear, and selected dimension
- **AND** hidden fields (laser power, swing frequency, delays, etc.) SHALL come from that same row
