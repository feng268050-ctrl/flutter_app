# device-ws-video-metadata Specification

## Purpose
TBD - created by archiving change refactor-process-video-upload-cover-ws. Update Purpose after archive.
## Requirements
### Requirement: video.metadata WebSocket message after cover upload

After a successful presigned-PUT upload of the process-video JPEG cover for a row (per `device-r2-presigned-upload`), once the device has persisted `coverUrl` and set `uploadStatus` to `1` (`CoverUploaded`) on `t_params_process_video`, the system SHALL send an outbound device WebSocket envelope whose `type` string is exactly `video.metadata`. The envelope `payload` SHALL be a JSON object whose property names SHALL use the same **camelCase** identifiers as the `ProcessParamsVideo` Room entity / Java bean (for example `videoId`, `processParametersJson`, `processType`, `materialType`, `fileSize`, `duration`, `createTime`, `resolution`, `uploadStatus`, `uploadProgress`, `coverUrl`, `videoUrl`). The payload SHALL include every persisted catalog-style field from the row that is needed for server-side display or correlation **except** the local database primary key (`id`) and the local filesystem path (`videoPath`); in particular it SHALL include `videoId` (UUID string matching the entity’s `videoId`). The payload MUST NOT include `id` or `videoPath`. The payload MUST NOT include a legacy **`status`** field. The system SHALL send this message at most once per successful cover upload completion boundary for that attempt (no duplicate sends solely due to progress throttling).

#### Scenario: Payload uses camelCase aligned with Room entity and excludes local-only fields

- **WHEN** the client finishes a successful cover presigned PUT and updates the row with `coverUrl` and `uploadStatus` equal to `1`
- **THEN** it MUST emit `video.metadata` whose JSON keys match the Java bean property names (camelCase), includes `videoId`, does not include `id` or `videoPath`, and does not include `status`

#### Scenario: Ordering relative to STS video upload

- **WHEN** the user runs **Monitor → Videos** list upload starting from `uploadStatus` equal to `0`
- **THEN** the system MUST complete successful cover PUT, row update to `CoverUploaded`, and `video.metadata` emission before starting the STS S3 video byte transfer for that row in that action

### Requirement: video.metadata serialization without secrets

The `video.metadata` payload MUST NOT contain STS credentials, raw presigned `upload_url` query strings, or session tokens.

#### Scenario: Presigned secrets absent

- **WHEN** any `video.metadata` message is constructed
- **THEN** the payload MUST NOT include `access_key_id`, `secret_access_key`, `session_token`, or full presigned URLs with signing query parameters

