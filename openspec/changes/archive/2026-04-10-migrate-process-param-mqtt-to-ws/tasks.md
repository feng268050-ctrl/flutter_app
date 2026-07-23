## 1. Contract and parsing

- [x] 1.1 Confirm with backend the exact `payload` JSON for `command.send_process_param` (full `ProcessParametersDataMq`-shaped object vs `data`-only) and document it in `docs/network-api-reference.md`.
- [x] 1.2 Add a small parser helper (next to WS code or in `network/channel`) that builds `ProcessParametersDataMq` from the WS `payload` / Gson without duplicating field mapping logic (MQTT continues to use `MQTTMessageHandler.convertMsg` for wire JSON).

## 2. WebSocket handling and acknowledgement

- [x] 2.1 In `DeviceWebSocketConnectionManager.onInboundMessage`, handle `type` `command.send_process_param`: validate envelope, parse payload to `ProcessParametersDataMq`, run shared persistence on a background executor consistent with MQTT DB access.
- [x] 2.2 Implement `sendProcessParamAck(String requestId, int code, String message)` (or equivalent): allocate a **new** outbound message `id` (e.g. `DeviceWebSocketEnvelope.newUniqueMessageId()`), `payload` with `request_id`, `code`, `message` (`requestId` is the inbound frame’s top-level `id`), `type` `command.send_process_param_ack`, current time for `ts`.
- [x] 2.3 Ensure an ack is sent after handling completes per product decision (including whether parse/validation failures still send ack); align with `design.md` Open Questions if needed.

## 3. Shared persistence and telemetry

- [x] 3.1 Shared entry point for saving single process parameters: `ServerPushMessageHandler.saveProcessData` (used by `MqttDeviceDataChannel`; WS path must call it after parsing).
- [x] 3.2 Emit `DeviceChannelTelemetry` / `DeviceDataEvent` for the WS path with `sourceProtocol` WS, `correlationId` = inbound envelope `id`, and success/failure outcome matching `MqttDeviceDataChannel` patterns.

## 4. MQTT migration and cleanup

- [x] 4.1 Remove or disable `ONE_PROCESS_DATA` handling in `MqttDeviceDataChannel` and any subscription/dispatch that only exists for this path once backend cuts over (coordinate timing).
- [x] 4.2 Update `MQDataAdapterFactory`, `MQTTMsgEnums` usage in docs, and integration notes so `ONE_PROCESS_DATA` is no longer the supported transport for this feature.

## 5. Verification

- [x] 5.1 Add or extend unit tests for envelope parsing and ack JSON (`DeviceWebSocketConnectionTest` or new tests): inbound `command.send_process_param` produces outbound `command.send_process_param_ack` with a **new** top-level `id`, `payload.request_id` equal to the inbound `id`, and result fields `payload.code` / `payload.message`.
- [x] 5.2 Manual or integration check: end-to-end receive parameters over WS and confirm DB/UI-visible data matches previous MQTT behavior.
