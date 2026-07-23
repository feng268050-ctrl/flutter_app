## Context

Today `device-video-metadata` specifies a Worker multipart `POST /v1/devices/:sn/videos/metadata`, `syncStatus` / `VideoSyncStatus` with `1 = MetadataUploaded`, WorkManager drains for pending metadata, and list upload ordering that treats HTTP metadata success as the gate before STS video bytes. `device-ws-video-list-command` already exposes live rows to the server, and the exploration-stage server no longer needs a second metadata ingestion path for the same facts.

## Goals / Non-Goals

**Goals:**

- Single column `uploadStatus` on `t_params_process_video` with enum `VideoUploadStatus`: `0` NotInitiated, `1` CoverUploaded, `2` VideoUploading, `3` VideoUploaded.
- Upload JPEG cover via existing presigned-PUT flow (`device-r2-presigned-upload`), persist `coverUrl` from the successful presign/PUT `public_url`, set `uploadStatus = 1`, then emit `video.metadata` over the device WebSocket with **snake_case** keys and **no** `id` or `video_path`.
- Remove Worker multipart metadata upload and the WorkManager backlog dedicated to that HTTP path; keep STS video upload behavior and `video.uploading` progress reporting, aligned to `uploadStatus`.
- Align WS list filtering and list payloads with `uploadStatus` naming.

**Non-Goals:**

- Server-side implementation details beyond what the app contract must send.
- Changing the object key layout for R2 presigned cover or STS video keys.
- Broader refactors of recording UX unrelated to upload/sync.

## Decisions

1. **Column rename `syncStatus` → `uploadStatus` at the SQLite layer**  
   **Rationale**: Matches semantics (upload pipeline, not generic “sync”) and avoids carrying two names across DAO/WS. **Alternative**: Keep DB column for less migration churn — rejected because the user explicitly requested the rename.

2. **Drop `POST .../videos/metadata` entirely for this flow**  
   **Rationale**: Duplicate of `command.video_list_request/response` inventory. **Alternative**: Keep HTTP as optional fallback — rejected (explicit non-goal / user direction).

3. **`CoverUploaded` (`1`) is set only after presigned cover PUT success and `coverUrl` persistence**  
   **Rationale**: Gives the server a stable public cover URL before optional metadata push. **Alternative**: Set `1` before PUT — rejected (misleading state on PUT failure).

4. **`video.metadata` payload = full row “catalog” fields minus `id` and `video_path`, snake_case**  
   **Rationale**: Matches user wording; `video_id` remains the business key. Fields such as `create_time`, `duration`, `file_size`, `resolution`, `process_type`, `material_type`, `process_data`, `cover_url`, `upload_status`, `upload_progress`, `video_url`, and any other small scalar fields persisted on the entity SHOULD be included when non-null rules allow; local PK and filesystem path are excluded.

5. **`video.uploading` uses `upload_status` (integer) instead of `sync_status`**  
   **Rationale**: Consistent naming with DB and enum rename. **Alternative**: keep `sync_status` key for compatibility — rejected (user waived compatibility).

6. **Retry / backlog for cover + WS**  
   **Rationale**: HTTP metadata WorkManager worker is removed; cover+WS retry SHOULD reuse the same hooks as today’s “pending upload” paths (e.g. user-initiated list upload, or a slimmed background pass if one already exists). Exact worker split is implementation detail captured in tasks; spec states absence of metadata POST drain.

## Risks / Trade-offs

- **[Risk] Rows stuck at `uploadStatus = 0` if cover pipeline never runs** → **Mitigation**: Preserve user-driven Monitor list upload as the primary retry; document any optional periodic pass in tasks.
- **[Risk] Server expects old `sync_status` key on `video.uploading`** → **Mitigation**: Accepted breaking change per stakeholder note.
- **[Trade-off] No HTTP metadata means no server-side validation from that endpoint** → **Mitigation**: Server validates via list + WS payloads under new contract.

## Migration Plan

1. Ship Room migration renaming column `syncStatus` → `uploadStatus` (or equivalent SQL) with app code updated in the same release (no cross-version server dependency).
2. Remove metadata HTTP client usage and obsolete worker enqueue sites.
3. Deploy app + server WS handlers for `video.metadata` and updated `video.uploading` keys together (dev/staging first).

## Open Questions

- Whether `video.metadata` should be idempotent deduped on the server (out of scope for device spec beyond “send after successful cover upload”).
- Exact set of nullable fields omitted vs sent as `null` in JSON (implementation choice; spec requires snake_case and exclusions only).
