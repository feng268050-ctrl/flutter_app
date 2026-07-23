## MODIFIED Requirements

### Requirement: Alarm status checks require ready device state

The Alarm Information status check indicators SHALL evaluate and display healthy/normal state only after valid device status/data readiness is confirmed for the current screen session. Indicators MUST be `FrostStatusIndicatorView` (**Icon** variant). **Comm Status indicators (Pump, Gun, Feeder) are exempt from the generic offline Idle presentation:** they SHALL follow `alarm-comm-status-platform-display` (gray on emulator, red cross on device when not ready or comm fault).

#### Scenario: Offline lower controller on entry

- **WHEN** the Alarm Information screen is rendered before any valid lower-controller status/data has been received
- **THEN** non-communication status indicators SHALL display **Idle** (gray background, no glyph) and MUST NOT display **Success** (green checkmark) derived from default model values
- **AND** Comm Status indicators SHALL display neutral (gray) on emulator or fault (red cross) on production hardware, per platform rules.

#### Scenario: Status becomes ready after polling

- **WHEN** valid lower-controller status/data is received and readiness becomes true
- **THEN** each non-communication status indicator SHALL evaluate using the existing alarm semantics and reflect the actual device condition
- **AND** each Comm Status indicator SHALL evaluate using platform-aware comm display rules (healthy checkmark when comm alarm clear, otherwise neutral on emulator or fault cross on device).
