## Why

The server already learns live process-video inventory via `command.video_list_request` / `command.video_list_response`, so duplicating the same facts through a separate Worker multipart metadata upload adds latency, failure modes, and two sources of truth. Aligning the device model around **cover-first R2 upload** plus a lightweight **WebSocket metadata** push keeps uploads coherent and matches the exploration-stage server contract.

## What Changes

- **BREAKING**: Rename SQLite/Room column `syncStatus` to `uploadStatus` on `t_params_process_video` (entity and migrations as required by project conventions).
- **BREAKING**: Remove the Worker `POST /v1/devices/:sn/videos/metadata` multipart pipeline and related WorkManager “metadata-only” backlog drain; do not sync full video metadata to the Worker for this flow.
- **BREAKING**: Rename `VideoSyncStatus` to `VideoUploadStatus` and redefine meaning: value `1` is **`CoverUploaded`** (cover object successfully uploaded and `coverUrl` persisted), not “metadata uploaded via HTTP”.
- After a successful **presigned PUT** of the JPEG cover (per `device-r2-presigned-upload` key layout), persist `coverUrl` from the presign/PUT result, set `uploadStatus` to `1` (`CoverUploaded`), and emit a WebSocket message `video.metadata` whose JSON payload uses **snake_case** keys and includes all logical metadata fields **except** `id` and `video_path` / `videoPath`.
- Update **Monitor list upload** and any progress reporting (`video.uploading`) to use `uploadStatus` / consistent snake_case field names where the spec defines wire keys, and to treat “cover done” as the new prerequisite before STS video byte transfer instead of HTTP metadata success.
- Update `device-ws-video-list-command` documentation and scenarios to filter and expose `uploadStatus` instead of `syncStatus` (same non-zero visibility semantics unless design specifies otherwise).

## Capabilities

### New Capabilities

- `device-ws-video-metadata`: Outbound WebSocket `video.metadata` message: when it is sent (after successful cover upload + row update), payload shape, snake_case naming, excluded fields, and ordering relative to cover PUT and optional follow-on video upload.

### Modified Capabilities

- `device-video-metadata`: Replace HTTP multipart metadata requirements with local row fields, `uploadStatus` semantics (`CoverUploaded` at `1`, existing meanings for in-flight / completed video file upload adjusted in delta), removal of metadata POST success criteria, and removal of WorkManager-only metadata sync requirements superseded by cover + WS.
- `device-r2-presigned-upload`: Adjust post-cover-PUT “metadata submission” language to **WS `video.metadata` + DB updates**; update Monitor list-upload preconditions from `syncStatus`/`metadata POST` to `uploadStatus` / cover-presigned path.
- `device-ws-video-uploading`: Rename enum references to `VideoUploadStatus`; update payload keys and integer semantics to match `uploadStatus` on the row (including final states for STS video upload).
- `device-ws-video-list-command`: Rename filter and list field documentation from `syncStatus` to `uploadStatus` (and wire key naming if applicable).

## Impact

- Room entity `ProcessParamsVideo` / DAO / migrations; any UI or adapters showing sync labels.
- `ProcessVideoMetadataWorker`, handlers that enqueue metadata upload, `DeviceWorkerPresignedVideoClient` / cover upload orchestration, Monitor list upload runner.
- WebSocket envelope builders for upload progress and the new `video.metadata` type.
- OpenSpec deltas and any unit tests tied to old message field names or HTTP metadata behavior.
