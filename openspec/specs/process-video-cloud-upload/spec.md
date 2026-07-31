# process-video-cloud-upload Specification

## Purpose

Cover-then-media cloud upload for process videos (lws-ui parity): JPEG cover PutObject (`0→1`), full MP4 upload (`1→2→3`), R2 object keys, and a shared single-flight coordinator for Monitor Upload and WebSocket `command.upload_video`.

## Requirements

### Requirement: Cover upload promotes local rows for cloud and LAN visibility

When Worker API origin is pinned and a process-video row has `uploadStatus == 0`, the system SHALL extract a JPEG cover from the local MP4, PutObject it to R2 with content type `image/jpeg`, update the row to `uploadStatus == 1` with `coverUrl` set from STS `public_base_url` + object key, and emit WebSocket `video.metadata` for that row. Cover work MUST be soft-fail for App stability (record error; do not crash UI).

#### Scenario: Cover success after Record Work

- **WHEN** Record Work inserts a new row and Worker origin is pinned
- **THEN** the App MUST enqueue cover upload for that row (or drain pending covers)
- **AND** on success `uploadStatus` MUST become `1` with a non-empty `coverUrl`

#### Scenario: Cover skipped without pin

- **WHEN** Worker origin is not pinned
- **THEN** the App MUST NOT require network for the local insert
- **AND** MUST leave `uploadStatus` at `0` until pin + drain or an Upload action runs

### Requirement: Full video upload is cover-then-media

User or `command.upload_video` triggered cloud upload SHALL use a single-flight coordinator that:
1. Ensures cover is uploaded (`0→1`) when still pending
2. Sets `uploadStatus == 2` and emits `video.uploading` with `uploadProgress == 0`
3. PutObjects the MP4 while emitting throttled `video.uploading` progress (percent advances with bytes; at least every 5 percentage points or every 2 seconds, matching lws-ui)
4. Sets `uploadStatus == 3` with `videoUrl`, emits a forced final `video.uploading` at 100%, and MUST NOT require a second `video.metadata` after media PutObject (cover already emitted metadata)

Object keys SHALL use `uploads/devices/{sn}/videos/{yyyy-MM-dd}/{videoId}.{ext}` where the date comes from the row `createTime` in the device local timezone. Rows already at status `3` MUST be rejected as already uploaded.

#### Scenario: Upload from status 1

- **WHEN** Upload starts for a row with cover already uploaded
- **THEN** status MUST move `1→2→3` without re-requiring a successful cover PutObject unless cover URL is missing

#### Scenario: Upload from status 0

- **WHEN** Upload starts for a row still at status `0`
- **THEN** the coordinator MUST complete cover (`0→1`) before video PutObject

#### Scenario: Object key shape

- **WHEN** cover or video is PutObject'd
- **THEN** the object key MUST match `uploads/devices/{sn}/videos/{yyyy-MM-dd}/{videoId}.{jpg|mp4}`

#### Scenario: Remote progress during media PutObject

- **WHEN** `command.upload_video` (or Monitor Upload) is transferring the MP4
- **THEN** the device MUST emit `video.uploading` with camelCase `videoId`, `uploadStatus`, `uploadProgress`, and `videoUrl`
- **AND** mid-transfer progress MUST not be limited to only 0 and 100

### Requirement: Shared coordinator for UI and WebSocket

Monitor Upload taps and inbound `command.upload_video` SHALL share one single-flight upload coordinator so concurrent requests cancel/replace safely and show the same progress semantics. `command.upload_video` MUST still acknowledge acceptance promptly when upload starts (not only when finished).

#### Scenario: WS reuses coordinator

- **WHEN** `command.upload_video` arrives for a known `videoId`
- **THEN** the response ack MUST indicate acceptance/start
- **AND** the same cover-then-video pipeline MUST run as Monitor Upload
