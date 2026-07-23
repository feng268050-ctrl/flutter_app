## ADDED Requirements

### Requirement: video.uploading message type and payload

When reporting process video upload progress to the server over the device WebSocket, the client SHALL send outbound frames whose envelope `type` string is exactly `video.uploading`. The envelope `payload` SHALL be a JSON object (serialized in the same manner as other device-originated commands) containing at minimum these keys, using **snake_case** names: `video_id` (string UUID matching `t_params_process_video.videoId`), `sync_status` (integer matching `VideoSyncStatus` for the row at send time), `upload_progress` (integer 0–100 inclusive), and `video_url` (string; MAY be empty when no public URL is known yet).

#### Scenario: Payload keys are present on each sending

- **WHEN** the client emits `video.uploading` for a given row during an upload attempt
- **THEN** the JSON payload MUST include the keys `video_id`, `sync_status`, `upload_progress`, and `video_url` with types as specified, even if `video_url` is an empty string

### Requirement: Emit during upload with throttling

The client SHALL send `video.uploading` at least once when the upload enters `VideoUploading` (`sync_status` `2`) and at least once when the upload terminates successfully (`sync_status` `3`, `upload_progress` `100`) or fails (final `sync_status` reflects the non-success terminal state defined together with `device-video-metadata`). Between start and completion, the client SHALL throttle additional sends so that under steady progress the emit rate does not exceed one message approximately every 2 seconds unless `upload_progress` increased by at least 5 percentage points since the last emit.

#### Scenario: Final state is always reported

- **WHEN** a process video file upload completes or fails after having entered `VideoUploading`
- **THEN** the client MUST send a final `video.uploading` reflecting the terminal `sync_status`, final `upload_progress` value appropriate to that outcome, and best-known `video_url` (empty if unknown)

### Requirement: No secrets in WebSocket payload

The `video.uploading` payload MUST NOT contain STS credentials, presigned query parameters, or raw session tokens.

#### Scenario: STS fields absent from payload

- **WHEN** any `video.uploading` message is constructed
- **THEN** the payload MUST NOT include `access_key_id`, `secret_access_key`, `session_token`, or full presigned URLs with signing query parameters
