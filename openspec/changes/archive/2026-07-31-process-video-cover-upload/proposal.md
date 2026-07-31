## Why

Record Work already indexes local MP4s, and WebSocket `command.upload_video` can PutObject an MP4, but Linux never runs the lws-ui cover phase (`uploadStatus` 0→1 + `coverUrl` + `video.metadata`). LAN `GET /v1/videos` hides `uploadStatus == 0`, so the phone app sees an empty device library. Monitor Videos also lacks the Upload control and progress UX.

## What Changes

- Auto **cover extract + R2 PutObject** after Record Work save when Worker API origin is pinned (`0→1`, set `coverUrl`, emit WS `video.metadata`).
- Align full **video upload** orchestration with lws-ui: ensure cover first, then `1→2→3`, object keys `uploads/devices/{sn}/videos/{yyyy-MM-dd}/{videoId}.{ext}`, progress via `video.uploading`.
- Add Monitor → Videos **Upload** action + progress dialog (same coordinator for UI tap and `command.upload_video`).
- Drain pending covers when API origin becomes pinned.
- **Out of scope:** list/detail cover thumbnails (lws-ui has none), changing LAN default `uploadStatus != 0` filter, Android APK path.

## Capabilities

### New Capabilities

- `process-video-cloud-upload`: Cover 0→1, video 1→2→3, R2 keys, STS/`public_base_url`, WS events, single-flight coordinator.

### Modified Capabilities

- `process-video`: After successful local insert, when cloud origin is pinned, SHALL enqueue cover upload (network soft-fail allowed).
- `product-monitor-ui`: Videos tab SHALL offer Upload (disabled when already uploaded / upload in flight) with progress UX.
- `device-cloud-websocket`: `command.upload_video` SHALL reuse the same cover-then-video coordinator (early ack retained).
- `device-cloud-http`: Clarify cover PutObject + `public_base_url` join for read URLs and catalog object-key shape.

## Impact

- App: `features/process_video/` (cover extract, uploader, coordinator), `platform/cloud/` (STS public base, keys, runtime wiring), Monitor `videos_tab.dart`, l10n strings.
- Depends on existing R2 STS / PutObject clients and pinned Worker origin.
- Board needs `ffmpeg` (or equivalent) for JPEG frame extract from MP4.
