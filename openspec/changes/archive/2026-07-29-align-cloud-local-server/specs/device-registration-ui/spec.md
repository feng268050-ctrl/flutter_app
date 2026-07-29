## ADDED Requirements

### Requirement: Device identity QR remains the binding payload

Settings → Device Information SHALL continue to offer the device identity QR using payload `SN|2|Model|SystemVersion` (v2), with `|` in fields replaced by `_`. Registration and bind dialogs SHALL reuse the same payload generator.

#### Scenario: Registration dialog shows same QR family

- **WHEN** the registration dialog is shown due to WebSocket auth failure
- **THEN** it MUST display a QR encoding the same v2 identity payload family as Device Information

### Requirement: Unbound device bind prompt

When the users binding probe reports no bound users and a suitable foreground route exists, the system SHALL present a bind-device prompt that shows the identity QR and instructs the operator to scan with the LaserCyber mobile app. The prompt MUST be dismissible without crashing networking.

#### Scenario: Operator cancels bind prompt

- **WHEN** the bind prompt is visible and the operator dismisses it
- **THEN** the dialog MUST close
- **AND** cloud WebSocket MAY continue or retry per connectivity policy without requiring the dialog to stay open

### Requirement: WebSocket 401 registration dialog

On WebSocket auth-invalid failure (`401`), the system SHALL show a registration dialog with localized title/body equivalent to lws-ui “Register This Device” copy, the identity QR, and actions Cancel and Reconnect. Duplicate 401 events MUST NOT stack multiple dialogs. Cancel dismisses only; Reconnect dismisses and initiates a user-driven reconnect attempt that clears the auth-error reconnect latch.

#### Scenario: Reconnect clears auth latch

- **WHEN** the operator taps Reconnect on the registration dialog
- **THEN** the dialog MUST dismiss
- **AND** the system MUST allow a new `/ws/device` connect attempt

### Requirement: Remote lock operator feedback

When remote lock is active, the system SHALL show a lock indicator in the product status chrome and MAY show a home prompt explaining the device is locked. Locked state MUST block entry into quick/engineer welding modes per product policy until unlock.

#### Scenario: Lock blocks quick mode entry

- **WHEN** remote lock is active
- **AND** the operator attempts to enter quick mode
- **THEN** the system MUST prevent the mode session from starting
- **AND** MUST present lock feedback to the operator
