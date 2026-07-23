## MODIFIED Requirements

### Requirement: Local process video row includes metadata sync fields

The system SHALL persist on `t_params_process_video` (entity `ProcessParamsVideo`): `videoId` (TEXT, UUID assigned at insert), `resolution` (TEXT), `syncStatus` (INTEGER), `uploadProgress` (INTEGER), `materialType` (INTEGER, nullable; same semantics as `MaterialTypeEnum` when set), `coverUrl` (TEXT, nullable; hosted cover URL returned from Worker metadata success when available), and `videoUrl` (TEXT, nullable; populated when a Monitor process video **file** upload to R2 completes and a stable public URL is known; remains null after metadata-only success until such upload completes). These SHALL be independent of the existing `status` column. The system SHALL NOT use a column named `materials` on this table; the former `materials` column SHALL be renamed to `materialType` at the SQLite layer.

The system SHALL define `syncStatus` integer values as: `0` NotInitiated (initial; metadata not yet successfully uploaded); `1` MetadataUploaded; `2` VideoUploading (during R2 STS S3 byte transfer for Monitor process video file upload); `3` VideoUploaded (after successful completion of that transfer). For rows created by this feature, the system SHALL set `syncStatus` to `0` and `uploadProgress` to `0` at insert time.

#### Scenario: New row on successful recording save

- **WHEN** a recording completes, passes file checks, and is inserted
- **THEN** the row MUST have non-null `videoId`, non-null textual `resolution`, `syncStatus` equal to `0`, `uploadProgress` equal to `0`, `coverUrl` unset (null), and `videoUrl` unset (null)

### Requirement: Successful ApiResult transitions metadata state

#### Scenario: Successful ApiResult transitions metadata state

- **WHEN** the server returns a successful standard Worker `ApiResult` JSON envelope for metadata with `success: true` (including `data` null; `code` and `message` are informational and MUST NOT be used to infer success when `success` is not true)
- **THEN** the system MUST set `syncStatus` to `1` (MetadataUploaded), MUST set `uploadProgress` to `0` at this metadata completion boundary (before any video file byte upload begins), and MUST update `coverUrl` from the response when present: if `data` is a JSON object with a string property `cover_url` whose trimmed value is non-empty, the system MUST persist that string on the row’s `coverUrl`; if `data` is null or `cover_url` is absent, null, or empty after trim, the system MUST still treat the upload as successful and MAY leave `coverUrl` null (no failure solely for missing `cover_url`). The metadata response MUST NOT be used to populate `videoUrl` for the object file.

### Requirement: Process video row reserves nullable videoUrl

The system SHALL allow `videoUrl` on `t_params_process_video` to remain null until a successful Monitor process **video file** upload persists a non-empty URL. Metadata success alone MUST NOT require `videoUrl` to be non-null for the row to reach `MetadataUploaded`.

#### Scenario: Metadata success does not require videoUrl

- **WHEN** metadata upload completes with `success: true` and `data` contains no video file URL field
- **THEN** the system MUST NOT require `videoUrl` to be non-null for the row to reach `MetadataUploaded`

#### Scenario: Video file success may set videoUrl

- **WHEN** a Monitor process video file upload completes successfully and a stable public URL string is available for the object
- **THEN** the system MUST persist that string on `videoUrl` and MUST set `syncStatus` to `3` (VideoUploaded)

### Requirement: WorkManager backlog when network and pin are ready

When the application has selected a pinned API base after `NetworkCallback`-driven probing (or equivalent “server address chosen” hook), the system SHALL check for rows with `syncStatus = 0` that are eligible for metadata upload and SHALL enqueue WorkManager work to upload metadata for each such row sequentially (one metadata job at a time per implementation plan). WorkManager workers under this capability SHALL perform the metadata `POST` only; **video file** upload to R2 for Monitor flows SHALL be driven by the interactive upload path (or equivalent non-WorkManager executor) unless a future change explicitly enqueues it.

After each coalesced drain that enqueues WorkManager jobs, when a pinned API base is set, the system SHOULD also run **one** immediate pass of the same metadata upload implementation on a pooled background thread (same ordering as pending row ids), so uploads are not blocked solely behind JobScheduler / WorkManager scheduling or overly strict network constraints on some devices/emulators. WorkManager SHALL remain authoritative for persistence across process death and for retries after failures.

The system SHOULD, after a **cold process start** (e.g. device reboot and app launch), trigger reachability probing on the **currently active default network** when one exists, so a pinned Worker API base can be selected without waiting for a fresh `onAvailable` edge if the network was already up before callback registration. **Pending metadata WorkManager jobs SHALL be enqueued only after a successful probe has pinned a base** (same hook as `NetworkCallback`-driven probing), not directly from the cold-start path before pin.

#### Scenario: Offline recording later uploads metadata

- **WHEN** a row exists with `syncStatus = 0` and the network becomes available with a valid pinned base and SN
- **THEN** the system SHALL eventually run a WorkManager worker that attempts the metadata POST for that row until success or until cover/validation prevents success

## ADDED Requirements

### Requirement: STS video upload updates syncStatus and uploadProgress

For a Monitor-triggered process video file upload that uses R2 STS S3 after metadata success, the system SHALL set `syncStatus` to `2` (VideoUploading) immediately before starting the video byte transfer and SHALL update `uploadProgress` to reflect transferred bytes as an integer percentage from `0` through `100` inclusive while the transfer is active. On successful completion of the video object upload, the system SHALL set `syncStatus` to `3` (VideoUploaded) and SHALL set `uploadProgress` to `100`. On failure after entering `VideoUploading`, the system MUST NOT set `syncStatus` to `3`, MUST NOT treat the video as uploaded, and SHOULD set `syncStatus` back to `1` (MetadataUploaded) with `uploadProgress` reset to `0` so the user may retry without re-running metadata unless the implementation documents a different recovery path.

#### Scenario: Progress increases during upload

- **WHEN** bytes are being written for the video object and total size is known
- **THEN** persisted `uploadProgress` MUST be updated to reflect the ratio of transferred bytes to total size, clamped to `0`–`100`

#### Scenario: Failure rolls back upload state for retry

- **WHEN** the STS session or S3 upload fails after `syncStatus` was set to `2`
- **THEN** the system MUST NOT leave `syncStatus` at `3` and SHOULD restore `syncStatus` to `1` and `uploadProgress` to `0` for retry semantics unless a documented resume feature supersedes this

### Requirement: Monitor list upload may run metadata when syncStatus is zero

When the user starts **Monitor → Videos** list upload for a row with `syncStatus` equal to `0` (NotInitiated), the system SHALL run the same metadata pipeline as this capability (JPEG cover and `POST /v1/devices/:sn/videos/metadata` with required multipart fields) before any R2 STS video file upload for that row begins in that action. The presigned cover object key used in that path SHALL follow the updated R2 key layout from the `device-r2-presigned-upload` delta (`uploads/devices/{sn}/videos/{date}/{video_id}.jpg`). When `syncStatus` is already `1` (MetadataUploaded), the list upload action SHALL NOT repeat this metadata pipeline solely because the user clicked upload.

#### Scenario: Metadata-first on list upload from state zero

- **WHEN** list upload is started for a row with `syncStatus` `0` and a valid `video_id`
- **THEN** the system MUST attempt metadata upload first and MUST NOT start STS video byte transfer until metadata succeeds and `syncStatus` is `1`

#### Scenario: No metadata repeat when already uploaded

- **WHEN** list upload is started for a row with `syncStatus` `1`
- **THEN** the system MUST proceed to STS video upload without issuing the metadata `POST` as a prerequisite of that action
