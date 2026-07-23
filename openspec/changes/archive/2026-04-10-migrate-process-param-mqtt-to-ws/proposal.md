## Why

Single process-parameter push today arrives over MQTT as `ONE_PROCESS_DATA` and is persisted via existing handlers. The product is standardizing device control and data on WebSocket; this path should follow the unified envelope and command-style messaging so the server can correlate work with explicit acknowledgements. Migrating now avoids maintaining two transports for the same capability.

## What Changes

- Handle inbound WebSocket frames with `type` `command.send_process_param`, where `payload` carries the same process-parameter content that today is carried in the MQTT `ONE_PROCESS_DATA` message body (shape compatible with existing parsing / `ProcessParametersData` persistence).
- After handling, send an outbound frame with `type` `command.send_process_param_ack` using a **new device-generated** top-level message `id`, and `payload` containing `request_id` (inbound frame `id`), `code` (`200` success / `500` failure), and `message` (failure reason or success note).
- Reuse the transport-agnostic persistence entry `ServerPushMessageHandler.saveProcessData` (already used by `MqttDeviceDataChannel` for MQTT `ONE_PROCESS_DATA`) so validation, DB writes, and logging stay consistent when adding the WebSocket path.
- Stop treating MQTT `ONE_PROCESS_DATA` as the supported delivery path for this feature (or gate it off once WS is authoritative), so the server and operators use WS only. **BREAKING** for any integration that still sends only MQTT for single process parameters.

## Capabilities

### New Capabilities

- _(none — behavior extends existing WebSocket envelope and device data/command handling.)_

### Modified Capabilities

- `device-ws-unified-envelope`: Add normative `type` values and payload rules for `command.send_process_param` (inbound) and `command.send_process_param_ack` (outbound), including a new outbound `id` and `payload.request_id` referencing the server’s inbound `id`.
- `device-data-channel-abstraction`: Clarify that the WebSocket adapter may ingest server-initiated process-parameter payloads through the same normalization / observability expectations as other device data paths (e.g. `DeviceDataEvent`, telemetry), aligned with MQTT adapter behavior for the same logical event.

## Impact

- **Code**: `DeviceWebSocketConnectionManager` (inbound `type` dispatch, new ack sender), possibly `DeviceWebSocketEnvelope` helpers; `ServerPushMessageHandler` for shared persistence; MQTT stack (`MqttDeviceDataChannel`, `MQTTMessageHandler` for ingest/response only, `MQDataAdapterFactory`) if MQTT ingestion is removed or deprecated for this message type.
- **Docs**: `docs/network-api-reference.md` (message type table / WS section).
- **Server contract**: Backend must emit `command.send_process_param` and accept `command.send_process_param_ack` whose `payload.request_id` matches the `id` it sent on the command frame (outbound ack uses a new message `id`).
