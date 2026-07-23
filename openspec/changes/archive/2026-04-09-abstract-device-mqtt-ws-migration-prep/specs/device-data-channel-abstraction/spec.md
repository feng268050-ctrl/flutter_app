## ADDED Requirements

### Requirement: Protocol-agnostic device data ingestion
The system SHALL provide a protocol-agnostic ingestion interface for device data reporting, so upstream business handlers do not depend on MQTT-specific topics or payload formats.

#### Scenario: Ingest device data through channel interface
- **WHEN** a protocol adapter receives a device report
- **THEN** it MUST submit the report through the unified device data channel interface instead of invoking business handlers directly

### Requirement: Standardized internal device data event
The system SHALL normalize incoming protocol payloads into a standard `DeviceDataEvent` model with required fields: `deviceId`, `eventType`, `payload`, `timestamp`, `correlationId`, and `sourceProtocol`.

#### Scenario: Normalize MQTT payload to standard event
- **WHEN** MQTT adapter receives a valid telemetry message
- **THEN** it MUST produce a `DeviceDataEvent` containing all required fields before handing off to business processing

### Requirement: Validation and error classification for reported data
The system SHALL validate normalized device data events and classify failures into explicit categories (e.g., malformed payload, missing required fields, unsupported event type, processing failure).

#### Scenario: Reject malformed incoming report
- **WHEN** a received device report cannot be normalized or fails validation
- **THEN** the system MUST reject processing and emit a classified error record with protocol and device context

### Requirement: Unified observability for device data path
The system SHALL emit consistent logs and metrics for device data ingestion regardless of protocol, including fields `deviceId`, `correlationId`, `sourceProtocol`, processing result, and latency.

#### Scenario: Record protocol-independent telemetry metric
- **WHEN** a normalized device data event completes processing
- **THEN** the system MUST emit a success/failure metric and structured log using the unified field schema
