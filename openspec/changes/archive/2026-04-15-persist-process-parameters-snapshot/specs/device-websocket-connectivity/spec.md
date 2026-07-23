## ADDED Requirements

### Requirement: Outbound online and stat response include process-parameter snapshot
The device websocket layer SHALL include `processParameters` in outbound `device.online` and `command.stat_response` messages. The value of `processParameters` in both message types MUST be sourced from the same live in-memory snapshot defined by `device-remote-snapshot`, and MUST represent a complete current parameter view at serialization time.

#### Scenario: device.online contains current full processParameters snapshot
- **WHEN** the device emits `device.online`
- **THEN** the message payload MUST include `processParameters` equal to the latest complete in-memory process-parameter snapshot

#### Scenario: command.stat_response contains current full processParameters snapshot
- **WHEN** the device emits `command.stat_response`
- **THEN** the response payload MUST include `processParameters` equal to the latest complete in-memory process-parameter snapshot

#### Scenario: Consecutive parameter changes are reflected in later outbound messages
- **WHEN** one or more process-parameter updates are committed before the next outbound `device.online` or `command.stat_response`
- **THEN** the next emitted message MUST carry `processParameters` reflecting all committed updates up to that serialization point
