## MODIFIED Requirements

### Requirement: Cover upload promotes local rows for cloud and LAN visibility

When Worker API origin is pinned and a process-video row has `uploadStatus == 0`, the system SHALL extract a JPEG cover from the local MP4 via the product **GStreamer frame-extract** path (not App-bundled ffmpeg), PutObject it to R2 with content type `image/jpeg`, update the row to `uploadStatus == 1` with `coverUrl` set from STS `public_base_url` + object key, and emit WebSocket `video.metadata` for that row. Cover work MUST be soft-fail for App stability (record error; do not crash UI).

#### Scenario: Cover success after Record Work

- **WHEN** Record Work inserts a new row and Worker origin is pinned
- **THEN** the App MUST enqueue cover upload for that row (or drain pending covers)
- **AND** on success `uploadStatus` MUST become `1` with a non-empty `coverUrl`

#### Scenario: Cover skipped without pin

- **WHEN** Worker origin is not pinned
- **THEN** the App MUST NOT require network for the local insert
- **AND** MUST leave `uploadStatus` at `0` until pin + drain or an Upload action runs

#### Scenario: Cover extract uses GStreamer

- **WHEN** cover JPEG is produced for upload
- **THEN** extract MUST use rootfs GStreamer frame-extract and MUST NOT require `/opt/hmi/bin/ffmpeg`
