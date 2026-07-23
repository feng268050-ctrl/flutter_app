## MODIFIED Requirements

### Requirement: Heartbeat and command acknowledgement protocol handling

The device transport SHALL support heartbeat and command acknowledgement message flows in both directions using the unified WebSocket JSON envelope for all such frames: the device MAY emit periodic `heartbeat` frames and SHALL accept server `heartbeat_ack` responses; the device SHALL accept server `heartbeat` frames and emit the corresponding `heartbeat_ack` reply.

#### Scenario: Heartbeat acknowledgement exchange

- **WHEN** the device sends a unified-envelope frame with `type` `heartbeat`, `v` equal to `1`, a unique non-empty `id`, millisecond `ts`, and `payload` equal to `{}`
- **THEN** the transport handler MUST accept and process a server response frame that uses the unified envelope with `type` `heartbeat_ack` and `payload` equal to `{}`

#### Scenario: Server heartbeat solicits device heartbeat acknowledgement

- **WHEN** the transport receives an inbound unified-envelope frame with `type` `heartbeat`, `v` equal to `1`, and `payload` equal to `{}` on an active session where outbound frames are permitted by the connection manager
- **THEN** the device MUST emit an outbound unified-envelope frame with `type` `heartbeat_ack`, `v` equal to `1`, a newly generated non-empty `id`, millisecond `ts`, and `payload` equal to `{}`

#### Scenario: Command ACK response emission

- **WHEN** a command is received and processed by the device
- **THEN** the device MUST emit an ACK using the unified envelope with `type` `ack`, with command identity and status fields carried inside `payload` as required by the server contract (including logical command identity and result code)
