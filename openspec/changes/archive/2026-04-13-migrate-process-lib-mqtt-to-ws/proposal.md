## Why

The full process library was historically delivered from the cloud over MQTT as `PROCESS_LIB` (`msgType` 2) and persisted through `ServerPushMessageHandler.saveProcessLibrary` (formerly `saveProcessLib`); MQTT ingest for that type is removed in the app. The product is consolidating server-initiated device data on WebSocket with explicit command/ack pairs (same pattern as `command.send_process_param`). Completing the WebSocket path avoids maintaining two transports for the same capability and lets operators correlate delivery with `command.send_process_lib_ack`. The normative domain aggregate for library payloads is **ProcessLibrary**. This change **includes** renaming the Java POJO `ProcessVersion` → **`ProcessLibrary`** and aligning handler/API/docs (small surface area; see design §「Java 类型重命名」).

## What Changes

- Handle inbound WebSocket frames with `type` `command.send_process_lib`, where `payload` carries the same logical content as today’s MQTT process-library message (the **ProcessLibrary** aggregate / existing DAO behavior in the library save entry).
- **Rename Java aggregate** `ProcessVersion` → **`ProcessLibrary`** (entity class + imports + `ServerPushMessageHandler` / any remaining `MQTTMessage<…>` wrapper such as `ProcessVersionMq` → `ProcessLibraryMq` if the wrapper class is kept); update `docs/network-api-reference.md` §5.7 and related prose. Wire JSON field names stay the same unless backend agrees otherwise.
- After handling completes, send `command.send_process_lib_ack` with a **new device-generated** top-level `id`, and `payload` containing `request_id` (inbound frame top-level `id`), numeric `code` (success vs failure, aligned with existing ack conventions such as `command.send_process_param_ack`), and string `message`.
- Introduce **transport-neutral** DTO/parser names for the WS path (no `Mq` / `MQTT` / `MQTTMessage` in public types used for this command); prefer the domain name **ProcessLibrary** for the aggregate type in new code when the identifier is not already taken (no `ProcessLibrary` class exists today; `ProcessLibraryImporter` is unrelated).
- Reuse the same persistence rules as today’s MQTT path (`ServerPushMessageHandler` / same DAO batching and device-info version side effects), refactored so the handler is not tied to `ProcessVersionMq` for this feature.
- Stop treating MQTT `PROCESS_LIB` as a supported ingest path once WS is authoritative (log-and-ignore or remove branch), so cloud integrations must use WebSocket. **BREAKING** for any backend that still pushes the library only over MQTT.

## Capabilities

### New Capabilities

- _(none — extends existing WebSocket envelope and device data handling.)_

### Modified Capabilities

- `device-ws-unified-envelope`: Add normative `type` values and payload/ack rules for `command.send_process_lib` (inbound) and `command.send_process_lib_ack` (outbound), mirroring the correlation pattern used for `command.send_process_param` / `_ack` (new outbound `id`, `payload.request_id` equals server inbound top-level `id`, `payload.code`, `payload.message`).
- `device-data-channel-abstraction`: Add normative requirements for WebSocket ingestion of the process-library push so persistence and observability match the MQTT adapter’s prior behavior for the same logical event (shared `ServerPushMessageHandler` entry, `DeviceDataEvent` / telemetry fields including `sourceProtocol` WebSocket).

## Impact

- **Code**: `DeviceWebSocketConnectionManager` (dispatch, ack sender), new neutral payload parser/model under `network/channel` or `bean/dto`, `ServerPushMessageHandler.saveProcessLibrary(ProcessLibrary)`; **`ProcessVersion` type removal** in favor of `ProcessLibrary`; MQTT stack no longer ingests `PROCESS_LIB` (already removed in tree).
- **Docs**: `docs/network-api-reference.md` — document `command.send_process_lib` / `_ack` and payload JSON shape.
- **Server contract**: Backend must emit `command.send_process_lib` and accept `command.send_process_lib_ack` with `payload.request_id` matching the inbound command frame’s top-level `id`.
