## MODIFIED Requirements

### Requirement: Unbound device bind prompt

When the users binding probe reports no bound users and a suitable foreground route exists, the system SHALL enqueue a bind-device prompt on the **global prompt queue**. The prompt SHALL show the identity QR and instruct the operator to scan with the LaserCyber mobile app. The prompt MUST be dismissible without crashing networking. The system MUST NOT present the bind dialog via an independent modal host that can stack over another prompt or over boot self-check.

#### Scenario: Operator cancels bind prompt

- **WHEN** the bind prompt is visible and the operator dismisses it
- **THEN** the dialog MUST close
- **AND** cloud WebSocket MAY continue or retry per connectivity policy without requiring the dialog to stay open

#### Scenario: Bind enqueues on global queue when probe returns

- **WHEN** the users binding probe reports unbound after network/cloud is ready
- **THEN** the bind prompt SHALL be enqueued on the global prompt queue
- **AND** MAY appear after any prompts already ahead in FIFO (including warn dialogs)
- **AND** MUST NOT delay warn enrollment while waiting for the probe

### Requirement: WebSocket 401 registration dialog

On WebSocket auth-invalid failure (`401`), the system SHALL enqueue a registration dialog on the **global prompt queue** with localized title/body equivalent to lws-ui “Register This Device” copy, the identity QR, and actions Cancel and Reconnect. Duplicate 401 events MUST NOT stack multiple dialogs. Cancel dismisses only; Reconnect dismisses and initiates a user-driven reconnect attempt that clears the auth-error reconnect latch. The registration dialog MUST NOT bypass the global prompt queue.

#### Scenario: Reconnect clears auth latch

- **WHEN** the operator taps Reconnect on the registration dialog
- **THEN** the dialog MUST dismiss
- **AND** the system MUST allow a new `/ws/device` connect attempt

#### Scenario: Registration enqueues on global queue

- **WHEN** a WebSocket `401` occurs
- **THEN** the registration dialog MUST be enqueued on the global prompt queue
- **AND** MUST NOT open as an independent modal over an in-flight prompt or boot self-check
