## ADDED Requirements

### Requirement: WebSocket process parameter ingestion uses shared persistence
When the device receives `command.send_process_param` over WebSocket, it SHALL persist process parameters using the same logical operations as the MQTT `ONE_PROCESS_DATA` path (same data typing, DAO usage, and `ServerPushMessageHandler.saveProcessData`), not a divergent copy of persistence rules.

#### Scenario: Shared save path
- **WHEN** a valid `command.send_process_param` payload is processed successfully
- **THEN** the resulting database state MUST match what would have resulted from processing an equivalent MQTT `ONE_PROCESS_DATA` message for the same parameter content

### Requirement: WebSocket process parameter observability
The WebSocket ingestion path for `command.send_process_param` SHALL emit protocol-appropriate observability for the device data path (structured logs and/or telemetry) including `deviceId` context, correlation using the inbound message `id`, `sourceProtocol` indicating WebSocket, processing outcome, and latency, consistent with the MQTT device data channel pattern for comparable events.

#### Scenario: Telemetry on success
- **WHEN** `command.send_process_param` is processed successfully
- **THEN** the system MUST record a success outcome with correlation id equal to the inbound envelope `id` and protocol context for WebSocket

#### Scenario: Telemetry on processing failure
- **WHEN** `command.send_process_param` processing throws or fails validation at the persistence layer
- **THEN** the system MUST record a failure outcome with the same correlation and protocol fields without silently dropping the attempt
