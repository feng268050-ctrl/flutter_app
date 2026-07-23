## Why

Server consumers of `command.video_list_response` expect process parameters in the same shape and field name as `command.stat_response` (`processParameters` as a structured object), not a raw JSON string under `processData`. Aligning naming (`processParametersJson` at rest) and the wire payload reduces ambiguity and duplicate parsing rules on the server.

The legacy integer **`status`** column on `t_params_process_video` (0/1 “录制完成 / 上传完成”) is redundant with **`uploadStatus`** and is no longer read for product logic; it only adds writes and optional `video.metadata` noise. Removing it simplifies the schema and outbound payloads.

## What Changes

- **BREAKING** (wire): Each element of `command.video_list_response` `payload.data.list` SHALL expose parsed process parameters as **`processParameters`** (JSON object or JSON `null`), not `processData` (string).
- Persisted / in-app naming for the stored string column on the process-video row SHALL be clarified or renamed to **`processParametersJson`** where that string is referenced in APIs and code paths (Room column rename is in scope only if design chooses a DB migration; otherwise rename at the Java field / serialization boundary with column mapping).
- The device SHALL parse `processParametersJson` safely; invalid or missing JSON SHALL yield `processParameters: null` while keeping the list item otherwise valid.
- **BREAKING** (persistence + wire): Remove the legacy **`status`** column from `t_params_process_video`, remove `ProcessParamsVideo.status`, `ProcessProcessVideoDao.updateStatus`, and all call sites (`setStatus`, post-upload `updateStatus`). **`video.metadata`** payloads SHALL NOT include a `status` field. Upload lifecycle remains **`uploadStatus`** only.

## Capabilities

### New Capabilities

- _(none)_

### Modified Capabilities

- `device-ws-video-list-command`: Update normative list-item field rules: require `processParameters` (object or null); remove `processData` from the list contract; document parsing from stored JSON string.
- `device-ws-unified-envelope`: If the envelope spec references list item field names for `command.video_list_response`, align examples or cross-references with `processParameters`.
- `device-ws-video-metadata`: Remove `status` (and align `processData` naming with `processParametersJson` / payload shape if the requirement lists entity field names).
- `device-video-metadata`: Update local row requirements so the table no longer includes or references a legacy `status` column.

## Impact

- Android: `DeviceWsVideoListPayload`, `ProcessParamsVideo` / `ProcessParamsVideoVo`, `ProcessProcessVideoDao` queries, Room migrations if column renamed, any HTTP or WS payloads that still say `processData`; `CameraController`, `ProcessVideoViewModel`, `DeviceWebSocketConnectionManager`, `DeviceWsVideoMetadataPayload`, tests.
- Server / documentation: any consumer of `data.list[].processData` must switch to `data.list[].processParameters`; any consumer of `video.metadata.status` must drop it.
