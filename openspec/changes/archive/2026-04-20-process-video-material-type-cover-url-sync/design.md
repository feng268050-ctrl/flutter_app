## Context

`ProcessParamsVideo` / `t_params_process_video` today stores material choice as `materials` while `DeviceWorkerVideoMetadataClient` already sends multipart `material_type`. Worker metadata responses use `ApiResult` with a `data` object that can include `cover_url` for the stored JPEG cover. `ProcessVideoMetadataWorker` currently calls `updateSyncStatus` only, so local rows never store the server cover URL. `AppDatabase` is at version **36** with migrations through `Migration_35_36`.

## Goals / Non-Goals

**Goals:**

- Align the Room column name with domain language: **`materialType`** on the process video row.
- Add **`coverUrl`** and **`videoUrl`** (both nullable TEXT); **`videoUrl`** stays unused except schema readiness.
- After a **successful** metadata POST, persist **`syncStatus = MetadataUploaded`** and **`coverUrl`** from `data.cover_url` when provided, in the same transaction or sequential updates that keep the row consistent.
- Parse JSON robustly when `data` is a generic object (current `ApiResult.data` is `Object`).

**Non-Goals:**

- Implementing R2/OSS video file upload or writing **`videoUrl`** from network responses.
- Changing **`ProcessParametersData`** or other tables that still use `materials` (only the **process video** row is in scope).
- Altering Worker API contracts beyond consuming optional `cover_url`.

## Decisions

1. **SQLite migration for rename + new columns**  
   Use a single **`Migration_36_37`**: add `materialType` and copy `UPDATE ... SET materialType = materials WHERE ...`; add nullable `coverUrl` and `videoUrl`; then drop legacy `materials` if the project’s SQLite build supports `DROP COLUMN`, otherwise use the project’s established pattern (table rebuild) from prior migrations. Rationale: keeps one upgrade path; avoids silent data loss.

2. **Room entity field names match column names**  
   `materialType`, `coverUrl`, `videoUrl` as Java fields with default Room column mapping (camelCase). Rationale: matches user request and existing style (`videoId`, `syncStatus`).

3. **Where to parse `cover_url`**  
   Prefer parsing in **`DeviceWorkerVideoMetadataClient`** (or a tiny helper next to it) so `ProcessVideoMetadataWorker` receives either a structured result (e.g. extend `Outcome` with optional `coverUrl`) or reuses `ApiResult` with a typed parse of `data`. Rationale: keeps HTTP + JSON concerns in the network layer; worker stays orchestration + DB.

4. **DAO update strategy**  
   Replace or supplement `updateSyncStatus` with a single **`UPDATE`** that sets `syncStatus`, and `coverUrl = :coverUrl` when non-null (or always set nullable column including null to clear). Rationale: one write reduces races; matches “update local coverUrl and syncStatus together.”

5. **`videoUrl` at insert**  
   Explicitly set null in **`CameraController`** (or rely on default null). Rationale: satisfies spec scenario without implicit behavior.

## Risks / Trade-offs

- **[Risk] SQLite `DROP COLUMN` availability** → Mitigation: follow min SDK / bundled SQLite version; use rebuild migration if needed (pattern already in repo).
- **[Risk] Gson `data` as `LinkedTreeMap`** → Mitigation: parse with `JsonObject` / map accessor keyed by `cover_url`, not cast to a missing DTO field on `ApiResult`.
- **[Risk] Partial DB update** → Mitigation: single SQL `UPDATE` or `@Transaction` method on DAO.

## Migration Plan

1. Ship app with bumped DB version + migration; existing installs retain material integers and gain null URL columns.
2. Rollback: reinstall / backup restore only (no downgrade path documented; matches typical Android Room practice).

## Open Questions

- Whether Worker ever returns **`video_url`** in the same `data` object for future use — out of scope; **`videoUrl`** column is reserved locally only.
