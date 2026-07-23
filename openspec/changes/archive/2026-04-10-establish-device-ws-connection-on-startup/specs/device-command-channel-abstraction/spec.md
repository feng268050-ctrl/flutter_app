## MODIFIED Requirements

### Requirement: Unified command lifecycle state handling
The system SHALL track each command through a consistent lifecycle state machine: `accepted`, `dispatched`, `acknowledged`, `failed`, and `timeout`, and SHALL bind lifecycle progression to active transport session readiness.

#### Scenario: Update lifecycle on device acknowledgement
- **WHEN** a device acknowledgement is received for a known correlation ID
- **THEN** the command lifecycle state MUST transition from `dispatched` to `acknowledged`

#### Scenario: Defer command dispatch until session online
- **WHEN** the selected transport session is connected at socket level but has not yet received protocol readiness confirmation
- **THEN** the command channel MUST NOT mark command dispatch as successful until the session is online-ready

### Requirement: Unified observability and rollback-safe routing
The system SHALL emit protocol-independent command metrics/logs and support feature-flag-based protocol routing with MQTT as the default fallback path, while preserving consistent ACK semantics across routed transports.

#### Scenario: Fall back to MQTT when routed protocol unavailable
- **WHEN** protocol routing selects a non-default adapter that is unavailable or disabled
- **THEN** the system MUST route command delivery through the MQTT adapter and record a fallback event

#### Scenario: Preserve ACK schema across transport protocols
- **WHEN** a routed protocol adapter emits a command acknowledgement result
- **THEN** the command channel MUST normalize and record the acknowledgement using the common model fields (`correlationId`, status, code, and timestamps)
