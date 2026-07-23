## Context

The Android app already exposes a **unified WebSocket envelope** and dispatches inbound `command.*` frames in `DeviceWebSocketConnectionManager` (for example `command.stat_request` → background work → `command.stat_response` with `payload.request_id` and `payload.data`). Process videos are stored in Room as `ProcessParamsVideo` / `t_params_process_video`; `ProcessProcessVideoDao` already exposes a paged read (`selectPage`) ordered by `createTime` descending, but it does **not** filter by `syncStatus`. Metadata sync semantics and `syncStatus` values are defined in `device-video-metadata` (`0` = not uploaded, non-zero = progressed).

## Goals / Non-Goals

**Goals:**

- Handle `command.video_list_request` on the device WebSocket using the same structural pattern as `command.stat_request` / `command.stat_response` (inbound correlation id = top-level `id`; outbound response uses a **new** top-level `id`).
- Page rows from `t_params_process_video` with **`syncStatus != 0`** only, returning **`total`** for that filter and **`list`** for the requested window.
- Keep DB access off the main thread (consistent with `handleInboundStatRequest`).

**Non-Goals:**

- Changing MQTT or other transports for the same data.
- Defining server-side pagination contracts beyond this device command pair.
- Returning full `processData` blobs in the list if they are large; the spec may constrain list item fields to a safe, explicit set (implementation maps from `ProcessParamsVideo` / `ProcessParamsVideoVo`).

## Decisions

1. **Dispatch location** — Extend `DeviceWebSocketConnectionManager.onInboundMessage` with a branch for `command.video_list_request`, mirroring `command.stat_request`: validate envelope/`id`, require `ONLINE`, run work on `ThreadPoolManager.getExecutor()`, send response from the worker path (reuse `sendRawJson` / `DeviceWebSocketEnvelope.toJson`).

2. **Response type name** — Use outbound `type` **`command.video_list_response`** (user-provided), not `*_ack`, but follow the same correlation pattern as `command.stat_response`: `payload.request_id` = inbound top-level `id`; `payload.data` = `{ "list", "total" }`.

3. **Query layer** — Add Room DAO methods (or a single query returning count + page if preferred, but two queries `COUNT` + paged `SELECT` is acceptable) scoped with `WHERE syncStatus != 0` and **`ORDER BY createTime DESC`** to match existing UI list ordering. Reuse the column projection already used by `selectPage` where possible (VO-shaped rows without `processData` in the VO today).

4. **Request payload parsing** — Read `page` and `page_size` from `payload` as numbers; normalize to integers with **minimum 1** for `page`, **minimum 1 and a hard cap** for `page_size` (e.g. 100) to avoid accidental huge reads. On missing or invalid values, use safe defaults rather than failing the command silently (still respond with `list`/`total`).

5. **List JSON shape** — Serialize each row as a JSON object with stable **snake_case** keys for cross-language consumers (e.g. `video_id`, `create_time`, `sync_status`, `cover_url`, `video_url`, `file_size`, `duration`, `resolution`, `process_type`, `material_type`, `upload_progress`). Do **not** expose local-only fields such as the Room row `id` or `video_path` on the wire.

6. **Failure behavior** — If the app context or DB is unavailable, **log** and skip sending or send an empty `list` with `total` 0 per implementation policy; the spec should require a response on the happy path and allow logging-only failure when the socket is not sendable.

## Risks / Trade-offs

- **[Risk] Large JSON responses** — Mitigation: cap `page_size`; omit heavy fields such as inline `process_data` unless explicitly required later.
- **[Risk] `syncStatus != 0` includes reserved future states** — Mitigation: matches user requirement; document that any non-zero row is included.
- **[Trade-off] Two round-trips to SQLite (count + page)** — Acceptable for clarity and small N; can optimize with a single statement later if profiling warrants.

## Migration Plan

No database migration: read-only new queries on existing `t_params_process_video`. Deploy with app release; server must send the new `command` types only when the device version supports them (operational coordination outside this repo).

## Open Questions

- Whether `data.list` items must include **`processData`** for remote consumers (default in design: **omit** unless product requires it—confirm with server team before implementation).
