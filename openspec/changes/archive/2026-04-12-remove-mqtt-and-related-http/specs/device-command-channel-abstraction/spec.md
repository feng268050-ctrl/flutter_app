## MODIFIED Requirements

### Requirement: Protocol-agnostic command dispatch interface

The system SHALL provide a unified command dispatch interface that allows business services to issue device commands without transport-specific publish or session logic for the supported device transport.

#### Scenario: Dispatch command via abstracted channel

- **WHEN** a business workflow requests sending a device command
- **THEN** the command MUST be sent through the unified command channel interface rather than invoking WebSocket client APIs directly from business code

### Requirement: Unified observability and rollback-safe routing

The system SHALL emit protocol-independent command metrics/logs for the WebSocket command transport and SHALL preserve consistent acknowledgement semantics on that transport. The system SHALL NOT operate an MQTT command transport or perform silent cross-transport fallback for command delivery.

#### Scenario: Record command path telemetry

- **WHEN** a command is dispatched, acknowledged, fails, or times out
- **THEN** the system MUST emit structured metrics/logs with `deviceId`, `correlationId`, lifecycle state, and transport context for the active command channel

#### Scenario: Preserve ACK schema for command results

- **WHEN** the command channel receives a command acknowledgement result
- **THEN** the command channel MUST normalize and record the acknowledgement using the common model fields (`correlationId`, status, code, and timestamps)
