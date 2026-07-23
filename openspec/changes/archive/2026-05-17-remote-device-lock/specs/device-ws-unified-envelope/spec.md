## ADDED Requirements

### Requirement: Inbound remote lock command envelope

Inbound frames with `type` equal to `command.lock` SHALL use the unified WebSocket JSON envelope (`v`, `type`, `id`, `ts`, `payload`). The `payload` object SHALL be present and SHALL be empty (no business fields required). The device SHALL apply remote lock per `device-remote-lock` when the frame is valid.

#### Scenario: Lock command structure

- **WHEN** the server sends `command.lock` on the device WebSocket with `payload` as an empty JSON object
- **THEN** the frame MUST include top-level `v`, `type`, `id`, `ts`, and object `payload`, with `type` equal to `command.lock`

#### Scenario: Lock applied without outbound ack requirement

- **WHEN** the device successfully processes `command.lock`
- **THEN** the device MUST persist remote lock state and MUST NOT require sending a lock acknowledgment frame as part of this capability

### Requirement: Inbound remote unlock command envelope

Inbound frames with `type` equal to `command.unlock` SHALL use the unified WebSocket JSON envelope (`v`, `type`, `id`, `ts`, `payload`). The `payload` object SHALL be present and SHALL be empty (no business fields required). The device SHALL clear remote lock per `device-remote-lock` when the frame is valid.

#### Scenario: Unlock command structure

- **WHEN** the server sends `command.unlock` on the device WebSocket with `payload` as an empty JSON object
- **THEN** the frame MUST include top-level `v`, `type`, `id`, `ts`, and object `payload`, with `type` equal to `command.unlock`

#### Scenario: Unlock is the only release path

- **WHEN** the remote lock flag is true and the device has not processed `command.unlock`
- **THEN** processing `command.unlock` MUST be the only WebSocket message type that clears remote lock state
