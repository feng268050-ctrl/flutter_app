## ADDED Requirements

### Requirement: Protocol-agnostic command dispatch interface
The system SHALL provide a unified command dispatch interface that allows business services to issue device commands without protocol-specific publish or session logic.

#### Scenario: Dispatch command via abstracted channel
- **WHEN** a business workflow requests sending a device command
- **THEN** the command MUST be sent through the unified command channel interface rather than direct MQTT operations

### Requirement: Standardized command request and result models
The system SHALL represent outbound command requests and inbound command results using standard models that include `deviceId`, `commandType`, `payload`, `correlationId`, `sourceProtocol`, `status`, and timestamps.

#### Scenario: Build standardized request before transport
- **WHEN** a command is accepted for dispatch
- **THEN** the system MUST create a standardized command request model before invoking protocol adapter send behavior

### Requirement: Unified command lifecycle state handling
The system SHALL track each command through a consistent lifecycle state machine: `accepted`, `dispatched`, `acknowledged`, `failed`, and `timeout`.

#### Scenario: Update lifecycle on device acknowledgement
- **WHEN** a device acknowledgement is received for a known correlation ID
- **THEN** the command lifecycle state MUST transition from `dispatched` to `acknowledged`

### Requirement: Timeout and duplicate acknowledgement handling
The system SHALL enforce configurable command timeout behavior and idempotent handling of duplicate acknowledgements per `correlationId`.

#### Scenario: Mark command as timeout without acknowledgement
- **WHEN** no acknowledgement is received within the configured timeout window
- **THEN** the command MUST transition to `timeout` and emit a timeout event for monitoring

### Requirement: Unified observability and rollback-safe routing
The system SHALL emit protocol-independent command metrics/logs and support feature-flag-based protocol routing with MQTT as the default fallback path.

#### Scenario: Fall back to MQTT when routed protocol unavailable
- **WHEN** protocol routing selects a non-default adapter that is unavailable or disabled
- **THEN** the system MUST route command delivery through the MQTT adapter and record a fallback event
