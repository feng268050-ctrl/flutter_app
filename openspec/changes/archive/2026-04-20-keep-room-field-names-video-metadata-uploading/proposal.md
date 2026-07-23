## Why

Serializing `video.metadata` and `video.uploading` WebSocket payloads with **snake_case** keys duplicates naming that already exists on the Room entity (`ProcessParamsVideo`) in **camelCase**, forcing an extra mapping layer in builders and tests and making it harder to trace fields from DB row to wire format. Aligning JSON keys with the persisted/Java property names removes that translation cost and keeps one mental model for the same data.

## What Changes

- Update the product contract so `video.metadata` and `video.uploading` payloads use **camelCase** JSON keys that match the Room entity field naming (e.g. `videoId`, `uploadStatus`, `uploadProgress`, `videoUrl`), instead of snake_case (`video_id`, etc.).
- **BREAKING** for any server or consumer that already parses snake_case keys for these two message types; those parsers must accept camelCase (or be updated) before rollout.
- Implementation (out of scope for proposal text but covered in tasks): adjust payload builders, `DeviceWebSocketConnectionManager` helpers, and unit tests; no change to exclusion rules for local-only fields on `video.metadata` (`id`, `videoPath` still omitted).

## Capabilities

### New Capabilities

- None (contract update only on existing capabilities).

### Modified Capabilities

- `device-ws-video-metadata`: Payload key naming requirement changes from snake_case-only to camelCase aligned with `ProcessParamsVideo` / Room column property names; scenarios updated accordingly.
- `device-ws-video-uploading`: Minimum required payload keys change from snake_case to camelCase (`videoId`, `uploadStatus`, `uploadProgress`, `videoUrl`).

## Impact

- Android: `DeviceWsVideoMetadataPayload`, `DeviceWebSocketConnectionManager#sendVideoUploading` / `#sendVideoMetadata`, and related tests (`DeviceWsVideoMetadataPayloadTest`, `VideoUploadingWsEnvelopeTest`, any envelope assertions).
- Backend / analytics: consumers of `video.metadata` and `video.uploading` must align with camelCase keys (**BREAKING** unless they already accept both).
