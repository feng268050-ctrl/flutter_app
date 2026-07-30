# process-video Specification

## Purpose

Local process-video index for Quick/Engineer Record Work: SQLite rows with frozen process-parameter snapshots, newest-first paging, and local file delete. Cloud upload and HAL product coupling are out of scope.

## Requirements

### Requirement: Process video rows persist on successful Record Work stop

When Quick or Engineer Record Work encoding stops successfully, the App SHALL insert one process-video row into a durable SQLite index (under `/var/lib/hmi/`, e.g. `process-videos.db`) with at least: stable `video_id` (UUID), absolute `video_path`, `process_type`, optional `material_type`, `process_parameters_json` snapshot, `file_size`, `duration_ms`, optional `resolution`, and `create_time_ms`. Upload-related columns MAY exist with default local-only values (`upload_status = 0`, empty cloud URLs) but MUST NOT require network. The App MUST NOT store only a live preset foreign key without the parameter snapshot. Settings demo Record/Stop MUST NOT insert business process-video rows.

#### Scenario: Armed laser session produces a listable row

- **WHEN** Record Work is armed, laser enable becomes on long enough to produce a playable MP4, then laser enable turns off (or Record Work disarms)
- **THEN** a new process-video row references that MP4 path and appears in queries ordered by newest `create_time_ms`

#### Scenario: Short or invalid file is discarded

- **WHEN** encoding stops but the output is unreadable or shorter than the configured minimum duration (~1 s)
- **THEN** the App MUST NOT insert a process-video row for that file
- **AND** MUST soft-fail with operator feedback without crashing the mode page

#### Scenario: Settings demo remains isolated

- **WHEN** the operator uses Common Settings → Camera demo Record/Stop
- **THEN** the resulting MP4 MUST NOT be inserted into the process-video business index

### Requirement: Process parameter snapshot is frozen at record time

The process-video save path SHALL capture process type, material (when applicable), and process parameter values as JSON at recording time (prefer snapshot taken when encode starts; may refresh from the active Quick/Engineer UI when still attached and process type matches). Historical rows MUST remain meaningful after presets are edited or deleted.

#### Scenario: Preset edit does not rewrite history

- **WHEN** a process-video row was saved with parameter snapshot S, and the operator later edits the preset that was loaded during recording
- **THEN** reading that row still yields snapshot S (not the edited preset values)

#### Scenario: Snapshot available without live UI attachment

- **WHEN** encode started with a valid start snapshot and the mode UI is no longer providing live params at stop
- **THEN** save SHALL still persist using the start snapshot

### Requirement: Local delete removes file and index row

Deleting a process-video entry SHALL remove the SQLite row and best-effort delete the MP4 at `video_path`. Missing files MUST still allow row deletion (soft-fail file I/O).

#### Scenario: Delete from repository

- **WHEN** the App deletes a process-video by local id
- **THEN** subsequent list queries omit that row
- **AND** the MP4 is removed when the path still exists

### Requirement: Repository lists newest-first with paging

The process-video repository SHALL support newest-first listing with a page size compatible with Monitor (lws-ui uses 10) and a total count for footer/progress display. Queries MUST NOT require `upload_status != 0`.

#### Scenario: Empty library

- **WHEN** no process-video rows exist
- **THEN** list queries return an empty page and total count 0 without error

#### Scenario: Page beyond first

- **WHEN** more than one page of rows exists
- **THEN** requesting the next offset/page returns older rows without duplicates of the first page

### Requirement: HAL recording API stays product-neutral

Process-video persistence MUST live in the App layer. `cyber_hal` IP-camera recording types MUST NOT gain Quick/Engineer, process-parameter, or video-database fields.

#### Scenario: Recording result remains file-oriented

- **WHEN** HAL recording completes
- **THEN** the HAL result exposes file/path/timing/size style fields only
- **AND** the App maps those into the process-video row
