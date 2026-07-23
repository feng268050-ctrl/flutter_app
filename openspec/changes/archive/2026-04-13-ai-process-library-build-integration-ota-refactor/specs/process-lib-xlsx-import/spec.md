## MODIFIED Requirements

### Requirement: Required headers for OTA process library upgrade

For process-library replacement imports that replace default/quick-mode rows—including imports triggered after comparing bundled asset versions to app-private storage at startup, and no longer requiring delivery through App OTA—the parser SHALL treat **参数名称**, **工艺类型**, and **数据类型** as required headers when present in the mapping configuration for that import profile; if any required header is missing, the import SHALL fail with a clear error (log and/or exception) and SHALL NOT partially apply a silent wrong schema.

#### Scenario: Missing 工艺类型 column

- **WHEN** the first sheet does not contain a column with header 工艺类型 (and no alias maps to process type)
- **THEN** the import SHALL fail before persisting replacement rows
