## MODIFIED Requirements

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
