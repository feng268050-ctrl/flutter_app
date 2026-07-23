## ADDED Requirements

### Requirement: Read-only parameter list custom body pattern

Informational dialogs that summarize process-parameter field values (for example remote received-parameter confirmation) SHALL use `FrostedGlassDialog.prompt(...).customBodyView(...)` with a shared read-only list body layout. When only acknowledgment is required, the dialog MAY use **OK-only** confirm (`.showCancel(false).confirmText(R.string.ok_text)`) following the same pattern as global status dialogs.

#### Scenario: Remote received-parameter summary

- **WHEN** the app shows the remote process-parameter received confirmation
- **THEN** the overlay MUST use `FrostedGlassDialog` with a custom body containing the shared read-only parameter list
- **AND** MUST show only an OK confirm action in the default action slot

#### Scenario: List content supplied by feature wrapper

- **WHEN** a read-only parameter list dialog is shown
- **THEN** row labels, values, and units MUST be bound by the feature wrapper or shared row builder
- **AND** `FrostedGlassDialog` itself MUST NOT gain built-in parameter-list modes
