## ADDED Requirements

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
