## ADDED Requirements

### Requirement: Multiple alarm signal sources merge into one coordinator

`cyber_alarm` SHALL continue to consume alarm activity through a single inbound `AlarmSignalSource` port on the coordinator. Product Apps MUST be able to merge multiple transport adapters (at least the existing Modbus attribute adapter and an IP-camera health adapter for C002) into that port without changing episode lifecycle, queueing, or recover/ack policy inside the package. Package episode policy MUST remain transport-agnostic (stable codes + active/inactive + kind only).

#### Scenario: Camera and Modbus share one coordinator

- **WHEN** the App wires both a Modbus adapter and a camera health adapter into the warn stack
- **THEN** both feeds SHALL produce `AlarmSignalEvent`s consumed by one `WarnAlarmCoordinator`
- **AND** concurrent codes SHALL queue presentation under the same single-host rules

#### Scenario: Adding camera source does not fork episode policy

- **WHEN** C002 rises from camera health while a Modbus code is already showing
- **THEN** C002 SHALL enqueue behind the showing episode per existing package policy
- **AND** the App MUST NOT open a second independent warn modal host for C002

## MODIFIED Requirements

### Requirement: Warn presentation gated during boot self-check

While product boot self-check is active, the `cyber_alarm` coordinator MUST NOT call the presentation port to show new modal warn dialogs for Modbus-backed **or non-Modbus** alarm codes (gate supplied by App). Historical insert MAY still occur per existing package policy. After self-check completes, subsequent rising edges SHALL present normally, and `flushPresentation` MAY show parked eligible episodes.

#### Scenario: Suppressed during self-check

- **WHEN** boot self-check overlay is active
- **AND** an alarm attribute becomes true
- **THEN** no modal warn dialog is shown for that onset
- **AND** after self-check ends, a later new rising edge MAY show a dialog

#### Scenario: Camera C002 uses the same gate

- **WHEN** boot self-check presentation is gated
- **AND** camera health reports unhealthy
- **THEN** no C002 modal SHALL be shown via the presentation port
- **AND** gating SHALL use the same App `WarnGate` as Modbus-backed codes
