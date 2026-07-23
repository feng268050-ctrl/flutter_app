## Purpose

Define outbound WebSocket reporting for **Monitor process video** upload progress: message type `video.uploading`, payload shape, throttling, and prohibition of secrets in the payload.
## Requirements
### Requirement: video.uploading message type and payload

When reporting process video upload progress to the server over the device WebSocket, the client SHALL send outbound frames whose envelope `type` string is exactly `video.uploading`. The envelope `payload` SHALL be a JSON object (serialized in the same manner as other device-originated commands) containing at minimum these keys, using **camelCase** names matching the `ProcessParamsVideo` bean: `videoId` (string UUID matching `t_params_process_video.videoId`), `uploadStatus` (integer matching `VideoUploadStatus` for the row at send time), `uploadProgress` (integer 0–100 inclusive), and `videoUrl` (string; MAY be empty when no public URL is known yet).

#### Scenario: Payload keys are present on each sending

- **WHEN** the client emits `video.uploading` for a given row during an upload attempt
- **THEN** the JSON payload MUST include the keys `videoId`, `uploadStatus`, `uploadProgress`, and `videoUrl` with types as specified, even if `videoUrl` is an empty string

### Requirement: Emit during upload with throttling

The client SHALL send `video.uploading` at least once when the upload enters `VideoUploading` (numeric upload status `2`) and at least once when the upload terminates successfully (`uploadStatus` `3`, `uploadProgress` `100`) or fails (final `uploadStatus` reflects the non-success terminal state defined together with `device-video-metadata`). Between start and completion, the client SHALL throttle additional sends so that under steady progress the emit rate does not exceed one message approximately every 2 seconds unless `uploadProgress` increased by at least 5 percentage points since the last emit.

#### Scenario: Final state is always reported

- **WHEN** a process video file upload completes or fails after having entered `VideoUploading`
- **THEN** the client MUST send a final `video.uploading` reflecting the terminal `uploadStatus`, final `uploadProgress` value appropriate to that outcome, and best-known `videoUrl` (empty if unknown)

### Requirement: No secrets in WebSocket payload

The `video.uploading` payload MUST NOT contain STS credentials, presigned query parameters, or raw session tokens.

#### Scenario: STS fields absent from payload

- **WHEN** any `video.uploading` message is constructed
- **THEN** the payload MUST NOT include `access_key_id`, `secret_access_key`, `session_token`, or full presigned URLs with signing query parameters

