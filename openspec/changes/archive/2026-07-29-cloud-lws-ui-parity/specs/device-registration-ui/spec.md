## MODIFIED Requirements

### Requirement: Unbound device bind prompt

When the users binding probe reports success with no bound users (`ok` and empty user set) and a suitable foreground route exists, the system SHALL present a bind-device prompt that shows the identity QR and instructs the operator to scan with the LaserCyber mobile app. The prompt MUST be dismissible without crashing networking. Cancel or Reconnect MAY trigger a users re-probe so a newly registered SN can transition out of bind-only state.

#### Scenario: Operator cancels bind prompt

- **WHEN** the bind prompt is visible and the operator dismisses it
- **THEN** the dialog MUST close
- **AND** cloud WebSocket MAY continue or retry per connectivity policy without requiring the dialog to stay open

### Requirement: WebSocket 401 registration dialog

On WebSocket auth-invalid failure (`401`) or users-probe / upgrade classification of Worker `INVALID_SN` (needs-registration), the system SHALL show a registration dialog with localized title/body equivalent to lws-ui “Register This Device” copy, the identity QR, and actions Cancel and Reconnect. Duplicate registration events MUST NOT stack multiple dialogs. Cancel dismisses only; Reconnect dismisses, clears the auth-error reconnect latch, and initiates a user-driven reconnect that MAY re-probe users first.

#### Scenario: Reconnect clears auth latch

- **WHEN** the operator taps Reconnect on the registration dialog
- **THEN** the dialog MUST dismiss
- **AND** the system MUST allow a new `/ws/device` connect attempt

#### Scenario: INVALID_SN shows register not bind

- **WHEN** the users probe or WebSocket path classifies the SN as `INVALID_SN` / needs-registration
- **THEN** the system MUST present the registration dialog
- **AND** MUST NOT present the unbound bind dialog for that classification
