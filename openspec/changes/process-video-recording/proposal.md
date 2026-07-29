## Why

Quick/Engineer **Record Work** already arms with the laser session and writes MP4s under `/userdata/storage/Videos/movie/…`, but it never persists process metadata, so Monitor → Videos stays an empty stub. Operators cannot browse, play, inspect parameters, or delete local work recordings the way lws-ui `fragment_process_video` / `ProcessVideoDetailsActivity` do. This change closes that local gap (upload/cloud deferred).

## What Changes

- Persist a **process-video record** when Record Work encode completes: MP4 path, duration/size/resolution, work mode, material, and a **frozen process-parameter JSON snapshot** (not a live preset foreign key).
- Replace Monitor → Videos stub with a **real list** aligned to lws-ui columns (Recording Time, Work Mode, Material, Duration, Operations): pagination/refresh, row → detail, **Delete** (file + DB). **Upload** UI/actions stay absent or non-functional deferred.
- Add a **video detail** screen: local file playback + parameter panel + Delete; no upload.
- Harden Record Work save path: min-duration discard, soft-fail on corrupt/short files, optional 10-minute segment roll (lws-ui parity) if feasible with current HAL recorder.
- Keep Settings demo Record/Stop and `cyber_hal` recording API product-neutral (no video-DB fields in HAL).
- **Out of scope:** cloud/R2 upload, cover URL sync, WebSocket `upload_video`, AI Vision choose/inference, status-bar recording icon (unless already trivial).

## Capabilities

### New Capabilities

- `process-video`: Domain model, SQLite index, Record Work save-on-stop (snapshot + file metadata), local delete/playback helpers, path/duration policy aligned with lws-ui `t_params_process_video` (upload fields reserved/default only).

### Modified Capabilities

- `product-monitor-ui`: Monitor → Videos tab becomes a live list + detail navigation with local operations (no upload).

## Impact

- **App:** `RecordWorkController` / Quick + Engineer pages; new process-video feature (models, sqlite repo, save handler); `VideosTab` + new detail route/page; l10n for list/detail/Record Work labels.
- **Storage:** SQLite under `/var/lib/hmi/` (→ `/userdata/hmi/`); MP4s remain under `/userdata/storage/Videos/movie/…`.
- **HAL / rootfs:** No required HAL API change; reuse existing GStreamer remux + `video_player` for local file playback. Thumbnail/probe may use existing GStreamer/ffprobe tooling if present—soft-fail if not.
- **Explicit non-goals:** upload pipeline, AI Vision tab wiring, Settings demo → business DB coupling.
