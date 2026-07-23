## Why

Mobile apps and LAN tools need to read and manage **engineer-mode process library** entries (saved parameter sets in `t_process_parameters_data`) on the HMI device without using the on-device UI. Process **videos** already support remote list/delete over WebSocket and **`GET/DELETE /v1/videos`** on the embedded LAN server; engineer-mode presets lack an equivalent surface. A dual **WebSocket command** and **local HTTP API** contract keeps remote clients aligned with existing device patterns (`command.*_request` / `command.*_response`, `command.*_ack`, `ApiResult`).

## What Changes

- Add inbound WebSocket commands for engineer-mode process library CRUD and “set active preset”:
  - `command.process_library_request` / `command.process_library_response` — list summary rows by `process_type`
  - `command.process_parameters_create` / `command.process_parameters_create_ack`
  - `command.process_parameters_request` / `command.process_parameters_response`
  - `command.process_parameters_update` / `command.process_parameters_update_ack`
  - `command.process_parameters_delete` / `command.process_parameters_delete_ack`
  - `command.process_parameters_set_default` / `command.process_parameters_set_default_ack`
- Add matching routes on the existing **`0.0.0.0:8080`** local HTTP server under **`/v1`**, using **kebab-case** paths and **camelCase** query/body fields; responses use **`ApiResult`** (`success`, `code`, `message`, `data`).
- Extract shared **`ProcessParametersRemoteService`** (name TBD) used by `DeviceWebSocketConnectionManager` and `DeviceLocalHttpServer`, mirroring `ProcessVideoQueryService` for videos.
- Reuse `ProcessParametersData` / `ProcessParametersNameData` Gson field names (`name`, `materialType`, `materialName`, etc.) and engineer-mode visibility rules (`dataType` in `ENGINEER_MODE_DEFAULT_DATA` / `ENGINEER_MODE_CUSTOM_DATA` only).
- **WebSocket** row **`id`** / **`originId`**: inbound accepts string or number; outbound serializes as **string** (JS safe integer). **HTTP** keeps numeric `id` in paths and `ApiResult`.
- Mutating operations SHALL run off the main thread; successful create/update/delete/set-default SHALL refresh `ProcessParametersSnapshotStore` when the affected row is the active preset for that `processType`.

## Capabilities

### New Capabilities

- `device-ws-process-library-remote`: WebSocket envelope, payload fields (snake_case in `payload`), request/response correlation, and ack shape (`request_id` + `data.success` / `data.message`) for all process-library commands.
- `device-local-http-process-library`: LAN HTTP routes under `/v1` for the same operations with camelCase parameters and `ApiResult` envelopes.

### Modified Capabilities

- `device-ws-unified-envelope`: Document inbound/outbound types for the six new `command.process_*` message pairs (alongside existing `command.video_*` / `command.delete_video` patterns).

## Impact

- **Code**: `DeviceWebSocketConnectionManager` (new dispatch branches), `DeviceLocalHttpServer` (new routes), new remote service + optional DAO sync queries for engineer list/by-id; may refactor `ProcessParametersDataViewModel` helpers for create/save/delete/switch/set-default.
- **Data**: Room table `t_process_parameters_data` — no schema migration; business rules restrict remote delete to custom rows and scope list to engineer-mode types.
- **Docs**: Extend `docs/network-api-reference.md` with WS + local HTTP process-library sections.
- **Clients**: Server/mobile must use new command types or `/v1/process-library` / `/v1/process-parameters*` paths; no cloud Worker API change in this proposal.
