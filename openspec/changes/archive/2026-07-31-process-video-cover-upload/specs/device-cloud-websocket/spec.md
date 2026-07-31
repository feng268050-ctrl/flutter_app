## MODIFIED Requirements

### Requirement: Process-video WebSocket upload uses cover-then-media coordinator

When `command.upload_video` requests cloud upload, the system SHALL acknowledge acceptance promptly, then run the shared process-video cloud upload coordinator: cover when still `uploadStatus == 0`, then media PutObject with `video.uploading` progress, finishing at `uploadStatus == 3`. Cover success MUST emit `video.metadata`. Device-local `POST /v1/videos` multipart ingest remains a separate LAN API that writes the process-video index only and does not by itself perform Worker/R2 upload.

#### Scenario: Upload command early ack

- **WHEN** `command.upload_video` names a known local `videoId` and upload can start
- **THEN** the device MUST ack acceptance/start before PutObject completes

#### Scenario: Cover then video

- **WHEN** the named row is still at `uploadStatus == 0`
- **THEN** cover upload MUST complete (or fail the run) before video PutObject begins
