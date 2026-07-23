## Purpose

Define device-side behavior for listing persisted process videos over the WebSocket command pair `command.video_list_request` / `command.video_list_response`, including pagination and the **`syncStatus != 0`** visibility rule.

## Requirements

### Requirement: Filter process video list by non-zero sync status

The system SHALL expose a read path for process video rows used by the WebSocket list command that includes **only** rows where `syncStatus` is **not** equal to `0`. The system SHALL compute **`total`** as the count of rows matching that filter and SHALL compute each **`list`** page from the same filter.

#### Scenario: Excluded uninitialized row

- **WHEN** a row exists with `syncStatus` equal to `0`
- **THEN** that row MUST NOT appear in `data.list` for `command.video_list_response` and MUST NOT be counted in `data.total` for that command

#### Scenario: Included progressed row

- **WHEN** a row exists with `syncStatus` not equal to `0`
- **THEN** that row MUST be eligible for `data.list` and MUST be counted in `data.total`

### Requirement: Paginated ordering for the list command

The system SHALL return list rows ordered by **`createTime` descending** (newest first). Pagination SHALL use **1-based** `page` and **`page_size`** from the request payload. The system SHALL apply **`LIMIT page_size OFFSET (page - 1) * page_size`** semantics (or equivalent) against the filtered row set.

#### Scenario: Second page

- **WHEN** `total` is greater than `page_size` and the request specifies `page` equal to `2` with a given `page_size`
- **THEN** `data.list` MUST contain at most `page_size` rows and MUST correspond to the second window of the ordered filtered set

### Requirement: Request parameter validation and bounds

The system SHALL read numeric fields `page` and `page_size` from the inbound `payload`. The system SHALL treat non-positive or non-finite values as invalid for pagination. For invalid or missing `page`, the system SHALL behave as **`page` = 1**. For invalid or missing `page_size`, the system SHALL use a **default page size**; the system SHALL **cap** `page_size` at a **maximum** to prevent oversized responses.

#### Scenario: Oversized page_size is clamped

- **WHEN** the request payload contains `page_size` larger than the configured maximum
- **THEN** the system MUST use the maximum allowed `page_size` for the query and response

### Requirement: Off-main-thread database access

The system SHALL NOT perform Room/SQLite queries for this list on the Android main thread. Database reads for count and list SHALL run on a background executor consistent with other inbound WebSocket command handlers in the app.

#### Scenario: Handler defers to worker

- **WHEN** an inbound `command.video_list_request` is accepted for processing
- **THEN** blocking database operations MUST occur outside the main thread

### Requirement: List item payload minimization

The system SHALL include in each `data.list` element a stable set of fields sufficient to identify and display the video metadata **without** requiring a second round trip for the same row, **excluding** large opaque blobs unless a separate requirement explicitly adds them. At minimum the object SHOULD include: `videoId`, `createTime`, `duration`, `fileSize`, `resolution`, `processType`, `materialType`, `syncStatus`, `uploadProgress`, `coverUrl`, and `videoUrl` when applicable. Wire serialization MAY use **snake_case** keys (for example `video_id`, `create_time`) for JSON objects in `data.list`.

#### Scenario: No processData by default

- **WHEN** the device builds `data.list` for `command.video_list_response`
- **THEN** the payload MUST NOT include a `processData` / `process_data` field unless a superseding project requirement explicitly adds it

#### Scenario: Internal storage fields not exposed

- **WHEN** the device serializes each element of `data.list` for `command.video_list_response`
- **THEN** the object MUST NOT include the local database row identifier or local filesystem path fields (for example `id`, `video_path`)
