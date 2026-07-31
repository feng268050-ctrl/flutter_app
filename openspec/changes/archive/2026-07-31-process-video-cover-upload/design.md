## Context

- Local save: `ProcessVideoSaveHandler` → SQLite `upload_status=0`.
- Cloud MP4 path exists in `CloudLocalRuntime._handleUploadVideo` but skips cover, uses non-product object keys, and emits `video.metadata` only after full video.
- lws-ui: cover first (gated on pinned API), then list/WS video upload; list UI has Upload + progress, no cover thumbnails.

## Goals / Non-Goals

**Goals:**
- Parity status machine 0→1→2→3 with cover URL and correct R2 keys.
- Phone LAN list sees rows after cover (status ≥ 1).
- Monitor Upload UX + shared coordinator with WS command.

**Non-Goals:**
- Cover thumbnails in list/detail.
- Changing LAN/WS default visibility filter (`uploadStatus != 0`).
- HTTP multipart Worker metadata POST for Monitor (legacy Dev-only on Android).

## Decisions

1. **ffmpeg for JPEG cover** — `ffmpeg -ss 0 -i … -frames:v 1 -q:v 2` (soft-fail if missing); cache under `/var/lib/hmi/video-covers/`.
2. **Shared `ProcessVideoCloudUploadCoordinator`** — single-flight; UI and `command.upload_video` call the same runner.
3. **Object keys** — `uploads/devices/{sn}/videos/{yyyy-MM-dd}/{videoId}.{jpg|mp4}` from createTime (local TZ).
4. **STS `public_base_url`** — parse from STS response; join for `coverUrl` / `videoUrl`; fail cover if missing.
5. **`video.metadata` after cover** — match lws-ui (catalog after 0→1); full video path still emits `video.uploading` and may refresh metadata/url fields.
6. **Enqueue cover only when pinned** — after save and when origin pin succeeds; no cover without Worker.

## Risks / Trade-offs

- [ffmpeg absent] → cover fails, status stays 0 (or reset to 0 if a failed upload incorrectly left status 1 without coverUrl); surface soft error in Upload dialog. Ship aarch64 static ffmpeg as `/opt/hmi/bin/ffmpeg` via `hmi_bundle_install_ffmpeg`.
- [No public_base_url] → cover fails like Android.
- [Concurrent sqlite openers] → keep update via repository API; short transactions.

## Migration Plan

Ship App (`make build-app` / `push-app`). Existing status-0 rows drain when pin is present. No DB schema migration.

## Open Questions

- None blocking.
