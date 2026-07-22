## ADDED Requirements

### Requirement: Boot self-check suppresses warn presentation

While the boot self-check overlay is active, the product App MUST gate `cyber_alarm` so it does not present new modal warn dialogs for Modbus-backed alarm onsets. Self-check item evaluation MAY continue to use the same Alarm Information semantics for pass/fail tiles. After self-check completes (success or operator-dismissed failure path per existing rules), normal warn presentation SHALL resume for subsequent onsets.

#### Scenario: Alarm during self-check does not popup

- **WHEN** boot self-check is active
- **AND** a Modbus `alarm.*` attribute becomes true
- **THEN** the App MUST NOT show a modal warn dialog for that onset during the active self-check session

#### Scenario: After self-check resumes warns

- **WHEN** boot self-check has finished
- **AND** a later rising edge occurs for a catalogued alarm code
- **THEN** warn presentation MAY show a modal dialog for that onset
