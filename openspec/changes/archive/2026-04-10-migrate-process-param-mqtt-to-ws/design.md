## Context

- Today, a single process-parameter update from the cloud is delivered over MQTT as `ONE_PROCESS_DATA` (`msgType` 1). `MqttDeviceDataChannel.ingest` parses the JSON via `MQTTMessageHandler.convertMsg`, validates a `DeviceDataEvent`, calls `ServerPushMessageHandler.saveProcessData` for `ProcessParametersDataMq`, and logs via `DeviceChannelTelemetry`. `MQTTMessageHandler` (MQTT-only) orchestrates ingest and `response`, which publishes MQTT `ResponseMsgMq` and sends a generic WS `ack` frame (legacy side path).
- The device already maintains a unified WebSocket session in `DeviceWebSocketConnectionManager`, parsing inbound frames with `DeviceWebSocketEnvelope` and handling `connected`, `heartbeat_ack`, `ack`, and a stub `command` type.
- The user requirement is to move this **single process parameter** path to WS: listen for `command.send_process_param`, reuse the same persistence logic as MQTT, and reply with `command.send_process_param_ack` using a **new** outbound envelope `id` while setting `payload.request_id` to the server’s inbound message `id`, plus `payload.code` / `payload.message` to describe result.

## Goals / Non-Goals

**Goals:**

- Parse inbound WS `command.send_process_param` and persist using the same code path as MQTT `ONE_PROCESS_DATA` (same `ProcessParametersData` handling, `ENGINEER_MODE_CUSTOM_DATA`, DAO behavior).
- Send `command.send_process_param_ack` after processing completes, with a **new** outbound `id` (device-originated, globally unique like other outbound frames) and `payload` `{ "request_id": "<inbound id>", "code": 200|500, "message": "<result>" }`.
- Keep observability consistent (structured logging / `DeviceChannelTelemetry` pattern analogous to `MqttDeviceDataChannel`).
- Align server and documentation with the new types.

**Non-Goals:**

- Changing Modbus/local “下发工艺参数” from the UI (`GeneralOperationsFragment.sendProcessConfigData`, etc.).
- Migrating other MQTT data types (`PROCESS_LIB`, `DEVICE_INFO`, etc.) to WS in this change.
- Redesigning the full command framework beyond this one command/ack pair (unless minimal hooks are required).

## Decisions

1. **Payload shape on WS**  
   **Decision**: Treat `payload` as the source for the same logical content MQTT carried in `ProcessParametersDataMq` (fields such as `data`, optional `msgId` / `timestamp` / `version` per `MQTTMessage`). Prefer one canonical mapping agreed with backend: either embed the full MQTT-shaped JSON inside `payload`, or embed only `data` and synthesize wrapper fields in the client.  
   **Rationale**: Minimizes changes inside `ServerPushMessageHandler.saveProcessData` if we can still build a `ProcessParametersDataMq` instance.  
   **Alternative**: Re-serialize payload to a fake MQTT JSON string and call `convertMsg` — possible but obscures errors; direct Gson mapping into `ProcessParametersDataMq` is clearer.

2. **Where dispatch lives**  
   **Decision**: Extend `DeviceWebSocketConnectionManager.onInboundMessage` (or a small helper it calls) to branch on `command.send_process_param`, parse payload into `ProcessParametersDataMq`, call `ServerPushMessageHandler.saveProcessData`, then send the ack. Persistence is already centralized in `ServerPushMessageHandler` (shared with MQTT).  
   **Rationale**: WS lifecycle and send already live here; keeps one place for inbound routing until a fuller `WsDeviceDataChannel` exists.

3. **Ack send API**  
   **Decision**: Add a dedicated send method (e.g. `sendProcessParamAck(String requestId, int code, String message)`) that generates a **new** message id via `DeviceWebSocketEnvelope.newUniqueMessageId()`, builds `payload` as `{"request_id": requestId, "code": code, "message": message}` where `requestId` is the inbound frame’s top-level `id`, and calls `DeviceWebSocketEnvelope.toJson("command.send_process_param_ack", payload, newId, now)`.  
   **Rationale**: Keeps outbound ids unique while giving server explicit success/failure and reason without additional message types.

4. **MQTT deprecation**  
   **Decision**: Remove or no-op `ONE_PROCESS_DATA` handling in `MqttDeviceDataChannel` / subscription path once WS is verified, and update `docs/network-api-reference.md`. Coordinate rollout with backend so MQTT is not relied on for this message.  
   **Rationale**: True migration avoids dual sources of truth.

5. **Failure behavior**  
   **Decision**: Match MQTT’s try/catch behavior: on persistence exception, still send `command.send_process_param_ack` (new outbound `id`, `payload.request_id` set) if the spec requires an ack for every handled attempt; if product requires distinguishing failure, that can be a follow-up (extra payload fields or separate type) — failures remain visible via logs/telemetry.

## Risks / Trade-offs

- **[Risk] Payload mismatch** between server and existing Gson models → parse errors or silent partial data. **Mitigation**: Contract test or sample JSON in docs; strict logging on parse failure; coordinate with backend on exact `payload` schema.
- **[Risk] Rolling upgrade** where server still sends MQTT only. **Mitigation**: Feature flag or temporary dual subscribe until backend cuts over; document order of deployment.
- **[Risk] Threading** — WS callback thread vs DB access rules. **Mitigation**: Mirror MQTT’s executor pattern if main-thread constraints apply (today MQTT uses `ThreadPoolManager` in `handleMessage`; WS may need the same for DB).

## Migration Plan

1. Implement WS receive + ack + shared persistence.
2. Deploy backend emitting `command.send_process_param` and consuming `command.send_process_param_ack`.
3. Verify on staging; then disable MQTT `ONE_PROCESS_DATA` handling and update docs.
4. Rollback: re-enable MQTT branch and pause WS command until fixed.

## Open Questions

- _(Resolved for implementation)_ `payload`: documented in `docs/network-api-reference.md` §5.6 / §6 — supports MQTT-shaped object (with `data`) or bare `ProcessParametersData` at root.
- _(Resolved for implementation)_ Parse / validation failures still send `command.send_process_param_ack` so the server can correlate via `request_id`.
