## MODIFIED Requirements

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

## ADDED Requirements

### Requirement: Monitor list upload uses R2 STS S3 for video with optional metadata-first step

For the **Monitor → Videos** list action on a persisted row (non-null `video_id`), the system SHALL upload the main video file bytes using temporary credentials from `POST /v1/storage/r2/sts` and an S3-compatible client (`DeviceR2StsS3Client` contract). The object key SHALL match the **video** key shape in `Requirement: Presign query parameters and object keys` (`uploads/devices/{sn}/videos/{date}/{video_id}.mp4` by default). The system SHALL NOT call `/upload/device/presigned-put` for that **video** object unless a separately documented legacy or debug flag re-enables presigned video upload.

When the row’s `syncStatus` equals `0` (metadata not yet successfully uploaded), the same list action SHALL first run the cover + Worker metadata multipart flow (per `device-video-metadata`) using the corrected cover object key, and SHALL only start the STS video upload after metadata succeeds and `syncStatus` reflects `MetadataUploaded`. When `syncStatus` is already `1` (`MetadataUploaded`) before the action starts, the system SHALL NOT re-run the metadata `POST` as part of that list upload action and SHALL proceed directly to the STS video upload.

#### Scenario: List upload when metadata pending runs metadata first

- **WHEN** the user triggers upload from the Monitor video list and the row has `syncStatus` equal to `0`
- **THEN** the client MUST perform cover + metadata upload before starting the STS video byte transfer

#### Scenario: List upload when metadata done skips metadata

- **WHEN** the user triggers upload from the Monitor video list and the row has `syncStatus` equal to `1` (MetadataUploaded)
- **THEN** the client MUST NOT require a successful metadata `POST` in that same action before starting the STS video upload

### Requirement: Presigned cover PUT uses corrected key when still needed

Any remaining presigned-put **cover** upload that is not superseded by another change SHALL use `key` equal to `uploads/devices/{sn}/videos/{date}/{video_id}.jpg` as specified above; the system MUST NOT use a `covers/` path segment under `uploads/devices/{sn}/{date}/` for new cover objects for process videos.

#### Scenario: Legacy covers subdirectory is not used for new keys

- **WHEN** the client builds a presigned-put request for a process-video cover JPEG for a row with known `video_id`
- **THEN** the `key` parameter MUST NOT be formed as `uploads/devices/{sn}/{date}/covers/{file_name}` for that flow
