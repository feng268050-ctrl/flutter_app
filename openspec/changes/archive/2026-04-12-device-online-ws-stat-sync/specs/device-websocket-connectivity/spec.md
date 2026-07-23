## REMOVED Requirements

### Requirement: Online readiness is gated by connected frame

**Reason:** Replaced by **transport-open** gating so the device can send `device.online` immediately without any inbound prerequisite message; `connected` is removed from the lifecycle contract.

**Migration:** See `device-ws-unified-envelope` removal of **Server connected payload**. Coordinate server rollout; redefine monitoring that assumed “online after `connected` text”.

## MODIFIED Requirements

### Requirement: Exponential backoff reconnect strategy

The device SHALL reconnect after disconnect using exponential backoff delays starting at 1 second and doubling each failed attempt until a configured maximum delay.

#### Scenario: Progressive reconnect delays

- **WHEN** repeated reconnect attempts fail
- **THEN** retry delays MUST follow `1s`, `2s`, `4s`, ... until reaching the configured cap

#### Scenario: Reset backoff after successful session

- **WHEN** the WebSocket **transport successfully opens** for a new session (handshake complete, socket ready for application frames)
- **THEN** the reconnect backoff attempt counter MUST reset to initial delay

## ADDED Requirements

### Requirement: Online readiness is gated by WebSocket transport open

The device SHALL consider itself **online** (able to send outbound business frames such as `device.online`, `command.stat_response`, and command-related traffic per existing rules) when the WebSocket **transport** for the active `/ws/device` session has **successfully opened**—i.e. the secure WebSocket upgrade has completed and the client may send application text frames on that socket—without requiring any prior inbound JSON text frame. When transitioning to online under this rule, the device SHALL emit the same **online telemetry and status publication** side effects that apply whenever the connection manager enters online state (replacing the prior trigger that ran after a valid `connected` frame).

#### Scenario: Transport open implies online without inbound text

- **WHEN** the WebSocket transport reports open for the active session and no inbound application frame has been processed yet
- **THEN** the device MUST be in online state for outbound purposes per this requirement

#### Scenario: Inbound connected does not gate online

- **WHEN** the server sends no `connected` frame (or sends one only as a legacy artifact)
- **THEN** the device MUST still reach online state at transport open and MUST NOT require `connected` for that transition

#### Scenario: Online telemetry when entering online from transport open

- **WHEN** the device transitions to online because the WebSocket transport has opened
- **THEN** the connection manager MUST publish online telemetry/status consistent with entering online state elsewhere in the product (no regression solely caused by removing `connected` gating)

### Requirement: Push remote snapshot immediately after transport open

When the WebSocket transport successfully opens for a session (including after a reconnect), the device SHALL attempt to send exactly one outbound `device.online` frame for that transport-open event, as defined in `device-ws-unified-envelope`. The attempt SHALL be scheduled **immediately** from the transport-open lifecycle point (no wait for inbound server text). The send SHALL NOT depend on a prior inbound `command.stat_request`.

#### Scenario: First open after connect

- **WHEN** the WebSocket transport opens for a newly established session
- **THEN** the device MUST attempt to emit `device.online` on that session using the current remote snapshot as `payload`

#### Scenario: Reconnect obtains a new push

- **WHEN** the WebSocket transport opens again after a disconnect and a new session is established
- **THEN** the device MUST again attempt to emit `device.online` for that new transport-open event
