## REMOVED Requirements

### Requirement: Device parameters persisted in dedicated table
**Reason**: Advanced Settings device parameters are being moved from `t_parameter_settings` to the new `t_advanced_settings` table.
**Migration**: Use the new `advanced-settings-persistence` capability for active Advanced Settings parameter storage and defaults.

### Requirement: Legacy advanced-setting parameter columns migrate to parameter settings
**Reason**: New upgrades must migrate existing `t_parameter_settings` values into `t_advanced_settings` instead of maintaining `t_parameter_settings` as the active parameter table.
**Migration**: Use the `Parameter settings migrate to advanced settings` requirement in `advanced-settings-persistence`.

### Requirement: Blow pressure threshold maximum is 500
**Reason**: Minimum Gas Pressure Threshold validation moves with the Advanced Settings parameter model.
**Migration**: Preserve this validation under the new `advanced-settings-persistence` capability and apply it to values persisted in `t_advanced_settings`.

### Requirement: Advanced Settings numeric dialogs enforce supported ranges
**Reason**: Numeric dialog validation moves with the Advanced Settings parameter model.
**Migration**: Use the `Advanced settings numeric validation is preserved` requirement in `advanced-settings-persistence`.

### Requirement: Parameter settings excluded from remote snapshot
**Reason**: The active parameter table is no longer `t_parameter_settings`.
**Migration**: Use the `Advanced settings excluded from remote snapshot` requirement in `advanced-settings-persistence`.

### Requirement: Parameter settings pages use the global scrollbar style
**Reason**: The page is no longer specified as a Parameter Settings page; it is part of the refactored Advanced Settings UI.
**Migration**: Use the Settings page structure and Advanced Settings page requirements for scrollable layout behavior.

## ADDED Requirements

### Requirement: Parameter settings capability is superseded
The `parameter-settings` capability is retained for historical traceability only. Active Advanced Settings device parameter storage, validation, migration, and remote-snapshot rules MUST be defined by `advanced-settings-persistence` and `advanced-settings-device-registers`.

#### Scenario: New work references advanced settings persistence
- **WHEN** a contributor implements Advanced Settings parameter behavior
- **THEN** they MUST use `advanced-settings-persistence` rather than `parameter-settings`
