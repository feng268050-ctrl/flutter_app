## ADDED Requirements

### Requirement: Alarm status checks require ready device state
The Alarm Information status check indicators SHALL evaluate and display healthy/normal checked state only after valid device status/data readiness is confirmed for the current screen session.

#### Scenario: Offline lower controller on entry
- **WHEN** the Alarm Information screen is rendered before any valid lower-controller status/data has been received
- **THEN** status check indicators SHALL remain unchecked and MUST NOT display healthy/normal state derived from default model values.

#### Scenario: Status becomes ready after polling
- **WHEN** valid lower-controller status/data is received and readiness becomes true
- **THEN** each status check indicator SHALL evaluate using the existing alarm semantics and reflect the actual device condition.
