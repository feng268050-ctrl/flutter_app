# device-registration-ui Specification

## Purpose

Device identity QR, bind vs registration prompts, and remote-lock operator feedback. Registration covers unrecognized SN (`INVALID_SN` / needs-registration); bind covers a cloud-known SN with zero bound users.

## Requirements

### Requirement: Device identity QR remains the binding payload

Settings → Device Information SHALL continue to offer the device identity QR using payload `SN|2|Model|SystemVersion` (v2), with `|` in fields replaced by `_`. Registration and bind dialogs SHALL reuse the same payload generator.

#### Scenario: Registration dialog shows same QR family

- **WHEN** the registration dialog is shown due to WebSocket auth failure
- **THEN** it MUST display a QR encoding the same v2 identity payload family as Device Information

### Requirement: Unbound device bind prompt

When the users binding probe reports success with no bound users (`ok` and empty user set) and a suitable foreground route exists, the system SHALL enqueue a bind-device prompt on the **global prompt queue** that shows the identity QR and instructs the operator to scan with the LaserCyber mobile app. The prompt MUST be dismissible without crashing networking. Cancel or Reconnect MAY trigger a users re-probe so a newly registered SN can transition out of bind-only state. The system MUST NOT present the bind dialog via an independent modal host that can stack over another prompt or over boot self-check. The bind dialog MUST NOT bypass the global prompt queue.

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

On WebSocket auth-invalid failure (`401`) or users-probe / upgrade classification of Worker `INVALID_SN` (needs-registration), the system SHALL enqueue a registration dialog on the **global prompt queue** with localized title/body equivalent to lws-ui “Register This Device” copy, the identity QR, and actions Cancel and Reconnect. Duplicate registration events MUST NOT stack multiple dialogs. Cancel dismisses only; Reconnect dismisses, clears the auth-error reconnect latch, and initiates a user-driven reconnect that MAY re-probe users first. The registration dialog MUST NOT bypass the global prompt queue.

#### Scenario: Reconnect clears auth latch

- **WHEN** the operator taps Reconnect on the registration dialog
- **THEN** the dialog MUST dismiss
- **AND** the system MUST allow a new `/ws/device` connect attempt

#### Scenario: INVALID_SN shows register not bind

- **WHEN** the users probe or WebSocket path classifies the SN as `INVALID_SN` / needs-registration
- **THEN** the system MUST present the registration dialog
- **AND** MUST NOT present the unbound bind dialog for that classification

#### Scenario: Registration enqueues on global queue

- **WHEN** a WebSocket `401` occurs
- **THEN** the registration dialog MUST be enqueued on the global prompt queue
- **AND** MUST NOT open as an independent modal over an in-flight prompt or boot self-check

### Requirement: Remote lock operator feedback

When remote lock is active, the system SHALL show a lock indicator in the product status chrome and SHALL show lock feedback via the **global prompt queue** (stable id `remoteLock`) explaining the device is locked. Locked state MUST block entry into quick/engineer welding modes per product policy until unlock. The lock prompt MUST NOT bypass the global queue. On remote unlock, the App MUST dismiss the `remoteLock` queue entry so the dialog does not remain visible.

#### Scenario: Lock blocks quick mode entry

- **WHEN** remote lock is active
- **AND** the operator attempts to enter quick mode
- **THEN** the system MUST prevent the mode session from starting
- **AND** MUST enqueue lock feedback on the global prompt queue

#### Scenario: Unlock dismisses lock prompt

- **WHEN** the lock prompt is pending or showing
- **AND** remote unlock clears the lock flag
- **THEN** the `remoteLock` queue entry MUST be dismissed
- **AND** the lock dialog MUST close without requiring Close
