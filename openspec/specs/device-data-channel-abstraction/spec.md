## Purpose

Define a protocol-agnostic device data channel so adapters can ingest and report telemetry consistently across transports while preserving normalized events, validation behavior, and observability.
## Requirements
### Requirement: Protocol-agnostic device data ingestion
The system SHALL provide a protocol-agnostic ingestion interface for device data reporting, so upstream business handlers do not depend on transport-specific session lifecycle or payload envelope details.

#### Scenario: Ingest device data through channel interface
- **WHEN** a protocol adapter receives a device report
- **THEN** it MUST submit the report through the unified device data channel interface instead of invoking business handlers directly

#### Scenario: Gate online data stream by transport readiness
- **WHEN** a transport session is open but has not reached protocol online-ready state
- **THEN** the adapter MUST NOT publish the session as online data-ready until readiness confirmation is received

### Requirement: Standardized internal device data event
The system SHALL normalize incoming protocol payloads into a standard `DeviceDataEvent` model with required fields: `deviceId`, `eventType`, `payload`, `timestamp`, `correlationId`, and `sourceProtocol`.

#### Scenario: Normalize WebSocket payload to standard event
- **WHEN** the WebSocket device data adapter receives a valid telemetry or server-push message that is eligible for normalization into `DeviceDataEvent`
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

### Requirement: WebSocket process library ingestion uses shared persistence

When the device receives `command.send_process_lib` over WebSocket, it SHALL persist the **ProcessLibrary** aggregate using the same logical operations as the legacy MQTT `PROCESS_LIB` path (same DAO usage, batch replace rules for default and quick-mode data, and `DeviceInfo.processLibVersion` update behavior in the library save entry in `ServerPushMessageHandler` as implemented at the time of migration), not a divergent copy of persistence rules.

#### Scenario: Shared save path

- **WHEN** a valid `command.send_process_lib` payload is processed successfully
- **THEN** the resulting database state MUST match what would have resulted from processing an equivalent legacy MQTT `PROCESS_LIB` message for the same library content

### Requirement: WebSocket process library observability

The WebSocket ingestion path for `command.send_process_lib` SHALL emit protocol-appropriate observability for the device data path (structured logs and/or telemetry) including `deviceId` context, correlation using the inbound message top-level `id`, `sourceProtocol` indicating WebSocket, processing outcome, and latency, consistent with the MQTT device data channel pattern for comparable process-library events.

#### Scenario: Telemetry on success

- **WHEN** `command.send_process_lib` is processed successfully
- **THEN** the system MUST record a success outcome with correlation id equal to the inbound envelope `id` and protocol context for WebSocket

#### Scenario: Telemetry on processing failure

- **WHEN** `command.send_process_lib` processing throws or fails validation at the persistence layer
- **THEN** the system MUST record a failure outcome with the same correlation and protocol fields without silently dropping the attempt

### Requirement: Transport-neutral naming for WebSocket process library parsing

Types introduced solely to parse and carry `command.send_process_lib` payload data for the WebSocket path SHALL NOT include `Mq`, `MQTT`, or `MQTTMessage` in their type names. The normative domain aggregate name for library content is **ProcessLibrary**.

#### Scenario: Parser output type naming

- **WHEN** the WebSocket layer maps `payload` into a Java object prior to calling `ServerPushMessageHandler`
- **THEN** that object’s class name MUST NOT contain the substrings `Mq`, `MQTT`, or `MQTTMessage`

### Requirement: Java aggregate type rename

The implementation SHALL rename the Java POJO historically named `ProcessVersion` (library version metadata + `dataList` of `ProcessParametersData`) to **`ProcessLibrary`**, updating the entity source file, all imports, and the library persistence method on `ServerPushMessageHandler` to use **`ProcessLibrary`** as the parameter type (`saveProcessLibrary(ProcessLibrary)` or a single `saveProcessLib(ProcessLibrary)` entry point—one consistent public name). If a legacy `MQTTMessage` subclass is retained for Gson compatibility, it SHALL be renamed consistently (e.g. `ProcessVersionMq` → `ProcessLibraryMq`) and SHALL use `MQTTMessage<ProcessLibrary>`. Wire-level JSON property names for the aggregate SHALL remain unchanged unless explicitly agreed with the backend in a separate contract change.

#### Scenario: No library aggregate type named ProcessVersion

- **WHEN** this change is implemented to completion
- **THEN** the application source MUST NOT define a class `ProcessVersion` for the process-library aggregate (grep-clean under `app/` for that purpose), and `ServerPushMessageHandler` MUST accept `ProcessLibrary` for library persistence

#### Scenario: Documentation matches code

- **WHEN** the rename is complete
- **THEN** `docs/network-api-reference.md` MUST describe the aggregate under the name **`ProcessLibrary`** (e.g. §5.7 heading and prose) instead of `ProcessVersion`

### Requirement: WebSocket process parameter success notifies operator

When the device successfully persists an inbound `command.send_process_param` over WebSocket, the ingestion path SHALL trigger the operator-facing received-parameter confirmation dialog defined in **`remote-process-param-received-dialog`**, in addition to existing telemetry and ack behavior. Notification MUST occur only on successful persistence, not on validation or processing failure.

#### Scenario: Success path triggers UI notification

- **WHEN** `handleInboundSendProcessParam` completes persistence successfully
- **THEN** the system MUST schedule the received-parameter dialog on the main thread
- **AND** MUST still emit success telemetry and send `command.send_process_param_ack`

#### Scenario: Failure path skips UI notification

- **WHEN** `command.send_process_param` fails before or during persistence
- **THEN** the system MUST NOT schedule the received-parameter dialog
- **AND** MUST still record failure telemetry and send failure ack when applicable

