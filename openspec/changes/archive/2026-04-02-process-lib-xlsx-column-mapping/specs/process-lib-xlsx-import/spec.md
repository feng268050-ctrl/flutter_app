## ADDED Requirements

### Requirement: Process library xlsx uses header row for column binding

The import logic SHALL read the first non-empty row of the first sheet as the **header row**. Each data row SHALL be mapped to `ProcessParametersData` fields using the **header cell text** as the key, not fixed column indices.

#### Scenario: Columns reordered in template

- **WHEN** a valid process-library xlsx contains the same canonical header names as the reference template but in a different column order
- **THEN** each `ProcessParametersData` field populated from those headers SHALL match the semantic meaning of that header (same as reference order mapping)

### Requirement: Canonical header names for reference template

For the reference file pattern `工艺库_V*.xlsx` (validated against `工艺库_V1.4.xlsx`), the system SHALL recognize at minimum the following header strings and map them to entity fields:

| Header (列名) | `ProcessParametersData` field |
|---------------|----------------------------------|
| 参数名称 | `paramsName` |
| 材料 | `materials` (via existing material enum conversion) |
| 材质名称 | `materialsName` |
| 厚度 | `thickness` |
| 激光功率 | `laserPower` |
| 摆动频率 | `swingFrequency` |
| 摆动宽度 | `swingWidth` |
| 吹气延时 | `blowDelay` |
| 关气延时 | `closeAirDelay` |
| 关光延时 | `closeLightDelay` |
| 补丝时延 | `fillDelay` |
| 点焊间隔 | `pointWeldingInterval` |
| 点焊持续 | `pointWeldingDuration` |
| 功率缓升 | `powerRampUp` |
| 功率缓降 | `powerRampDown` |
| 送丝速度 | `wireFeedSpeed` |
| 回抽长度 | `retractLength` |
| 回抽速度 | `retractSpeed` |
| 补丝长度 | `fillLength` |
| 工艺类型 | `processType` (via existing process-type string conversion) |
| 数据类型 | `dataType` (via existing data-type string conversion) |
| 档位 | `gear` |

#### Scenario: Reference template import

- **WHEN** the xlsx first-sheet header row exactly matches the reference template above
- **THEN** each data row SHALL produce a `ProcessParametersData` instance with fields set from the matching columns

### Requirement: Extensible parsing abstraction

The implementation SHALL separate:

1. **Header resolution** — build a map from normalized header string → column index (or equivalent).
2. **Row mapping** — given a data row and header map, produce `ProcessParametersData` (or partial + validation errors).

Future formats (extra columns, aliases, new templates) SHALL be supportable by extending configuration or mapping tables without rewriting the core read loop.

#### Scenario: Unknown column present

- **WHEN** the header row contains a column name not present in the canonical mapping (and no configured alias matches)
- **THEN** that column SHALL be ignored for mapping and SHALL NOT cause import failure

### Requirement: Missing optional columns

- **WHEN** a canonical header is absent from the sheet
- **THEN** the corresponding `ProcessParametersData` field MAY remain unset (null) unless the implementation defines that field as required; required-field policy SHALL be documented in code or mapping config

#### Scenario: Empty optional numeric field

- **WHEN** a mapped cell is empty for a nullable numeric field
- **THEN** the entity field SHALL be null (or equivalent) and SHALL NOT throw solely due to emptiness

### Requirement: Required headers for OTA process library upgrade

For OTA process-library upgrade paths that replace default/quick-mode rows, the parser SHALL treat **参数名称**, **工艺类型**, and **数据类型** as required headers when present in the mapping configuration for that import profile; if any required header is missing, the import SHALL fail with a clear error (log and/or exception) and SHALL NOT partially apply a silent wrong schema.

#### Scenario: Missing 工艺类型 column

- **WHEN** the first sheet does not contain a column with header 工艺类型 (and no alias maps to process type)
- **THEN** the import SHALL fail before persisting replacement rows
