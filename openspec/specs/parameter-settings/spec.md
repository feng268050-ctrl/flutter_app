# parameter-settings Specification

## Purpose
TBD - created by archiving change refactor-advanced-settings-data-structure. Update Purpose after archive.
## Requirements
### Requirement: Parameter settings capability is superseded
The `parameter-settings` capability is retained for historical traceability only. Active Advanced Settings device parameter storage, validation, migration, and remote-snapshot rules MUST be defined by `advanced-settings-persistence` and `advanced-settings-device-registers`.

#### Scenario: New work references advanced settings persistence
- **WHEN** a contributor implements Advanced Settings parameter behavior
- **THEN** they MUST use `advanced-settings-persistence` rather than `parameter-settings`

