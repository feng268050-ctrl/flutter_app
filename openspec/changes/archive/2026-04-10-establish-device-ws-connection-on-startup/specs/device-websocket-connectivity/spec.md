## ADDED Requirements

### Requirement: Environment-aware device WebSocket endpoint selection
The device networking layer SHALL select the WebSocket host by release channel and build the connection endpoint as `wss://<host>/ws/device?sn=<device-sn>`.

#### Scenario: Use production host in release channel
- **WHEN** the app runs with `RELEASE_CHANNEL=1`
- **THEN** the device WebSocket connection MUST target `wss://api-prod.lasercyber.workers.dev/ws/device?sn=<device-sn>`

#### Scenario: Use test host outside release channel
- **WHEN** the app runs with `RELEASE_CHANNEL!=1`
- **THEN** the device WebSocket connection MUST target `wss://api-test.lasercyber.workers.dev/ws/device?sn=<device-sn>`

### Requirement: Startup and network-recovery connection lifecycle
The device SHALL attempt WebSocket connection on app startup and whenever network connectivity is restored.

#### Scenario: Connect on app startup
- **WHEN** app bootstrap completes and a device SN is available
- **THEN** the connection manager MUST start a WebSocket connect attempt to `/ws/device`

#### Scenario: Reconnect after network recovery
- **WHEN** network connectivity transitions from unavailable to available
- **THEN** the connection manager MUST trigger a new WebSocket connect attempt

### Requirement: Online readiness is gated by connected frame
The device SHALL consider itself online only after receiving the server `connected` JSON frame on a successfully established WebSocket session.

#### Scenario: Socket open without connected frame
- **WHEN** the WebSocket transport opens but no `connected` frame has been received
- **THEN** the device MUST remain in a non-online pending state

#### Scenario: Connected frame confirms online
- **WHEN** a valid `connected` frame is received on the active session
- **THEN** the device MUST transition to online state and publish online telemetry/status

### Requirement: Disconnect and auth failure handling
The device SHALL classify WebSocket failures by protocol outcome, including handshake `401` and close code `4409`.

#### Scenario: Handshake rejected with 401
- **WHEN** WebSocket upgrade fails with HTTP `401`
- **THEN** the device MUST classify the failure as SN/registration/auth configuration error and emit actionable diagnostics before retry

#### Scenario: Connection replaced with 4409
- **WHEN** the active connection is closed with code `4409`
- **THEN** the device MUST treat it as connection replacement behavior and continue lifecycle handling without fatal error classification

### Requirement: Exponential backoff reconnect strategy
The device SHALL reconnect after disconnect using exponential backoff delays starting at 1 second and doubling each failed attempt until a configured maximum delay.

#### Scenario: Progressive reconnect delays
- **WHEN** repeated reconnect attempts fail
- **THEN** retry delays MUST follow `1s`, `2s`, `4s`, ... until reaching the configured cap

#### Scenario: Reset backoff after successful session
- **WHEN** the device receives `connected` for a new session
- **THEN** the reconnect backoff attempt counter MUST reset to initial delay

### Requirement: Heartbeat and command acknowledgement protocol handling
The device transport SHALL support heartbeat and command acknowledgement message flows expected by the server contract.

#### Scenario: Heartbeat acknowledgement exchange
- **WHEN** the device sends `{\"type\":\"heartbeat\",\"timestamp\":...}`
- **THEN** the transport handler MUST accept and process the corresponding `heartbeat_ack` response frame

#### Scenario: Command ACK response emission
- **WHEN** a command is received and processed by the device
- **THEN** the device MUST emit an ACK payload containing command identity and status fields (including `commandId` and `data.code`) via the active connection
