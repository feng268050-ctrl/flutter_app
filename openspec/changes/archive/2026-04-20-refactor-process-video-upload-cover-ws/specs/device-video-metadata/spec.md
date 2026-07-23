## REMOVED Requirements

### Requirement: Metadata multipart fields and create_time source

**Reason**: The device no longer posts multipart catalog metadata to the Worker; the server uses `command.video_list_request` / `command.video_list_response` for live inventory and `video.metadata` for post-cover updates.

**Migration**: Implement catalog fields on `video.metadata` per `device-ws-video-metadata` after successful presigned cover upload.

### Requirement: Silent metadata upload without client auth headers

**Reason**: The Worker `POST /v1/devices/:sn/videos/metadata` path is removed for process videos under this capability.

**Migration**: N/A.

### Requirement: POST device video metadata after local save when possible

**Reason**: Same as multipart metadata removal.

**Migration**: Use cover presigned upload + `uploadStatus` + `video.metadata` instead.

### Requirement: WorkManager backlog when network and pin are ready

**Reason**: Dedicated WorkManager draining of pending **HTTP metadata POST** rows is no longer part of the contract.

**Migration**: Pending cover+metadata work MAY be retried via user-initiated Monitor upload or a replacement strategy documented in implementation tasks; it MUST NOT rely on the removed metadata POST worker.

## MODIFIED Requirements

### Requirement: Local process video row includes metadata sync fields

The system SHALL persist on `t_params_process_video` (entity `ProcessParamsVideo`): `videoId` (TEXT, UUID assigned at insert), `resolution` (TEXT), `uploadStatus` (INTEGER), `uploadProgress` (INTEGER), `materialType` (INTEGER, nullable; same semantics as `MaterialTypeEnum` when set), `coverUrl` (TEXT, nullable; stable public URL from successful presigned cover PUT per `device-r2-presigned-upload` when available), and `videoUrl` (TEXT, nullable; populated when a Monitor process video **file** upload to R2 completes and a stable public URL is known; remains null after cover-only success until such upload completes). These SHALL be independent of the existing `status` column. The system SHALL NOT use a column named `materials` on this table; the former `materials` column SHALL be renamed to `materialType` at the SQLite layer.

The system SHALL NOT call `POST /v1/devices/:sn/videos/metadata` for these rows as part of this capability.

The system SHALL define `uploadStatus` integer values as: `0` NotInitiated (initial; cover not yet successfully uploaded to R2 via presigned PUT); `1` CoverUploaded (cover object upload succeeded and `coverUrl` persisted); `2` VideoUploading (during R2 STS S3 byte transfer for Monitor process video file upload); `3` VideoUploaded (after successful completion of that transfer). Application code SHALL represent these values using the enum `VideoUploadStatus` (replacing `VideoSyncStatus`). For rows created by this feature, the system SHALL set `uploadStatus` to `0` and `uploadProgress` to `0` at insert time.

#### Scenario: New row on successful recording save

- **WHEN** a recording completes, passes file checks, and is inserted
- **THEN** the row MUST have non-null `videoId`, non-null textual `resolution`, `uploadStatus` equal to `0`, `uploadProgress` equal to `0`, `coverUrl` unset (null), and `videoUrl` unset (null)

### Requirement: JPEG cover required; failure aborts metadata upload

The system SHALL encode the cover artifact as JPEG for presigned upload. If first-frame extraction or JPEG encoding fails, the system MUST NOT treat cover upload as successful, MUST NOT set `uploadStatus` to `1`, and MUST leave `uploadStatus` at `0` (NotInitiated) for retry.

#### Scenario: Cover extraction failure

- **WHEN** cover extraction fails
- **THEN** the system MUST NOT perform a successful transition to `CoverUploaded`

### Requirement: Process video row reserves nullable videoUrl

The system SHALL allow `videoUrl` on `t_params_process_video` to remain null until a successful Monitor process **video file** upload persists a non-empty URL. `CoverUploaded` alone MUST NOT require `videoUrl` to be non-null.

#### Scenario: Cover uploaded does not require videoUrl

- **WHEN** cover presigned upload completes and `uploadStatus` becomes `1` (`CoverUploaded`)
- **THEN** the system MUST NOT require `videoUrl` to be non-null for that state

#### Scenario: Video file success may set videoUrl

- **WHEN** a Monitor process video file upload completes successfully and a stable public URL string is available for the object
- **THEN** the system MUST persist that string on `videoUrl` and MUST set `uploadStatus` to `3` (VideoUploaded)

### Requirement: STS video upload updates syncStatus and uploadProgress

For a Monitor-triggered process video file upload that uses R2 STS S3 after `uploadStatus` is at least `1` (`CoverUploaded`), the system SHALL set `uploadStatus` to `2` (VideoUploading) immediately before starting the video byte transfer and SHALL update `uploadProgress` to reflect transferred bytes as an integer percentage from `0` through `100` inclusive while the transfer is active. On successful completion of the video object upload, the system SHALL set `uploadStatus` to `3` (VideoUploaded) and SHALL set `uploadProgress` to `100`. On failure after entering `VideoUploading`, the system MUST NOT set `uploadStatus` to `3`, MUST NOT treat the video as uploaded, and SHOULD set `uploadStatus` back to `1` (`CoverUploaded`) with `uploadProgress` reset to `0` so the user may retry video file upload without re-uploading the cover unless the implementation documents a different recovery path.

#### Scenario: Progress increases during upload

- **WHEN** bytes are being written for the video object and total size is known
- **THEN** persisted `uploadProgress` MUST be updated to reflect the ratio of transferred bytes to total size, clamped to `0`–`100`

#### Scenario: Failure rolls back upload state for retry

- **WHEN** the STS session or S3 upload fails after `uploadStatus` was set to `2`
- **THEN** the system MUST NOT leave `uploadStatus` at `3` and SHOULD restore `uploadStatus` to `1` and `uploadProgress` to `0` for retry semantics unless a documented resume feature supersedes this

### Requirement: Monitor list upload may run metadata when syncStatus is zero

When the user starts **Monitor → Videos** list upload for a row with `uploadStatus` equal to `0` (NotInitiated), the system SHALL run the cover presigned-PUT pipeline (per `device-r2-presigned-upload` and this capability’s JPEG rules) and SHALL emit `video.metadata` per `device-ws-video-metadata` before any R2 STS video file upload for that row begins in that action. When `uploadStatus` is already `1` (`CoverUploaded`), the list upload action SHALL NOT repeat this cover pipeline solely because the user clicked upload.

#### Scenario: Cover-first on list upload from state zero

- **WHEN** list upload is started for a row with `uploadStatus` `0` and a valid `video_id`
- **THEN** the system MUST complete cover upload, row update to `CoverUploaded`, and `video.metadata` before starting STS video byte transfer

#### Scenario: No cover repeat when already uploaded

- **WHEN** list upload is started for a row with `uploadStatus` `1`
- **THEN** the system MUST proceed to STS video upload without repeating cover presign+PUT+`video.metadata` as a prerequisite of that action

### Requirement: Metadata sync does not block the UI thread

Cover extraction, JPEG encoding, presign HTTP, cover PUT, WebSocket serialization for `video.metadata`, and STS upload orchestration MUST run off the Android main thread.

#### Scenario: UI thread not blocked

- **WHEN** cover or upload work runs after recording or from Monitor list upload
- **THEN** the main thread MUST not synchronously perform presign HTTP, PUT uploads, or STS byte transfers
