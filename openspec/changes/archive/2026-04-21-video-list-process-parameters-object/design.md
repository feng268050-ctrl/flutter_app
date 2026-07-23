## Context

Today the process-video row stores a Gson-serialized `ProcessParametersData` string in Room (`ProcessParamsVideo.processData` / column `processData`). `command.video_list_response` list items currently expose that string (after recent work) as **`processData`**. `command.stat_response` already exposes the same logical model as a nested object under **`processParameters`**. Servers want one field name and JSON type for both paths.

The same table still carries a legacy **`status`** integer (set to `0` on insert, `1` after some legacy “upload done” paths) while **`uploadStatus`** is the authoritative cover/video pipeline state. Nothing in the UI reads `status`; it appears only in writes and optional `video.metadata` serialization.

## Goals / Non-Goals

**Goals:**

- Persisted string field is conceptually **`processParametersJson`** (code + spec naming); wire list items expose **`processParameters`** as a **JSON object or JSON `null`**, never a raw string key `processData` on the list payload.
- Parse stored JSON **off the UI thread** in the same handler path that already queries Room for the list command.
- Invalid or non-object JSON (including empty / whitespace-only) maps to **`processParameters`: null** while the rest of the row still serializes.
- Remove **`status`** end-to-end: drop SQLite column in the same migration window as other `t_params_process_video` changes (or a coordinated migration), delete `updateStatus` / `setStatus` usage, and stop emitting `status` on **`video.metadata`**.

**Non-Goals:**

- Changing the shape of `command.stat_response` in this change (beyond shared naming alignment if a helper is reused).
- Redefining business semantics of individual laser/wire fields inside `ProcessParametersData`.

## Decisions

1. **SQLite column vs Java-only rename**  
   - **Preferred**: Add a Room **migration** renaming column `processData` → `processParametersJson` so DB, entity, and Gson persistence stay aligned.  
   - **Fallback**: If migration risk is too high short-term, use `@ColumnInfo(name = "processData")` on a Java field named `processParametersJson` (wire + Java rename only). Document chosen path in `tasks.md`.

2. **Parsed type on the wire**  
   Use **`com.google.gson.JsonElement`** (typically `JsonObject`) or `Map<String, Object>` via Gson’s `fromJson(..., Map.class)` — pick **`JsonElement`** embedded in the row `Map<String, Object>` so `GsonUtils.toJson` emits a JSON **object** without re-stringifying. `null` stays JSON null.

3. **Where to parse**  
   Parse in **`DeviceWsVideoListPayload`** (or a small dedicated helper called from the video-list handler thread) from the string loaded by DAO — **not** on the main thread; list command handler already uses a background executor.

4. **Vo / DAO field name**  
   Rename VO/entity field to `processParametersJson`; update all `@Query` projections and inserts/updates accordingly if the column is renamed.

5. **Tests**  
   Unit-test: valid JSON string → object under `processParameters`; malformed → `null`; key `processData` absent; optional test that serialized frame contains `"processParameters":{` or `:null`.

6. **Legacy `status` removal**  
   Delete `ProcessParamsVideo.status` and `ProcessProcessVideoDao.updateStatus`; remove `setStatus(0)` on insert and post-upload `updateStatus(..., 1)` in `CameraController`, `ProcessVideoViewModel`, and `DeviceWebSocketConnectionManager` (upload completion already reflected via `uploadStatus` / `videoUrl` in current flows). Strip `status` from `DeviceWsVideoMetadataPayload`. One Room migration SHALL `ALTER TABLE` / rebuild to drop `status` alongside `processData` → `processParametersJson` if both land together.

## Risks / Trade-offs

- **[BREAKING] Server clients** expecting `processData` string on list rows → document in proposal; migration note for API consumers.  
- **[BREAKING] Server clients** expecting `video.metadata.status` → remove; use `uploadStatus` only.  
- **Large JSON** in list responses → already accepted by product; same size as string, slightly more CPU for parse per row.  
- **Room migration failure on large installs** → Mitigation: ship migration in controlled release; instrument or log migration errors.

## Migration Plan

1. Ship app with migration + code paths reading/writing `processParametersJson`.  
2. Same migration (or chained migration) drops `status` after verifying no read paths remain.  
3. Rollback: re-release prior APK only if migration not yet applied; avoid downgrading across migration without backup.

## Open Questions

- Whether to rename the SQLite column in this same PR or stage Java-only `@ColumnInfo` first (team preference).
