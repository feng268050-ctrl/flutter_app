## MODIFIED Requirements

### Requirement: Standardized internal device data event

The system SHALL normalize incoming protocol payloads into a standard `DeviceDataEvent` model with required fields: `deviceId`, `eventType`, `payload`, `timestamp`, `correlationId`, and `sourceProtocol`.

#### Scenario: Normalize WebSocket payload to standard event

- **WHEN** the WebSocket device data adapter receives a valid telemetry or server-push message that is eligible for normalization into `DeviceDataEvent`
- **THEN** it MUST produce a `DeviceDataEvent` containing all required fields before handing off to business processing

### Requirement: WebSocket process parameter ingestion uses shared persistence

When the device receives `command.send_process_param` over WebSocket, it SHALL persist process parameters using the same logical persistence operations as other supported server-push process-parameter ingestion for this app version (same data typing, DAO usage, and `ServerPushMessageHandler.saveProcessData` entry points), not a divergent copy of persistence rules.

#### Scenario: Shared save path

- **WHEN** a valid `command.send_process_param` payload is processed successfully
- **THEN** the resulting database state MUST match what would have resulted from processing another valid `command.send_process_param` payload with equivalent parameter content on the same app version

### Requirement: WebSocket process parameter observability

The WebSocket ingestion path for `command.send_process_param` SHALL emit protocol-appropriate observability for the device data path (structured logs and/or telemetry) including `deviceId` context, correlation using the inbound message `id`, `sourceProtocol` indicating WebSocket, processing outcome, and latency.

#### Scenario: Telemetry on success

- **WHEN** `command.send_process_param` is processed successfully
- **THEN** the system MUST record a success outcome with correlation id equal to the inbound envelope `id` and protocol context for WebSocket

#### Scenario: Telemetry on processing failure

- **WHEN** `command.send_process_param` processing throws or fails validation at the persistence layer
- **THEN** the system MUST record a failure outcome with the same correlation and protocol fields without silently dropping the attempt
