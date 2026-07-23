## MODIFIED Requirements

### Requirement: Local process video row includes metadata sync fields

The system SHALL persist on `t_params_process_video` (entity `ProcessParamsVideo`): `videoId` (TEXT, UUID assigned at insert), `resolution` (TEXT), `uploadStatus` (INTEGER), `uploadProgress` (INTEGER), `materialType` (INTEGER, nullable; same semantics as `MaterialTypeEnum` when set), `coverUrl` (TEXT, nullable; stable public URL from successful presigned cover PUT per `device-r2-presigned-upload` when available), and `videoUrl` (TEXT, nullable; populated when a Monitor process video **file** upload to R2 completes and a stable public URL is known; remains null after cover-only success until such upload completes). The system SHALL NOT persist a legacy `status` column on this table. The system SHALL NOT use a column named `materials` on this table; the former `materials` column SHALL be renamed to `materialType` at the SQLite layer.

The system SHALL NOT call `POST /v1/devices/:sn/videos/metadata` for these rows as part of this capability.

The system SHALL define `uploadStatus` integer values as: `0` NotInitiated (initial; cover not yet successfully uploaded to R2 via presigned PUT); `1` CoverUploaded (cover object upload succeeded and `coverUrl` persisted); `2` VideoUploading (during R2 STS S3 byte transfer for Monitor process video file upload); `3` VideoUploaded (after successful completion of that transfer). Application code SHALL represent these values using the enum `VideoUploadStatus` (replacing `VideoSyncStatus`). For rows created by this feature, the system SHALL set `uploadStatus` to `0` and `uploadProgress` to `0` at insert time.

#### Scenario: New row on successful recording save

- **WHEN** a recording completes, passes file checks, and is inserted
- **THEN** the row MUST have non-null `videoId`, non-null textual `resolution`, `uploadStatus` equal to `0`, `uploadProgress` equal to `0`, `coverUrl` unset (null), and `videoUrl` unset (null)
