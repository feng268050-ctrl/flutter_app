## MODIFIED Requirements

### Requirement: Required headers for OTA process library upgrade

For process-library replacement imports that replace default/quick-mode rows—including imports triggered after comparing bundled asset versions to app-private storage at startup, and no longer requiring delivery through App OTA—the parser SHALL treat **参数名称**, **工艺类型**, and **数据类型** as required headers when present in the mapping configuration for that import profile; if any required header is missing, the import SHALL fail with a clear error (log and/or exception) and SHALL NOT partially apply a silent wrong schema.

The parser SHALL map **数据类型** cell values as follows:

- **`快速模式参数`** / **`快速模式工艺数据`** → `QUICK_MODE_DATA` (`0`)
- **`工程师模式常用参数`** / legacy **`工程师模式内置参数`** / **`工程师模式默认数据`** → `ENGINEER_MODE_DATA` (`1`)
- Legacy **`工程师模式自定义参数`** / **`工程师模式自定义数据`** → normalized to `ENGINEER_MODE_DATA` (`1`) with a deprecation log; MUST NOT persist as `2`

#### Scenario: Missing 工艺类型 column

- **WHEN** the first sheet does not contain a column with header 工艺类型 (and no alias maps to process type)
- **THEN** the import SHALL fail before persisting replacement rows

#### Scenario: Legacy custom data type normalized

- **WHEN** a row has 数据类型 equal to `工程师模式自定义参数`
- **THEN** the persisted row MUST have `dataType` **`1`** (`ENGINEER_MODE_DATA`)

#### Scenario: New common parameter label accepted

- **WHEN** a row has 数据类型 equal to `工程师模式常用参数`
- **THEN** the persisted row MUST have `dataType` **`1`** (`ENGINEER_MODE_DATA`)
