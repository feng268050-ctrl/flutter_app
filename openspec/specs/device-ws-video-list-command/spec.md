## Purpose

Define device-side behavior for listing persisted process videos over the WebSocket command pair `command.video_list_request` / `command.video_list_response`, including pagination and the **`uploadStatus != 0`** visibility rule.

## Requirements

### Requirement: Filter process video list by non-zero sync status

The system SHALL expose a read path for process video rows used by the WebSocket list command that includes **only** rows where `uploadStatus` is **not** equal to `0`. The system SHALL compute **`total`** as the count of rows matching that filter and SHALL compute each **`list`** page from the same filter.

#### Scenario: Excluded uninitialized row

- **WHEN** a row exists with `uploadStatus` equal to `0`
- **THEN** that row MUST NOT appear in `data.list` for `command.video_list_response` and MUST NOT be counted in `data.total` for that command

#### Scenario: Included progressed row

- **WHEN** a row exists with `uploadStatus` not equal to `0`
- **THEN** that row MUST be eligible for `data.list` and MUST be counted in `data.total`

### Requirement: Paginated ordering for the list command

The system SHALL return list rows ordered by **`createTime`**. Pagination SHALL use **1-based** `page` and **`page_size`** from the request payload. The system SHALL apply **`LIMIT page_size OFFSET (page - 1) * page_size`** semantics (or equivalent) against the filtered row set.

The inbound `payload` MAY include optional string field **`order`** with value **`date_asc`** (oldest `createTime` first) or **`date_desc`** (newest first). When **`order`** is omitted or not a recognized value, the system SHALL order by **`createTime` descending** (same as **`date_desc`**).

#### Scenario: Default newest-first order

- **WHEN** `command.video_list_request` omits `order` or sets `order` to `date_desc`
- **THEN** `data.list` MUST be ordered by `createTime` descending

#### Scenario: Oldest-first order

- **WHEN** `command.video_list_request` sets `order` to `date_asc`
- **THEN** `data.list` MUST be ordered by `createTime` ascending

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

The system SHALL include in each `data.list` element a stable set of fields sufficient to identify and display the video metadata **without** requiring a second round trip for the same row. At minimum the object SHOULD include: `videoId`, `createTime`, `duration`, `fileSize`, `resolution`, `processType`, `materialType`, `uploadStatus`, `uploadProgress`, `coverUrl`, and `videoUrl` when applicable. JSON property names in each `data.list` element SHALL use **camelCase** aligned with `ProcessParamsVideo` / `ProcessParamsVideoVo` field names where those fields exist (for example `videoId`, `createTime`, `uploadStatus`). The system SHALL include **`processParameters`** in each list element as a **JSON object** (parsed from the persisted process-parameters JSON string) or JSON **`null`** when absent, blank, or unparseable. The system SHALL NOT include a string field named `processData` or `process_data` in list elements for this purpose.

#### Scenario: Valid persisted JSON becomes an object

- **WHEN** a list row’s persisted process-parameters string contains valid JSON that parses to a JSON object
- **THEN** the corresponding `data.list` element MUST include `processParameters` as that JSON object and MUST NOT include `processData` / `process_data`

#### Scenario: Absent or invalid JSON becomes null

- **WHEN** the persisted process-parameters string is null, empty, whitespace-only, or does not parse to a JSON object
- **THEN** the corresponding `data.list` element MUST include `processParameters` with JSON value `null`

#### Scenario: Internal storage fields not exposed

- **WHEN** the device serializes each element of `data.list` for `command.video_list_response`
- **THEN** the object MUST NOT include the local database row identifier or local filesystem path fields (for example `id`, `videoPath` / `video_path`)

### Requirement: List element processParameters JSON uses ProcessParametersData canonical keys

When the system includes `processParameters` in each `command.video_list_response` `data.list` element as a parsed JSON object (per existing list minimization rules), that object SHALL follow the same property naming as `ProcessParametersData` after rename: **`name`**, **`materialType`**, and **`materialName`** for the former `paramsName`, `materials`, and `materialsName` semantics. List serialization MUST NOT reintroduce legacy keys `paramsName`, `materials`, or `materialsName` when emitting parsed objects.

#### Scenario: Parsed list processParameters matches canonical keys

- **WHEN** a list row’s persisted process-parameters string parses to a JSON object that was stored under the renamed model
- **THEN** the `data.list` element’s `processParameters` object MUST expose material and naming fields only under `name`, `materialType`, and `materialName` when those members are present

#### Scenario: Legacy-key JSON is not rewritten by the list path alone

- **WHEN** a row still contains persisted JSON using legacy property names only
- **THEN** parsing MAY fail or yield null `processParameters` per existing unparseable rules; the list command SHALL NOT be required to transform legacy keys (optional separate migration is out of scope for this requirement)

### Requirement: Optional list filters for process type, material type, and date range

The system SHALL accept optional filter fields on inbound `command.video_list_request` **`payload`**:

- **`process_type`** (optional integer): when present, restrict rows to those whose `processType` equals this value
- **`material_type`** (optional integer): when present, restrict rows to those whose `materialType` equals this value
- **`start_date`** (optional string, `yyyy-MM-dd`): when present, include only rows whose `createTime` falls on or after the start of that calendar day (device system default time zone)
- **`end_date`** (optional string, `yyyy-MM-dd`): when present, include only rows whose `createTime` falls on or before the end of that calendar day (device system default time zone)
- **`order`** (optional string, `date_asc` | `date_desc`): when present, controls `createTime` sort direction per the paginated ordering requirement; omitted or unrecognized values default to **`date_desc`**
- **`upload_status`** (optional integer): when present, restrict rows to those whose `uploadStatus` equals this value (`0` NotInitiated, `1` CoverUploaded, `2` VideoUploading, `3` VideoUploaded per `VideoUploadStatus`)

When **`upload_status`** is omitted, the system SHALL apply the existing **`uploadStatus != 0`** visibility rule. When **`upload_status`** is present, the system SHALL match rows with that exact `uploadStatus` (including `0`) and SHALL NOT apply the default non-zero rule for that request.

The system SHALL apply these filters when computing **`data.list`** and **`data.total`**. The same filter semantics SHALL be used by the local HTTP **`GET /v1/videos`** endpoint (`processType`, `materialType`, `startDate`, `endDate` query parameters as **`yyyy-MM-dd`** strings; `order` query parameter with the same `date_asc` | `date_desc` values; `uploadStatus` query parameter with the same semantics as **`upload_status`**).

#### Scenario: Filtered total matches list

- **WHEN** `command.video_list_request` includes `process_type` and date bounds and matching rows exist
- **THEN** `data.total` MUST equal the count of rows matching all filters, and each `data.list` element MUST satisfy every active filter

#### Scenario: Omitted filters are open-ended

- **WHEN** `command.video_list_request` omits `process_type`, `material_type`, `start_date`, `end_date`, and `upload_status`
- **THEN** list behavior MUST match the pre-filter implementation (pagination and `uploadStatus != 0` only)

#### Scenario: Explicit upload status filter

- **WHEN** `command.video_list_request` sets `upload_status` to `3` and rows exist with `uploadStatus` equal to `3`
- **THEN** `data.list` MUST include only rows with `uploadStatus` equal to `3` and `data.total` MUST count only those rows

#### Scenario: Not-initiated rows via upload status filter

- **WHEN** `command.video_list_request` sets `upload_status` to `0` and rows exist with `uploadStatus` equal to `0`
- **THEN** those rows MUST appear in `data.list` and MUST be counted in `data.total`

### Requirement: List response supports client end-of-list pagination

The `command.video_list_response` payload SHALL provide enough pagination information for Monitor -> Videos to decide whether another page is available. The response `data.total` SHALL represent the total count for the active list query, and `data.list` SHALL represent only the requested page window.

#### Scenario: Client computes more pages from total

- **WHEN** Monitor -> Videos receives `command.video_list_response` for a paginated request
- **THEN** the client MUST be able to compare the number of loaded rows with `data.total`
- **AND** the client MUST be able to stop requesting additional pages when the loaded row count is greater than or equal to `data.total`

#### Scenario: Next page appends only requested window

- **WHEN** Monitor -> Videos requests a later page using the same list query
- **THEN** `data.list` MUST contain only rows for that requested page window
- **AND** `data.total` MUST remain the total count for the active query, not the count of the returned page

