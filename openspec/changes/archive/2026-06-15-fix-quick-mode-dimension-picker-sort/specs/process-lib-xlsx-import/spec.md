## MODIFIED Requirements

### Requirement: Process library xlsx uses header row for column binding

The import logic SHALL read the first non-empty row of the first sheet as the **header row**. Each data row SHALL be mapped to `ProcessParametersData` fields using the **header cell text** as the key, not fixed column indices.

After filtering to `QUICK_MODE_DATA` rows for persistence, the importer SHALL sort rows in canonical quick-mode order (material → thickness or swing width → gear) before replacing quick-mode rows in Room.

#### Scenario: Columns reordered in template

- **WHEN** a valid process-library xlsx contains the same canonical header names as the reference template but in a different column order
- **THEN** each `ProcessParametersData` field populated from those headers SHALL match the semantic meaning of that header (same as reference order mapping)

#### Scenario: Quick-mode rows stored in canonical order regardless of sheet row order

- **WHEN** a process-library xlsx lists quick-mode rows with thickness or swing-width values out of ascending order
- **THEN** the rows persisted as `QUICK_MODE_DATA` SHALL be stored in canonical ascending dimension order for each material
