## ADDED Requirements

### Requirement: Local HTTP server bind and lifecycle

The system SHALL run an embedded HTTP server bound to **`0.0.0.0:8080`** while the application process is active and the server component is enabled. The server SHALL listen on all interfaces so LAN clients can reach the device IP. The system SHALL start the server from application scope and SHALL stop it on application termination or explicit shutdown without crashing the process if the port is unavailable (SHALL log the failure).

#### Scenario: Server accepts LAN connections

- **WHEN** the device has a LAN IP and the local HTTP server has started successfully
- **THEN** a client MAY connect to `http://<device-lan-ip>:8080` and receive HTTP responses from the device

#### Scenario: Bind failure is non-fatal

- **WHEN** port 8080 cannot be bound (for example already in use)
- **THEN** the application MUST continue running and MUST emit a diagnosable error log

### Requirement: LaserCyber health probe endpoint

The system SHALL expose **`GET /lasercyber`**. On success the system SHALL respond with HTTP status **200** and response body plain text **`Hello LaserCyber`** with a text-compatible `Content-Type`. This endpoint SHALL NOT wrap the body in `ApiResult`.

#### Scenario: Mobile app probe succeeds

- **WHEN** a client sends `GET /lasercyber` to the device local server
- **THEN** the response status MUST be 200 and the body MUST be exactly `Hello LaserCyber`

### Requirement: Video list HTTP endpoint

The system SHALL expose **`GET /v1/videos`**. The system SHALL accept optional query parameters:

- `page` (1-based, default **1**)
- `pageSize` (default **10**, maximum **100**)
- `processType` (optional integer; filters the `processType` column when present)
- `startDate` (optional long, epoch milliseconds; inclusive lower bound on `createTime`)
- `endDate` (optional long, epoch milliseconds; inclusive upper bound on `createTime`)

The system SHALL apply the same row visibility rule as `device-ws-video-list-command` (**`uploadStatus != 0`**). The system SHALL return a JSON body in the standard **`ApiResult`** shape where logical success uses **`success: true`**, and **`data`** is an object with:

- `list`: array of video row objects
- `total`: numeric count of all rows matching the filter (not only the current page)

Each element of `list` SHALL match the serialization rules for `command.video_list_response` list items (camelCase fields, `processParameters` object or null, no local row `id` or `videoPath`).

#### Scenario: Default pagination

- **WHEN** a client calls `GET /v1/videos` without query parameters
- **THEN** the response MUST be `ApiResult` success with `data.list` at most 10 items and `data.total` equal to the filtered row count

#### Scenario: Filter by process type and date range

- **WHEN** a client calls `GET /v1/videos?processType=1&startDate=1000&endDate=2000`
- **THEN** every item in `data.list` MUST have `processType` equal to `1` and `createTime` between 1000 and 2000 inclusive, and `data.total` MUST count only matching rows

### Requirement: Single video metadata HTTP endpoint

The system SHALL expose **`GET /v1/videos/:video_id`** where `:video_id` is the business UUID stored in `ProcessParamsVideo.videoId`. On success the system SHALL return **`ApiResult`** with `data` set to a single list-item-shaped object (same fields as `data.list[]` for the list command). When no row exists for that `video_id`, the system SHALL return logical failure with an appropriate `message` (for example not found).

#### Scenario: Known video id

- **WHEN** a row exists with `videoId` `abc-123`
- **THEN** `GET /v1/videos/abc-123` MUST return success `ApiResult` whose `data.videoId` is `abc-123`

#### Scenario: Unknown video id

- **WHEN** no row exists for `videoId` `missing`
- **THEN** `GET /v1/videos/missing` MUST return `ApiResult` with `success` false

### Requirement: Video stream HTTP endpoint

The system SHALL expose **`GET /v1/videos/:video_id/stream`**. The system SHALL resolve the row by business `videoId` and SHALL stream bytes from the local `videoPath` file when present. The system SHALL use a video-compatible `Content-Type` (for example `video/mp4`). When the row or file is missing, the system SHALL respond with HTTP **404** or an `ApiResult` failure envelope consistent with other video routes.

#### Scenario: Stream local file

- **WHEN** `videoId` maps to a row with a readable `videoPath`
- **THEN** `GET /v1/videos/<videoId>/stream` MUST return HTTP 200 with a body containing the file bytes

#### Scenario: Missing file

- **WHEN** the row exists but `videoPath` is null or the file does not exist
- **THEN** the stream endpoint MUST NOT return success with an empty body posing as video

### Requirement: Video delete HTTP endpoint

The system SHALL expose **`DELETE /v1/videos/:video_id`**. The system SHALL delete the local video file when `videoPath` points to an existing file, then SHALL delete the database row for that business `videoId`. The system SHALL return **`ApiResult`** indicating success or failure.

#### Scenario: Successful delete

- **WHEN** `DELETE /v1/videos/<videoId>` is called for an existing row and file deletion succeeds
- **THEN** the response MUST be `ApiResult` success and subsequent `GET /v1/videos/<videoId>` MUST fail as not found

### Requirement: Off-main-thread local HTTP handlers

The system SHALL NOT perform Room/SQLite or filesystem delete work on the Android main thread for local HTTP video routes. Request handling that touches the database or large file I/O SHALL run on a background executor consistent with WebSocket command handlers.

#### Scenario: List request does not block UI thread

- **WHEN** `GET /v1/videos` is invoked
- **THEN** database queries MUST complete off the main thread
