## Purpose

Define a protocol-agnostic command channel contract so business workflows can dispatch commands consistently on the WebSocket transport with unified lifecycle, ACK handling, and observability.

## Requirements

### Requirement: Protocol-agnostic command dispatch interface
The system SHALL provide a unified command dispatch interface that allows business services to issue device commands without transport-specific publish or session logic for the supported device transport.

#### Scenario: Dispatch command via abstracted channel
- **WHEN** a business workflow requests sending a device command
- **THEN** the command MUST be sent through the unified command channel interface rather than invoking WebSocket client APIs directly from business code

### Requirement: Standardized command request and result models
The system SHALL represent outbound command requests and inbound command results using standard models that include `deviceId`, `commandType`, `payload`, `correlationId`, `sourceProtocol`, `status`, and timestamps.

#### Scenario: Build standardized request before transport
- **WHEN** a command is accepted for dispatch
- **THEN** the system MUST create a standardized command request model before invoking protocol adapter send behavior

### Requirement: Unified command lifecycle state handling
The system SHALL track each command through a consistent lifecycle state machine: `accepted`, `dispatched`, `acknowledged`, `failed`, and `timeout`, and SHALL bind lifecycle progression to active transport session readiness.

#### Scenario: Update lifecycle on device acknowledgement
- **WHEN** a device acknowledgement is received for a known correlation ID
- **THEN** the command lifecycle state MUST transition from `dispatched` to `acknowledged`

#### Scenario: Defer command dispatch until session online
- **WHEN** the selected transport session is connected at socket level but has not yet received protocol readiness confirmation
- **THEN** the command channel MUST NOT mark command dispatch as successful until the session is online-ready

### Requirement: Timeout and duplicate acknowledgement handling
The system SHALL enforce configurable command timeout behavior and idempotent handling of duplicate acknowledgements per `correlationId`.

#### Scenario: Mark command as timeout without acknowledgement
- **WHEN** no acknowledgement is received within the configured timeout window
- **THEN** the command MUST transition to `timeout` and emit a timeout event for monitoring

### Requirement: Unified observability and rollback-safe routing
The system SHALL emit protocol-independent command metrics/logs for the WebSocket command transport and SHALL preserve consistent acknowledgement semantics on that transport. The system SHALL NOT operate an MQTT command transport or perform silent cross-transport fallback for command delivery.

#### Scenario: Record command path telemetry
- **WHEN** a command is dispatched, acknowledged, fails, or times out
- **THEN** the system MUST emit structured metrics/logs with `deviceId`, `correlationId`, lifecycle state, and transport context for the active command channel

#### Scenario: Preserve ACK schema for command results
- **WHEN** the command channel receives a command acknowledgement result
- **THEN** the command channel MUST normalize and record the acknowledgement using the common model fields (`correlationId`, status, code, and timestamps)
