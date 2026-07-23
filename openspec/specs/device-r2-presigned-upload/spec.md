## Purpose

Define the device-side contract for uploading process-video **cover images** and **video files** to Cloudflare R2 via the Worker **presigned PUT** API (`/upload/device/presigned-put`), including HTTPS origin selection aligned with the LaserCyber Worker hosts, object key layout, JSON envelope parsing, and direct PUT semantics. **Monitor → Videos** list video file bytes use **R2 STS S3** (`POST /v1/storage/r2/sts`) per `storage-r2-sts-s3-client` and the key layout below; presigned-put remains for covers (and legacy paths where still applicable).
## Requirements
### Requirement: Worker HTTPS origin for presigned-put

The system SHALL derive the Worker API **HTTPS origin** (a string that includes the `https://` scheme) using `DeviceApiOriginConfig.resolveHttpsApiOrigin()`, and SHALL construct the presign endpoint as that origin immediately followed by `/upload/device/presigned-put` (no duplicate slash).

#### Scenario: Release channel uses production Worker origin

- **WHEN** the application build has `RELEASE_CHANNEL` true
- **THEN** presigned-put requests SHALL use HTTPS origin `https://api-prod.lasercyber.workers.dev`

#### Scenario: Non-release channel uses test Worker origin

- **WHEN** the application build has `RELEASE_CHANNEL` false
- **THEN** presigned-put requests SHALL use HTTPS origin `https://api-test.lasercyber.workers.dev`

### Requirement: Presign query parameters and object keys

The system SHALL call the presign endpoint with HTTP GET and query parameters `sn`, `content_type`, `file_name`, and `key`.

For **video** objects tied to a persisted process-video row (business UUID `video_id` on `t_params_process_video`), `key` SHALL be `uploads/devices/{sn}/videos/{date}/{video_id}.{ext}` where `{date}` is the device-local calendar date formatted as `yyyy-MM-dd`, `{sn}` matches the `sn` query parameter, `{video_id}` is that row’s UUID string, and `{ext}` is the storage extension for the object (for the main video file, typically `mp4`). The `file_name` query parameter SHOULD match the final path segment (e.g. `{video_id}.mp4`).

For **cover JPEG** objects tied to the **same** row, `key` SHALL be `uploads/devices/{sn}/videos/{date}/{video_id}.jpg` with the same `{sn}`, `{date}`, and `{video_id}` as the video object for that row.

#### Scenario: Video key uses `videos/` date folder and `video_id`

- **WHEN** presign is requested for serial `ABC`, date `2026-04-12`, and `video_id` UUID `f47ac10b-58cc-4372-a567-0e02b2c3d479` for an MP4 object
- **THEN** the `key` parameter SHALL be `uploads/devices/ABC/videos/2026-04-12/f47ac10b-58cc-4372-a567-0e02b2c3d479.mp4`

#### Scenario: Cover key pairs with the same `video_id` under `.jpg`

- **WHEN** presign is requested for the JPEG cover for the same serial, date, and `video_id`
- **THEN** the `key` parameter SHALL be `uploads/devices/ABC/videos/2026-04-12/f47ac10b-58cc-4372-a567-0e02b2c3d479.jpg`

### Requirement: ApiResult JSON is parsed for every HTTP status

The system SHALL read the presign response body as UTF-8 whenever a body is present and SHALL attempt to deserialize it into the Worker envelope with fields `code`, `success`, `data`, and `message` (snake_case JSON keys as returned by the Worker). This attempt SHALL run for presign responses regardless of HTTP status code (including non-2xx). If JSON parsing fails, the system SHALL treat the presign call as failed and SHALL log HTTP status and a truncated raw body snippet.

#### Scenario: HTTP 400 with JSON body drives logical error

- **WHEN** the presign HTTP status is 400 and the body is valid JSON with `success` false and `message` set
- **THEN** the client SHALL surface the failure using `message` and SHALL not treat the call as success based on HTTP status alone when JSON parses

### Requirement: Successful presign payload and PUT upload

When `success` is true and `data` is non-null, the system SHALL require non-empty `upload_url`, `method` equal to `PUT` ignoring case, and non-empty `public_url`. The system SHALL use `expires_in_seconds` when present as a hint to bound OkHttp read/write/call timeouts for the subsequent PUT.

The system SHALL upload bytes to `upload_url` with HTTP PUT and a `Content-Type` header equal to the `content_type` query parameter used for presign. Video files SHALL be streamed from disk without loading the entire file into memory. Cover images MAY be uploaded from in-memory JPEG bytes using chunked writes for progress reporting.

#### Scenario: PUT success allows follow-up metadata steps

- **WHEN** the PUT completes with a 2xx HTTP status for a **cover** object tied to a process-video row
- **THEN** the system SHALL treat the object upload as successful for that asset, SHALL persist `coverUrl` from the presign `public_url` (or equivalent stable public URL string returned by the presign contract), SHALL set `uploadStatus` to `1` (`CoverUploaded`) per `device-video-metadata`, and SHALL emit `video.metadata` per `device-ws-video-metadata` before any STS video byte transfer for that row begins in the same user action

#### Scenario: PUT non-success is a hard failure

- **WHEN** the PUT completes without a 2xx status
- **THEN** the system SHALL treat the upload as failed for that asset and SHALL not rely on `public_url` as reachable storage for downstream steps

### Requirement: Monitor list upload uses R2 STS S3 for video with optional metadata-first step

For the **Monitor → Videos** list action on a persisted row (non-null `video_id`), the system SHALL upload the main video file bytes using temporary credentials from `POST /v1/storage/r2/sts` and an S3-compatible client (`DeviceR2StsS3Client` contract). The object key SHALL match the **video** key shape in `Requirement: Presign query parameters and object keys` (`uploads/devices/{sn}/videos/{date}/{video_id}.mp4` by default). The system SHALL NOT call `/upload/device/presigned-put` for that **video** object unless a separately documented legacy or debug flag re-enables presigned video upload.

When the row’s `uploadStatus` equals `0` (NotInitiated), the same list action SHALL first run the **presigned-put cover JPEG upload** (and associated row updates and `video.metadata` emission per companion specs) using the cover object key `uploads/devices/{sn}/videos/{date}/{video_id}.jpg`, and SHALL only start the STS video upload after `uploadStatus` reflects `CoverUploaded`. When `uploadStatus` is already `1` (`CoverUploaded`) before the action starts, the system SHALL NOT repeat the cover presign+PUT+WS metadata emission as a prerequisite solely because the user clicked upload.

#### Scenario: List upload when cover pending runs cover first

- **WHEN** the user triggers upload from the Monitor video list and the row has `uploadStatus` equal to `0`
- **THEN** the client MUST perform cover presigned upload and related state transitions before starting the STS video byte transfer

#### Scenario: List upload when cover done skips cover pipeline

- **WHEN** the user triggers upload from the Monitor video list and the row has `uploadStatus` equal to `1` (`CoverUploaded`)
- **THEN** the client MUST proceed directly to STS video upload without repeating cover presign+PUT+`video.metadata` as a prerequisite of that action

### Requirement: Presigned cover PUT uses corrected key when still needed

Any remaining presigned-put **cover** upload that is not superseded by another change SHALL use `key` equal to `uploads/devices/{sn}/videos/{date}/{video_id}.jpg` as specified above; the system MUST NOT use a `covers/` path segment under `uploads/devices/{sn}/{date}/` for new cover objects for process videos.

#### Scenario: Legacy covers subdirectory is not used for new keys

- **WHEN** the client builds a presigned-put request for a process-video cover JPEG for a row with known `video_id`
- **THEN** the `key` parameter MUST NOT be formed as `uploads/devices/{sn}/{date}/covers/{file_name}` for that flow

