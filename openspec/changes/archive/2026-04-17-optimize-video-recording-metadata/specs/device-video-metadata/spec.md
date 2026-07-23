## ADDED Requirements

### Requirement: Local process video row includes metadata sync fields

The system SHALL persist on `t_params_process_video` (entity `ProcessParamsVideo`): `videoId` (TEXT, UUID assigned at insert), `resolution` (TEXT), `syncStatus` (INTEGER), and `uploadProgress` (INTEGER). These SHALL be independent of the existing `status` column.

The system SHALL define `syncStatus` integer values as: `0` NotInitiated (initial; metadata not yet successfully uploaded); `1` MetadataUploaded; `2` VideoUploading (reserved); `3` VideoUploaded (reserved). For rows created by this feature, the system SHALL set `syncStatus` to `0` and `uploadProgress` to `0` at insert time.

#### Scenario: New row on successful recording save

- **WHEN** a recording completes, passes file checks, and is inserted
- **THEN** the row MUST have non-null `videoId`, non-null textual `resolution`, `syncStatus` equal to `0`, and `uploadProgress` equal to `0`

### Requirement: Metadata multipart fields and create_time source

The metadata `POST` SHALL use multipart form field names: `video_id`, `cover`, `duration`, `resolution`, `file_size`, `create_time`, `process_type`, `process_data` (JSON text). The `create_time` part value MUST denote the same instant as the row’s persisted `createTime` (stored as Unix epoch milliseconds in the database).

The server SHALL accept `create_time` as a decimal string in either **Unix seconds** or **Unix milliseconds** since epoch. The device SHALL send **milliseconds** by default using `String.valueOf(createTime)`.

#### Scenario: Default create_time as milliseconds string

- **WHEN** the client builds the metadata request for a saved row with `createTime` set at save time
- **THEN** the default `create_time` form field MUST be the decimal string of that millisecond epoch value

#### Scenario: Seconds string is also valid for the same instant

- **WHEN** a client sends `create_time` as the decimal string of `floor(createTime / 1000)` seconds for the same wall-clock instant
- **THEN** the server contract SHALL treat that format as valid (alongside millisecond strings) per agreed parsing rules

### Requirement: JPEG cover required; failure aborts metadata upload

The system SHALL encode `cover` as JPEG. If first-frame extraction or JPEG encoding fails, the system MUST NOT treat metadata upload as successful, MUST NOT set `syncStatus` to `1`, and MUST leave `syncStatus` at `0` (or equivalent not-uploaded state) for retry.

#### Scenario: Cover extraction failure

- **WHEN** cover extraction fails
- **THEN** the system MUST NOT perform a successful metadata completion transition to `MetadataUploaded`

### Requirement: Silent metadata upload without client auth headers

Metadata upload SHALL be silent (no user confirmation step). The HTTP request SHALL NOT rely on client-added auth headers beyond what the shared OkHttp stack already applies globally; server-side SN validation is authoritative. Invalid or unknown device SN SHALL skip the HTTP call and keep `syncStatus` at `0`.

#### Scenario: Invalid SN skips network

- **WHEN** the device serial is missing or invalid per project rules
- **THEN** the system MUST not call the metadata endpoint and MUST keep `syncStatus` at `0`

### Requirement: POST device video metadata after local save when possible

After insert, the system SHOULD enqueue or trigger metadata upload off the main thread. The `POST` path SHALL be `/v1/devices/:sn/videos/metadata` on the pinned Worker API base.

#### Scenario: Successful ApiResult transitions metadata state

- **WHEN** the server returns success per `ApiResult` with `data` null
- **THEN** the system MUST set `syncStatus` to `1` (MetadataUploaded) and MUST leave `uploadProgress` at `0` unless a later feature assigns progress semantics

### Requirement: WorkManager backlog when network and pin are ready

When the application has selected a pinned API base after `NetworkCallback`-driven probing (or equivalent “server address chosen” hook), the system SHALL check for rows with `syncStatus = 0` that are eligible for metadata upload and SHALL enqueue WorkManager work to upload metadata for each such row sequentially (one metadata job at a time per implementation plan, no video file upload in this change).

#### Scenario: Offline recording later uploads metadata

- **WHEN** a row exists with `syncStatus = 0` and the network becomes available with a valid pinned base and SN
- **THEN** the system SHALL eventually run a WorkManager worker that attempts the metadata POST for that row until success or until cover/validation prevents success

### Requirement: Metadata sync does not block the UI thread

Cover extraction, JPEG encoding, and metadata HTTP MUST run off the Android main thread.

#### Scenario: UI thread not blocked

- **WHEN** metadata upload runs after recording
- **THEN** the main thread MUST not synchronously perform the metadata HTTP call
