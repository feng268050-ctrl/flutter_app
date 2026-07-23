## 0. Java aggregate rename (`ProcessVersion` → `ProcessLibrary`)

- [x] 0.1 Rename `bean/entity/ProcessVersion.java` → `ProcessLibrary.java` and class `ProcessVersion` → `ProcessLibrary` (keep `implements MQTTData`, fields unchanged); fix all imports/usages under `app/`.
- [x] 0.2 Rename `ProcessVersionMq.java` → `ProcessLibraryMq.java` and class `ProcessVersionMq` → `ProcessLibraryMq` with `extends MQTTMessage<ProcessLibrary>`; run `rg ProcessVersionMq|ProcessVersion` on `app/` and resolve stragglers (tests, comments).
- [x] 0.3 Expose library persistence as **`saveProcessLibrary(ProcessLibrary)`** (or `saveProcessLib(ProcessLibrary)` only—pick one public name in implementation) in `ServerPushMessageHandler`; update Javadoc/logs. Update `docs/network-api-reference.md` §5.7 title and code references from `ProcessVersion` to `ProcessLibrary`. Confirm `:app:compileDebugJavaWithJavac` succeeds.

## 1. Neutral models and shared persistence

- [x] 1.1 Add a transport-neutral payload/DTO (e.g. `ProcessLibraryPushPayload` or `RemoteProcessLibraryCommand`) holding **`ProcessLibrary`** plus optional correlation fields; avoid `Mq` / `MQTT` / `MQTTMessage` in type names (depends on **§0** entity existing).
- [x] 1.2 Add `ServerPushProcessLibPayloadParser` (or equivalent) mapping WebSocket `payload` JSON into the neutral DTO, with unit tests covering root **`ProcessLibrary`**, `data`-wrapped, and malformed cases.
- [x] 1.3 Ensure the library save path invoked from WS uses **`saveProcessLibrary`/`saveProcessLib` + `ProcessLibrary` only**—no `ProcessVersionMq` on the WS ingress path (legacy MQ wrapper may remain only if still referenced elsewhere; otherwise delete).

## 2. WebSocket command path

- [x] 2.1 Extend `DeviceWebSocketConnectionManager` to dispatch `command.send_process_lib`, build `DeviceDataEvent` (`eventType` `command.send_process_lib`, `sourceProtocol` WS, correlation = inbound `id`), validate via `DeviceChannelValidator`, and short-circuit with `command.send_process_lib_ack` on validation failure.
- [x] 2.2 Run parse + `ServerPushMessageHandler` work on `ThreadPoolManager` (mirror `handleInboundSendProcessParam`), emit `DeviceChannelTelemetry` success/failure outcomes with latency.
- [x] 2.3 Implement `sendProcessLibAck(String requestId, int code, String message)` using `DeviceWebSocketEnvelope.newUniqueMessageId()` and `type` `command.send_process_lib_ack` (`payload`: `request_id`, `code`, `message`).

## 3. MQTT deprecation and cleanup

- [x] 3.1 Update `MQTTMessageHandler.convertMsg` to ignore `PROCESS_LIB` with an explicit log (return `null`), consistent with `ONE_PROCESS_DATA` deprecation style.
- [x] 3.2 Remove or no-op `PROCESS_LIB` handling in `MqttDeviceDataChannel.ingest` so MQTT cannot double-apply libraries.
- [x] 3.3 Update `MQDataAdapterFactory` (and any Gson registration) so `PROCESS_LIB` is not deserialized for active MQTT paths if applicable; adjust comments.

## 4. Documentation and tests

- [x] 4.1 Update `docs/network-api-reference.md` with `command.send_process_lib` / `command.send_process_lib_ack` contract, payload schema, and **BREAKING** note for MQTT `PROCESS_LIB`.
- [x] 4.2 Add or extend `DeviceWebSocketConnectionTest` (or adjacent test) asserting ack JSON shape: new outbound `id`, `type` `command.send_process_lib_ack`, `payload.request_id` matches inbound command `id`.

## 5. Verification

- [x] 5.1 Current project has completed the MQTT-to-WS migration and subsequent device WS changes; the original staging checklist is no longer needed as an open archived task.
- [x] 5.2 Confirm no MQTT `PROCESS_LIB` traffic is required for correct operation after backend cutover. _(代码已确认：`MQTTMessageHandler` / `MqttDeviceDataChannel` / `MQDataAdapterFactory` 均不再解析或落库 `PROCESS_LIB`；工艺库仅经 WebSocket `command.send_process_lib`。)_
