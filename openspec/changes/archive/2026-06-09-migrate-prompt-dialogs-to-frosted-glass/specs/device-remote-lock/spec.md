## ADDED Requirements

### Requirement: Remote lock notice uses FrostedGlassDialog

The remote lock notice shown via `GlobalDialogUtil.showRemoteLockDialog` SHALL use `FrostedGlassDialog` for its overlay shell. The user MUST still be able to dismiss the notice; lock state MUST clear only on server unlock as before.

#### Scenario: Remote lock dialog on FrostedGlass

- **WHEN** the device receives a remote lock command and the notice is shown
- **THEN** the dialog MUST render as a `FrostedGlassDialog` overlay with title and message
- **AND** confirm/dismiss MUST close the notice without changing lock semantics

### Requirement: Forced disconnect notice uses FrostedGlassDialog

The forced WebSocket disconnect notice shown via `GlobalDialogUtil.showForcedDisconnectDialog` SHALL use `FrostedGlassDialog` for its overlay shell.

#### Scenario: Forced disconnect on FrostedGlass

- **WHEN** the app shows a forced disconnect notice to the user
- **THEN** the dialog MUST use `FrostedGlassDialog` instead of legacy `createDialogWithLayout` chrome
