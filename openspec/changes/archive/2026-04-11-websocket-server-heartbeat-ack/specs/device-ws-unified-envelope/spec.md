## ADDED Requirements

### Requirement: Server-originated heartbeat inbound payload

Inbound frames with `type` equal to `heartbeat` sent by the server on the device WebSocket SHALL use the unified envelope and SHALL have `payload` equal to the empty object `{}`.

#### Scenario: Server heartbeat envelope shape

- **WHEN** the server sends a `heartbeat` frame on the device WebSocket
- **THEN** the frame MUST include top-level `v`, `type`, `id`, `ts`, and object `payload`, with `type` equal to `heartbeat` and `payload` equal to `{}`

### Requirement: Device-originated heartbeat acknowledgement for server heartbeat

When the device sends `heartbeat_ack` as the immediate protocol reply to a server-originated `heartbeat`, that outbound frame SHALL use the unified envelope with `v` equal to `1`, a newly generated device-originated `id`, millisecond `ts`, `type` equal to `heartbeat_ack`, and `payload` equal to the empty object `{}`.

#### Scenario: Outbound heartbeat_ack after server heartbeat

- **WHEN** the device responds to an inbound server `heartbeat` with a `heartbeat_ack` frame
- **THEN** `type` MUST be `heartbeat_ack`, `payload` MUST serialize as `{}`, and `id` MUST be newly generated for that outbound message per outbound message identity rules
