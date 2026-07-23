## MODIFIED Requirements

### Requirement: Local process video row includes metadata sync fields

The system SHALL persist on `t_params_process_video` (entity `ProcessParamsVideo`): `videoId` (TEXT, UUID assigned at insert), `resolution` (TEXT), `syncStatus` (INTEGER), `uploadProgress` (INTEGER), `materialType` (INTEGER, nullable; same semantics as `MaterialTypeEnum` when set), `coverUrl` (TEXT, nullable; hosted cover URL returned from Worker metadata success when available), and `videoUrl` (TEXT, nullable; reserved for a future video file URL, not populated by metadata-only flows in this capability). These SHALL be independent of the existing `status` column. The system SHALL NOT use a column named `materials` on this table; the former `materials` column SHALL be renamed to `materialType` at the SQLite layer.

The system SHALL define `syncStatus` integer values as: `0` NotInitiated (initial; metadata not yet successfully uploaded); `1` MetadataUploaded; `2` VideoUploading (reserved); `3` VideoUploaded (reserved). For rows created by this feature, the system SHALL set `syncStatus` to `0` and `uploadProgress` to `0` at insert time.

#### Scenario: New row on successful recording save

- **WHEN** a recording completes, passes file checks, and is inserted
- **THEN** the row MUST have non-null `videoId`, non-null textual `resolution`, `syncStatus` equal to `0`, `uploadProgress` equal to `0`, `coverUrl` unset (null), and `videoUrl` unset (null)

### Requirement: Metadata multipart fields and create_time source

The metadata `POST` SHALL use multipart form field names: `video_id`, `cover`, `duration`, `resolution`, `file_size`, `create_time`, `process_type`, `material_type`, `process_data` (JSON text). The `video_id` part value SHALL be a **standard UUID string** (RFC 4122) matching the row’s `videoId` column; the device MUST reject non-UUID values before calling the endpoint so failures are visible locally. The `create_time` part value MUST denote the same instant as the row’s persisted `createTime` (stored as Unix epoch milliseconds in the database). The `material_type` part value SHALL be the decimal string of the row’s `materialType` column (same integer semantics as `MaterialTypeEnum` when set); when `materialType` is unset the part MAY be an empty string.

The server SHALL accept `create_time` as a decimal string in either **Unix seconds** or **Unix milliseconds** since epoch. The device SHALL send **milliseconds** by default using `String.valueOf(createTime)`.

#### Scenario: Default create_time as milliseconds string

- **WHEN** the client builds the metadata request for a saved row with `createTime` set at save time
- **THEN** the default `create_time` form field MUST be the decimal string of that millisecond epoch value

#### Scenario: Seconds string is also valid for the same instant

- **WHEN** a client sends `create_time` as the decimal string of `floor(createTime / 1000)` seconds for the same wall-clock instant
- **THEN** the server contract SHALL treat that format as valid (alongside millisecond strings) per agreed parsing rules

### Requirement: Successful ApiResult transitions metadata state

- **WHEN** the server returns a successful standard Worker `ApiResult` JSON envelope for metadata with `success: true` (including `data` null; `code` and `message` are informational and MUST NOT be used to infer success when `success` is not true)
- **THEN** the system MUST set `syncStatus` to `1` (MetadataUploaded), MUST leave `uploadProgress` at `0` unless a later feature assigns progress semantics, and MUST update `coverUrl` from the response when present: if `data` is a JSON object with a string property `cover_url` whose trimmed value is non-empty, the system MUST persist that string on the row’s `coverUrl`; if `data` is null or `cover_url` is absent, null, or empty after trim, the system MUST still treat the upload as successful and MAY leave `coverUrl` null (no failure solely for missing `cover_url`)

## ADDED Requirements

### Requirement: Process video row reserves nullable videoUrl

The system SHALL allow `videoUrl` on `t_params_process_video` to remain null for all flows implemented under the device-video-metadata capability. No requirement in this capability SHALL mandate populating `videoUrl` from the metadata `POST` response unless explicitly added by a future change.

#### Scenario: Metadata success does not require videoUrl

- **WHEN** metadata upload completes with `success: true` and `data` contains no video file URL field
- **THEN** the system MUST NOT require `videoUrl` to be non-null for the row to reach `MetadataUploaded`
