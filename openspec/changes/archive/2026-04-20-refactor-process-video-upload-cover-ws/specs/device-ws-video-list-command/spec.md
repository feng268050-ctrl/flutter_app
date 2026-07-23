## MODIFIED Requirements

### Requirement: Filter process video list by non-zero sync status

The system SHALL expose a read path for process video rows used by the WebSocket list command that includes **only** rows where `uploadStatus` is **not** equal to `0`. The system SHALL compute **`total`** as the count of rows matching that filter and SHALL compute each **`list`** page from the same filter.

#### Scenario: Excluded uninitialized row

- **WHEN** a row exists with `uploadStatus` equal to `0`
- **THEN** that row MUST NOT appear in `data.list` for `command.video_list_response` and MUST NOT be counted in `data.total` for that command

#### Scenario: Included progressed row

- **WHEN** a row exists with `uploadStatus` not equal to `0`
- **THEN** that row MUST be eligible for `data.list` and MUST be counted in `data.total`

### Requirement: List item payload minimization

The system SHALL include in each `data.list` element a stable set of fields sufficient to identify and display the video metadata **without** requiring a second round trip for the same row, **excluding** large opaque blobs unless a separate requirement explicitly adds them. At minimum the object SHOULD include: `videoId`, `createTime`, `duration`, `fileSize`, `resolution`, `processType`, `materialType`, `uploadStatus`, `uploadProgress`, `coverUrl`, and `videoUrl` when applicable. Wire serialization MAY use **snake_case** keys (for example `video_id`, `create_time`, `upload_status`) for JSON objects in `data.list`.

#### Scenario: No processData by default

- **WHEN** the device builds `data.list` for `command.video_list_response`
- **THEN** the payload MUST NOT include a `processData` / `process_data` field unless a superseding project requirement explicitly adds it

#### Scenario: Internal storage fields not exposed

- **WHEN** the device serializes each element of `data.list` for `command.video_list_response`
- **THEN** the object MUST NOT include the local database row identifier or local filesystem path fields (for example `id`, `video_path`)
