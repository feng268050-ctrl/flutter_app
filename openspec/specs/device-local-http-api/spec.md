## Purpose

Define the embedded **LAN HTTP API** on **`0.0.0.0:5580`** for mobile and direct device access (port **8080** is **deprecated**): health probe, process video list/read/stream/delete/upload, camera AI stream (`GET /v1/camera/ai`), camera record control (`POST /v1/camera/record`), `ApiResult` JSON envelopes, and alignment with WebSocket video row serialization and cover-upload pipeline. Camera main-stream LAN preview is via MediaMTX RTSP relay (see **`mediamtx-runtime-lifecycle`**), not an HTTP live route.
## Requirements
### Requirement: Local HTTP server bind and lifecycle

The system SHALL run an embedded HTTP server bound to **`0.0.0.0:5580`** while the application process is active and the server component is enabled. Port **8080** is **deprecated** and MUST NOT be used for new integrations. The server SHALL listen on all interfaces so LAN clients can reach the device IP. The system SHALL start the server from application scope and SHALL stop it on application termination or explicit shutdown without crashing the process if the port is unavailable (SHALL log the failure).

#### Scenario: Server accepts LAN connections

- **WHEN** the device has a LAN IP and the local HTTP server has started successfully
- **THEN** a client MAY connect to `http://<device-lan-ip>:5580` and receive HTTP responses from the device

#### Scenario: Bind failure is non-fatal

- **WHEN** port 5580 cannot be bound (for example already in use)
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
- `materialType` (optional integer; filters the `materialType` column when present)
- `startDate` (optional string, `yyyy-MM-dd`; inclusive calendar-day lower bound on `createTime`, interpreted in the device system default time zone)
- `endDate` (optional string, `yyyy-MM-dd`; inclusive calendar-day upper bound on `createTime`, interpreted in the device system default time zone)
- `order` (optional string, `date_asc` | `date_desc`; controls `createTime` sort direction; omitted or unrecognized values default to **`date_desc`**)

The system SHALL apply the same row visibility rule as `device-ws-video-list-command` (**`uploadStatus != 0`**). The system SHALL return a JSON body in the standard **`ApiResult`** shape where logical success uses **`success: true`**, and **`data`** is an object with:

- `list`: array of video row objects
- `total`: numeric count of all rows matching the filter (not only the current page)

Each element of `list` SHALL match the serialization rules for `command.video_list_response` list items (camelCase fields, `processParameters` object or null, no local row `id` or `videoPath`).

#### Scenario: Default pagination

- **WHEN** a client calls `GET /v1/videos` without query parameters
- **THEN** the response MUST be `ApiResult` success with `data.list` at most 10 items and `data.total` equal to the filtered row count

#### Scenario: Filter by process type and date range

- **WHEN** a client calls `GET /v1/videos?processType=1&startDate=2026-05-01&endDate=2026-05-18`
- **THEN** every item in `data.list` MUST have `processType` equal to `1` and `createTime` within those inclusive calendar days (device local time zone), and `data.total` MUST count only matching rows

### Requirement: Video upload HTTP endpoint

The system SHALL expose **`POST /v1/videos`** accepting **`multipart/form-data`** with fields:

- **`file`** (required): video binary
- **`processType`** (required integer)
- **`materialType`** (required integer)
- **`processParameters`** (optional JSON text; stored as `processParametersJson`)

The system SHALL NOT accept **`duration`** or **`resolution`** from the client; those SHALL be read from the saved video file (same probe path as local cover extraction: `MediaMetadataRetriever` duration in milliseconds and display-oriented resolution as `width`×`height`, swapping dimensions when rotation is 90° or 270°).

The system SHALL derive **`fileSize`** from the saved file, **`duration`** and **`resolution`** from the file probe, **`createTime`** as current epoch milliseconds, **`videoId`** as a newly generated UUID, **`uploadStatus`** as **`0`** (`NOT_INITIATED`), and **`uploadProgress`** as **`0`**. The system SHALL persist the file under application-accessible storage and insert a `t_params_process_video` row. On success the system SHALL return **`ApiResult`** with **`success: true`** and **`data`** as a list-item-shaped object per `command.video_list_response` rules.

After successful insert, the system SHALL schedule background cover upload (R2 cover pipeline per `device-video-metadata` / `ProcessVideoCoverR2Upload`) so **`uploadStatus`** and **`coverUrl`** may advance without blocking the HTTP response.

#### Scenario: Successful upload returns video metadata

- **WHEN** a client posts valid multipart data with a non-empty `file`
- **THEN** the response MUST be `ApiResult` success whose `data.videoId` is the generated UUID and `data.uploadStatus` is `0`

#### Scenario: Missing file is rejected

- **WHEN** `POST /v1/videos` omits `file` or the file is empty
- **THEN** the response MUST be `ApiResult` failure with an appropriate `message`

#### Scenario: Unprobeable video metadata is rejected

- **WHEN** a client posts a non-empty `file` that is saved but duration or resolution cannot be read from the file
- **THEN** the response MUST be `ApiResult` failure, the saved file MUST be removed, and no database row MUST be inserted

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

### Requirement: Camera AI stream HTTP endpoint

The system SHALL expose **`GET /v1/camera/ai`** on the same embedded local HTTP server and port as other `/v1/*` device routes. This endpoint SHALL return **`text/event-stream`** (SSE) of shared lifecycle and inference JSON events without `ApiResult` wrapping. SSE events SHALL be **`idle`**, **`start`**, **`running`**, **`stop`**, and **`error`**. It SHALL NOT stream H.264 or MPEG-TS video bytes.

Semantics are defined in **`device-local-http-ai-inference-sse`** (shared wire format and payloads) and **`device-local-http-camera-ai`** (live-camera data source and connection-relative `timestampMs`). Camera main-stream video SHALL be consumed from the MediaMTX RTSP relay at **`rtsp://<device-lan-ip>:8554/camera/pr0`** (see **`mediamtx-runtime-lifecycle`**).

#### Scenario: AI route on device LAN

- **WHEN** a client requests `http://<device-lan-ip>:5580/v1/camera/ai`
- **THEN** the request MUST be handled by the local HTTP server component that serves `/v1/videos` and MUST NOT require the cloud Worker base URL
- **AND** `Content-Type` MUST be `text/event-stream; charset=utf-8`
- **AND** the first SSE event on the connection MUST be `idle`

#### Scenario: Video is on RTSP relay not ai route

- **WHEN** a client needs camera main-stream (PR0) video bytes
- **THEN** the client MUST use `rtsp://<device-lan-ip>:8554/camera/pr0`, not `/v1/camera/ai`

### Requirement: Camera record control HTTP endpoint (API surface)

The system SHALL expose **`POST /v1/camera/record`** on the same embedded local HTTP server and port as other `/v1/*` device routes. The endpoint SHALL accept JSON **`{ "switch": "on" | "off" }`** and SHALL return **`ApiResult`** with **`data`** shaped as **`{ "switch": "on" | "off" }`** on success. Recording semantics, preconditions, UI sync, and coexistence with live streaming are defined in capability **`device-local-http-camera-record`**.

#### Scenario: Record route on device LAN

- **WHEN** a client sends `POST http://<device-lan-ip>:5580/v1/camera/record` with `Content-Type: application/json` and body `{ "switch": "on" }`
- **THEN** the request MUST be handled by the local HTTP server component that serves `/v1/videos` and MUST NOT require the cloud Worker base URL

#### Scenario: Successful response shape

- **WHEN** a record start or stop succeeds
- **THEN** the response body MUST be `ApiResult` with `success: true` and `data.switch` equal to the effective `"on"` or `"off"` state

### Requirement: Record start conflict on device LAN API

When **`POST /v1/camera/record`** receives `{ "switch": "on" }` while PR0 recording is already active, the local HTTP server SHALL return an **`ApiResult` failure** documented alongside other `/v1/camera/record` error codes, with **`recording_in_progress`** and user-visible text **`另一个线程正在录制中`** (localized). Successful `data` shape for start/stop remains `{ "switch": "on" | "off" }`.

#### Scenario: Documented conflict response

- **WHEN** a client sends `POST http://<device-lan-ip>:5580/v1/camera/record` with `{ "switch": "on" }` while recording is already active
- **THEN** `docs/network-api-reference.md` MUST list `recording_in_progress` with the Chinese operator message and MUST state that duplicate `on` is no longer idempotent success

### Requirement: Process video AI live stream HTTP endpoint (API surface)

The system SHALL expose **`GET /v1/videos/:video_id/ai`** on the same embedded local HTTP server and port as other `/v1/*` device routes. This endpoint SHALL provide an **SSE inference event stream** tied to **`ProcessVideoAiSession`**, not a chunked composited video body. SSE events SHALL be **`idle`**, **`start`**, **`running`**, **`stop`**, and **`error`** — the same names and JSON shapes as `/v1/camera/ai`.

Semantics are defined in **`device-local-http-ai-inference-sse`** and **`device-local-http-video-ai`** (process-video data source and media-timeline `timestampMs`).

#### Scenario: AI live stream route on device LAN

- **WHEN** a client requests `http://<device-lan-ip>:5580/v1/videos/<video_id>/ai`
- **THEN** the request MUST be handled by the local HTTP server component that serves `/v1/videos` and MUST NOT require the cloud Worker base URL
- **AND** the successful body MUST be SSE, not MP4/H.264
- **AND** the first SSE event on the connection MUST be `idle`

#### Scenario: Distinct from raw stream and camera AI

- **WHEN** a client compares `/v1/videos/<id>/stream`, `/v1/videos/<id>/ai`, and `/v1/camera/ai`
- **THEN** `/stream` MUST serve the raw `videoPath` file bytes
- **AND** both `/v1/camera/ai` and `/v1/videos/<id>/ai` MUST use the same SSE event names and JSON field shapes
- **AND** `/v1/camera/ai` MUST use live-camera inference with connection-relative `timestampMs`
- **AND** `/v1/videos/<id>/ai` MUST serve process-video inference SSE with media-timeline `timestampMs`

### Requirement: Monitor stat SSE HTTP endpoint (API surface)

The system SHALL expose **`GET /v1/monitor/stat`** on the same embedded local HTTP server and port as other `/v1/*` device routes. This endpoint SHALL return **`text/event-stream`** (SSE) of monitor snapshot JSON events without `ApiResult` wrapping. SSE events SHALL be **`stat`** and **`heartbeat`**.

Semantics are defined in capability **`device-local-http-monitor-stat-sse`**. Field meanings for external clients are documented in `openspec/changes/archive/2026-05-29-add-monitor-stat-sse/monitor-field-mapping.md`.

#### Scenario: Monitor stat route on device LAN

- **WHEN** a client requests `http://<device-lan-ip>:5580/v1/monitor/stat`
- **THEN** the request MUST be handled by the local HTTP server component that serves `/v1/videos` and MUST NOT require the cloud Worker base URL
- **AND** `Content-Type` MUST be `text/event-stream; charset=utf-8`
- **AND** the first SSE event on the connection MUST be `heartbeat` or `stat` depending on whether cached monitor data changed since the publisher last emitted

#### Scenario: Payload matches command.stat_response sub-objects

- **WHEN** the device emits a `stat` event
- **THEN** the `data` JSON object MUST contain `deviceStatus`, `deviceData`, and `processParameters` keys
- **AND** their JSON shapes MUST match `command.stat_response` `payload.data.deviceStatus`, `payload.data.deviceData`, and `payload.data.processParameters` for the same app version

### Requirement: Monitor alerts SSE HTTP endpoint (API surface)

The system SHALL expose **`GET /v1/monitor/alerts`** on the same embedded local HTTP server and port as other `/v1/*` device routes. This endpoint SHALL return **`text/event-stream`** (SSE) of monitor alert JSON events without `ApiResult` wrapping. SSE events SHALL be **`list`**, **`new`**, **`clear`**, and **`heartbeat`**.

Semantics are defined in capability **`device-local-http-monitor-alerts-sse`**.

#### Scenario: Monitor alerts route on device LAN

- **WHEN** a client requests `http://<device-lan-ip>:5580/v1/monitor/alerts`
- **THEN** the request MUST be handled by the local HTTP server component that serves `/v1/monitor/stat` and MUST NOT require the cloud Worker base URL
- **AND** `Content-Type` MUST be `text/event-stream; charset=utf-8`
- **AND** the first SSE event on the connection MUST be `event: list`

#### Scenario: Payload matches command.stat_response warns

- **WHEN** the device emits a `list` event
- **THEN** the `data` line MUST be a JSON array whose elements match `command.stat_response` `payload.data.warns` for the same app version at that instant

### Requirement: ADB enable HTTP endpoint (API surface)

The system SHALL expose **`POST /v1/adb`** on the same embedded local HTTP server and port as other `/v1/*` device routes. The endpoint SHALL use the standard **`ApiResult`** JSON envelope. On logical success, **`data`** MUST be **`null`**. Enablement semantics are defined in capability **`device-local-http-adb`**.

#### Scenario: ADB route on device LAN

- **WHEN** a client sends `POST http://<device-lan-ip>:5580/v1/adb`
- **THEN** the request MUST be handled by the local HTTP server component that serves `/v1/videos` and MUST NOT require the cloud Worker base URL
- **AND** on success the response MUST be `ApiResult` with `success: true` and `data: null`

#### Scenario: Documented in network API reference

- **WHEN** a developer reads `docs/network-api-reference.md` for device-local HTTP
- **THEN** the document MUST describe `POST /v1/adb`, the `ApiResult` success shape (`data: null`), failure message (for example `adb_enable_failed`), and a curl example against port **5580**

