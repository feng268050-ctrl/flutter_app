## MODIFIED Requirements

### Requirement: Online readiness is gated by connected frame
The device SHALL consider itself online only after receiving the server `connected` JSON text frame on a successfully established WebSocket session, where the frame conforms to the unified envelope and `type` is `connected`, `v` is `1`, and `payload` contains non-empty `sn` and `connection_id`.

#### Scenario: Socket open without connected frame
- **WHEN** the WebSocket transport opens but no valid `connected` envelope frame has been received
- **THEN** the device MUST remain in a non-online pending state

#### Scenario: Connected frame confirms online
- **WHEN** a valid unified-envelope `connected` frame is received on the active session
- **THEN** the device MUST transition to online state and publish online telemetry/status

### Requirement: Heartbeat and command acknowledgement protocol handling
The device transport SHALL support heartbeat and command acknowledgement message flows using the unified WebSocket JSON envelope for all such frames.

#### Scenario: Heartbeat acknowledgement exchange
- **WHEN** the device sends a unified-envelope frame with `type` `heartbeat`, `v` equal to `1`, a unique non-empty `id`, millisecond `ts`, and `payload` equal to `{}`
- **THEN** the transport handler MUST accept and process a server response frame that uses the unified envelope with `type` `heartbeat_ack` and `payload` equal to `{}`

#### Scenario: Command ACK response emission
- **WHEN** a command is received and processed by the device
- **THEN** the device MUST emit an ACK using the unified envelope with `type` `ack`, with command identity and status fields carried inside `payload` as required by the server contract (including logical command identity and result code)
