## Context

HAL RTSP→MP4 recording and Quick/Engineer **Record Work** (arm checkbox + laser-enable sync) already ship. Settings demo Record/Stop remains isolated. Monitor → Videos is a header + empty stub. lws-ui persists each completed recording into Room `t_params_process_video` with a process-parameter JSON snapshot, then lists/plays/deletes via `ProcessVideoFragment` / `ProcessVideoDetailsActivity`. Upload/cover/AI are separate on Android and stay out of this change.

Constraints:

- Flutter App API **3.24.4**; reuse `video_player` / eLinux GStreamer plugin for **file** URIs where possible.
- `cyber_hal` recording API stays product-neutral (no video-DB / process fields) — per `dart-hal` / `ip-camera` specs.
- SQLite patterns already exist (`alarm-logs.db`, `process-library.db`) under `/var/lib/hmi` → `/userdata/hmi`.
- MP4 path layout already matches lws-ui via `IpCameraDemoRecordingPaths`.

## Goals / Non-Goals

**Goals:**

- On Record Work stop (successful encode), insert a durable process-video row with file metadata + frozen process snapshot.
- Monitor Videos list + detail with local playback, parameter panel, delete (file + row).
- Align UX/columns/ops with lws-ui local surface; hide/omit Upload.
- Soft-fail DB/file errors so mode pages remain usable.

**Non-Goals:**

- Cloud/R2 upload, STS, cover URL workers, WebSocket upload commands.
- AI Vision choose / inference artifacts.
- Coupling Settings demo Record into the business video DB.
- Status-bar global recording indicator (later slice).
- Changing HAL recording API shape.

## Decisions

### 1. App-owned process-video module (not HAL)

**Choice:** New App feature under `app/lws_hmi/lib/features/process_video/` (domain + sqlite repo + save handler + Monitor UI). Record Work calls the save handler after `recorder.stop()` completes.

**Why:** Matches existing split (HAL remux vs product session/DB). Avoids polluting `cyber_hal`.

**Alternatives:** Extend `IpCameraRecordingResult` with business fields — rejected (dart-hal forbids). Separate systemd helper — overkill for App-local sqlite.

### 2. Schema aligned with lws-ui, Linux table naming

**Choice:** SQLite DB `/var/lib/hmi/process-videos.db`, table `process_videos` with fields mirroring `ProcessParamsVideo`:

| Field | Notes |
|-------|--------|
| `id` | INTEGER PK |
| `video_id` | TEXT UUID |
| `video_path` | TEXT absolute MP4 |
| `process_type` | INTEGER |
| `material_type` | INTEGER nullable |
| `process_parameters_json` | TEXT snapshot |
| `file_size` | INTEGER bytes |
| `duration_ms` | INTEGER |
| `resolution` | TEXT nullable |
| `create_time_ms` | INTEGER |
| `upload_status` | INTEGER default `0` (NOT_INITIATED) |
| `upload_progress` | INTEGER default `0` |
| `cover_url` / `video_url` | TEXT nullable, unused until upload slice |

**Why:** Forward-compatible with Phase F upload without schema churn; list queries ignore upload columns.

**Alternatives:** Omit upload columns until needed — accepted risk of ALTER later; prefer reserve defaults now like alarm/process libs.

### 3. Snapshot capture at record **start**, resolve at **save**

**Choice:** When encode starts, clone current Quick/Engineer process context into a `ProcessVideoSnapshot` (process type, material, parameter map / JSON, optional preset uuid + library version). On stop, use that snapshot; if page still attached, prefer live params when `processType` matches (lws-ui `resolveSaveProcessParameters` parity). Persist JSON as opaque string — **do not** FK to process-library presets.

**Why:** Docs §8.3 / lws-ui: history must not mutate when presets are edited/deleted.

**Alternatives:** Only live params at stop — loses accuracy if operator changes mode mid-record. Only preset UUID — breaks historical meaning.

### 4. Inject snapshot provider into `RecordWorkController`

**Choice:** `RecordWorkController` takes an optional `ProcessVideoSnapshotSource` (callback/interface) owned by Quick/Engineer pages (they already hold process UI state). On successful stop, call `ProcessVideoSaveHandler.save(path, snapshot)`.

**Why:** Controller already owns encode lifecycle; pages own process params. Keeps CNC/no-camera paths null-safe.

### 5. Min duration + soft-fail; segment roll best-effort

**Choice:** Discard and do not insert if duration &lt; ~1000 ms or file unreadable (lws-ui `MIN_SAVED_DURATION_MS`). Toast/snackbar soft message. **10-minute auto-segment:** if HAL recorder can stop/restart cleanly while still armed+laser, implement roll; else document as follow-up and keep single continuous file for v1.

**Why:** Avoid empty/corrupt rows. Continuous remux may already span long sessions; segment parity is nice-to-have.

### 6. Monitor UI: list + pushed detail route

**Choice:** Populate `VideosTab` from repository (newest-first, page size 10, refresh on appear). Row tap → detail route/page with `video_player` on `file://` path + parameter panel (mode-gated fields like lws-ui). Operations: **Delete** only (confirm dialog). No Upload button (or disabled placeholder omitted to avoid dead UI).

**Why:** Matches stub columns already in tree; detail as separate page matches Android Activity, fits existing Navigator patterns.

### 7. Thumbnails optional / on-demand

**Choice:** v1 list does **not** require cover images (lws-ui list also has no local cover column). Detail may show first frame via player. Optional later: cache under `/var/lib/hmi/video-covers/`.

**Why:** Avoid new rootfs tooling dependency for MVP.

### 8. Settings demo stays isolated

**Choice:** Demo Record continues writing MP4s without inserting `process_videos` rows.

**Why:** Existing OpenSpec settings-ui isolation; prevents polluting Monitor with unlabeled demo clips.

### 9. Orphan MP4 scan — deferred

**Choice:** Do not auto-index pre-existing Record Work files without metadata in v1. Optional one-shot “import orphans” is out of scope unless trivial.

**Why:** Ambiguous process snapshot for old files; operators can delete via filesystem if needed.

## Risks / Trade-offs

- **[Risk] Local file playback on eLinux plugin** may be RTSP-tuned → Mitigation: verify `file://` / absolute path with existing plugin; if blocked, evaluate GStreamer playbin widget or short ffplay overlay only as last resort.
- **[Risk] Snapshot source incomplete on Engineer tab switch** → Mitigation: snapshot at encode start; keep start-snapshot as save fallback.
- **[Risk] Disk fill from continuous Record Work** → Mitigation: existing userdata budget; delete from Monitor; upload size gate stays deferred.
- **[Risk] Dual writers (demo + business) same folder** → Mitigation: demo not in DB; list only DB-backed rows (same as lws-ui).
- **[Trade-off] No upload UI** vs lws-ui list having Upload → Prefer omit button over disabled stub to avoid operator confusion.

## Migration Plan

1. Ship App with new DB (create-if-missing). No rootfs schema migration.
2. Existing MP4s without rows remain unlisted until manually deleted or a future import.
3. Rollback: revert App; leftover DB/MP4s harmless.
4. Device validation: Record Work under Quick → laser on/off → row appears → play → delete.

## Open Questions

1. Exact JSON shape for snapshot: reuse a lws-ui-compatible `ProcessParametersData`-like map vs App `ProcessParameters` key map + envelope (`processType`, `materialType`, `presetUuid`, `libraryVersion`)? Prefer envelope wrapping App parameter keys for Linux consistency, with display mapping in detail UI.
2. Implement 10-minute segment roll in this change or explicitly defer after HAL stop/start timing is measured on ynh960?
3. Should Record Work toasts/l10n land in the same change (yes — include in tasks)?
