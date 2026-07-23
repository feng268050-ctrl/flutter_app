## Why

The process video table still uses a legacy column name `materials` while the Worker multipart contract already speaks in terms of `material_type`, which is confusing and brittle. After a successful metadata upload, the server can return the canonical hosted cover URL in `ApiResult.data`, but the app never persists it, so the local row diverges from cloud truth. A nullable `videoUrl` column is needed as a forward-looking hook for a later video-file upload phase.

## What Changes

- **BREAKING (schema / Room)**: On `t_params_process_video` / entity `ProcessParamsVideo`, rename persisted column **`materials` → `materialType`** (same integer semantics as today; aligns naming with multipart `material_type` and `MaterialTypeEnum`).
- Add nullable **`coverUrl`** (TEXT) and nullable **`videoUrl`** (TEXT, reserved; no upload flow in this change).
- On successful Worker metadata `POST` (`ApiResult.success === true`), update the row’s **`syncStatus`** to metadata-uploaded **and** persist **`coverUrl`** from response `data.cover_url` when present (JSON snake_case), so local state matches the server for cover location.
- **BREAKING (Java API)**: All getters/setters and DAO projections that referenced `materials` on the **process video** entity/VO move to `materialType`; call sites (`CameraController`, list/detail UI, metadata client) follow the rename.

## Capabilities

### New Capabilities

_(none — behavior extends existing device video metadata capability.)_

### Modified Capabilities

- `device-video-metadata`: Extend the persisted row model (rename column, new URL fields), clarify multipart `material_type` source column, and require persisting `cover_url` from successful `ApiResult.data` alongside `syncStatus` after metadata sync.

## Impact

- **Room**: `ProcessParamsVideo`, `ProcessParamsVideoVo`, `ProcessProcessVideoDao` queries, new **`Migration_36_37`** (or next version bump), `AppDatabase` version and migration registration, exported schema JSON if the project checks it in.
- **Networking / parsing**: `DeviceWorkerVideoMetadataClient` / `ProcessVideoMetadataWorker` — parse `data` object for `cover_url` (e.g. small DTO + Gson or `JsonObject`) and pass into a single DB update with `syncStatus`.
- **UI / VM**: `ProcessVideoViewHolder`, `ProcessVideoDetailsViewModel`, tests/docs that mention `materials` on the video row.
- **Specs / docs**: `openspec/specs/device-video-metadata/spec.md` and any developer notes that refer to the `materials` column on `t_params_process_video`.
