## MODIFIED Requirements

### Requirement: Protocol-agnostic device data ingestion
The system SHALL provide a protocol-agnostic ingestion interface for device data reporting, so upstream business handlers do not depend on transport-specific session lifecycle or payload envelope details.

#### Scenario: Ingest device data through channel interface
- **WHEN** a protocol adapter receives a device report
- **THEN** it MUST submit the report through the unified device data channel interface instead of invoking business handlers directly

#### Scenario: Gate online data stream by transport readiness
- **WHEN** a transport session is open but has not reached protocol online-ready state
- **THEN** the adapter MUST NOT publish the session as online data-ready until readiness confirmation is received

### Requirement: Unified observability for device data path
The system SHALL emit consistent logs and metrics for device data ingestion regardless of protocol, including fields `deviceId`, `correlationId`, `sourceProtocol`, processing result, and latency, and SHALL capture protocol keepalive outcomes.

#### Scenario: Record protocol-independent telemetry metric
- **WHEN** a normalized device data event completes processing
- **THEN** the system MUST emit a success/failure metric and structured log using the unified field schema

#### Scenario: Record heartbeat acknowledgement event
- **WHEN** a transport adapter receives a heartbeat acknowledgement from server
- **THEN** the data channel telemetry layer MUST emit a keepalive success signal with protocol and device context
