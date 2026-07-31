# device-local-http-api Specification

## Purpose

Embedded LAN HTTP API on `0.0.0.0:5580` for LaserCyber mobile and local tooling (lws-ui `DeviceLocalHttpServer` parity): health probe, process videos (list/upload/stream/delete/AI), process library/parameters, monitor SSE, camera control, and LAN SSH assist (`POST /v1/adb`). Live camera video remains RTSP on `:8554`, not an HTTP live route.

## Requirements

### Requirement: Local HTTP server bind and lifecycle

The system SHALL run an embedded HTTP server bound to `0.0.0.0:5580` while the application process is active. The server SHALL start from application scope after first frame and SHALL stop on application termination without crashing if the port is unavailable (MUST log the failure). Port `8080` MUST NOT be used for new LAN integrations.

#### Scenario: Server accepts LAN connections

- **WHEN** the device has a LAN IP and the local HTTP server has started successfully
- **THEN** a client MAY connect to `http://<device-lan-ip>:5580` and receive HTTP responses

#### Scenario: Bind failure is non-fatal

- **WHEN** port 5580 cannot be bound
- **THEN** the application MUST continue running
- **AND** MUST emit a diagnosable error log

### Requirement: LaserCyber health probe endpoint

The system SHALL expose `GET /lasercyber`. On success the response status MUST be `200` and the body MUST be exactly plain text `Hello LaserCyber` (not wrapped in `ApiResult`).

#### Scenario: Mobile app probe succeeds

- **WHEN** a client sends `GET /lasercyber` to the device local server
- **THEN** the response status MUST be 200 and the body MUST be exactly `Hello LaserCyber`

### Requirement: ApiResult JSON envelope

JSON API routes on `:5580` SHALL return an `ApiResult` object with `success`, `code`, `message`, and `data` fields. Logical success MUST set `success: true` and typically `code: 0`.

#### Scenario: Successful JSON route uses ApiResult

- **WHEN** a client calls an implemented JSON success route on `:5580`
- **THEN** the body MUST be `ApiResult` with `success` true

### Requirement: Process videos list HTTP endpoint

The system SHALL expose `GET /v1/videos` returning `ApiResult` with `data.list` and `data.total`. Query parameters SHALL include pagination `page` (default 1) and `pageSize` (default 10, max 100), and MAY include `processType`, `materialType`, `startDate`/`endDate` (`yyyy-MM-dd`), `order` (`date_asc`|`date_desc`), and `uploadStatus`. When `uploadStatus` is omitted, rows with upload status `0` (not initiated) MUST be excluded by default. Each list row SHALL use the business `videoId` and shared LAN video-row fields (`processType`, `materialType`, `fileSize`, `duration`, `createTime`, `resolution`, `uploadStatus`, `uploadProgress`, `coverUrl`, `videoUrl`, `processParameters`).

#### Scenario: Default pagination

- **WHEN** a client calls `GET /v1/videos` without query parameters and the videos backend is enabled
- **THEN** the response MUST be `ApiResult` success with a `data.list` array and `data.total` count

#### Scenario: Filter by process type

- **WHEN** a client calls `GET /v1/videos?processType=<n>`
- **THEN** every returned row MUST have that `processType`

### Requirement: Process video upload HTTP endpoint

The system SHALL expose `POST /v1/videos` as `multipart/form-data` with required parts `file`, `processType`, and `materialType`, and optional `processParameters` (JSON text). On success, `data` MUST be one video row. Failures MUST use structured messages such as `invalid_multipart`, `missing_file`, `invalid_processType`, `invalid_materialType`, `empty_file`, `invalid_video_duration`, `invalid_video_resolution`.

#### Scenario: Missing file is rejected

- **WHEN** a client posts multipart without a `file` part
- **THEN** the response MUST be `ApiResult` failure with message `missing_file`

### Requirement: Single video metadata, stream, and delete

Path segments after `/v1/videos/` SHALL be the business **`videoId`** (not a SQLite row id).

- `GET /v1/videos/:videoId` → full video row or `video_not_found`
- `DELETE /v1/videos/:videoId` → success or `video_not_found`
- `GET /v1/videos/:videoId/stream` → `video/mp4` bytes (MAY honor `Range`); missing file → `file_missing`

#### Scenario: Known video id

- **WHEN** a client GETs `/v1/videos/<videoId>` for an indexed video
- **THEN** the response MUST be `ApiResult` success whose `data.videoId` equals that id

### Requirement: Process video AI routes

`GET /v1/videos/:videoId/ai` SHALL stream AI SSE when a process-video AI backend is available. When unavailable, the response MUST be HTTP `503` with plain text `process_video_ai_unavailable` (not `ApiResult`). Unknown video → `video_not_found`. `GET /v1/videos/:videoId/ai/replay` SHALL return replay JSON when cached; otherwise `ai_replay_not_found`.

#### Scenario: AI unavailable plain text

- **WHEN** a known video exists and process-video AI is not available
- **AND** a client calls `GET /v1/videos/:videoId/ai`
- **THEN** the status MUST be 503 and the body MUST be exactly `process_video_ai_unavailable`

### Requirement: Process library LAN API

`GET /v1/process-library` SHALL require query `processType`; missing → `missing_process_type`. Success `data` MUST be an array of full engineer/process preset maps (including parameters and `dataType`).

`POST /v1/process-parameters` SHALL create a custom engineer preset (`dataType` 2) and return `data: { id }`.

`GET|PUT|DELETE /v1/process-parameters/:id` and `POST /v1/process-parameters/:id/set-default` SHALL operate on uuid or numeric id. Builtin presets MUST reject mutating deletes with a structured failure (for example `cannot_delete_non_engineer` / `builtin_readonly`). Set-default SHALL apply the preset through the shared library apply path; success `data` MAY be null.

#### Scenario: Library list requires processType

- **WHEN** a client calls `GET /v1/process-library` without `processType`
- **THEN** the response MUST be `ApiResult` failure with message `missing_process_type`

### Requirement: Monitor SSE HTTP endpoints

The system SHALL expose:

- `GET /v1/monitor/stat` as `text/event-stream` with events `stat` and `heartbeat`. The `stat` data object MUST include `deviceStatus`, `deviceData`, and `processParameters` (same family as cloud `command.stat_response` sub-objects). Absent halves MUST be JSON `null` (not empty objects solely to fill keys).
- `GET /v1/monitor/alerts` as `text/event-stream` with events `list`, `new`, `clear`, and `heartbeat`. The `list` payload MUST be a WarnTable-shaped JSON array (newest-first, at most 10 rows). `new` MUST carry a single WarnTable object with a non-null `id`. `clear` data MUST be `{}`.

`heartbeat` data MUST be `{"ok":true}` and MUST repeat at least every 15 seconds while the connection is open.

**Push model (intentional divergence from lws-ui `MonitorStatSseHub` 100 ms MemoryCache sampler):** subsequent `stat` events MUST be driven by HAL continuous-poll attribute/health changes (and process-parameter snapshot updates) via App `watchAttributes` / LiveCache. The App MUST NOT implement a second Modbus poll loop or a fixed 100 ms empty sample timer solely for Monitor SSE. Field and event-name contracts remain aligned with lws-ui `network-api-reference.md`.

#### Scenario: Monitor stat route on device LAN

- **WHEN** a client opens `GET /v1/monitor/stat`
- **THEN** the response Content-Type MUST be an event-stream
- **AND** an initial `stat` event MUST be sent without waiting for cloud connectivity

#### Scenario: Monitor alerts emit new and clear

- **WHEN** a client is subscribed to `GET /v1/monitor/alerts`
- **AND** a new alarm log row is inserted with an id
- **THEN** the stream MUST emit `event: new` with that WarnTable object
- **WHEN** alarm history is cleared
- **THEN** the stream MUST emit `event: clear` with data `{}`

### Requirement: Monitor / cloud `deviceData` temperature wire scale

Packed `deviceData` for LAN Monitor SSE and cloud remote snapshot MUST use lws-ui Gson `DeviceData` field names and **register-scale** temperature ints (`gunMotorTempRaw`, `gunDriverBoardTempRaw`, `protectionBoardTempRaw`, `collimatorTempRaw`): signed values scaled ×10 in Celsius (e.g. `419` → 41.9 °C). External clients (including the phone App) divide by 10 for display. HAL catalog decode applies `scale: 0.1`, so App packing MUST re-encode engineering °C back to ×10 raw (unavailable / disconnected scaled sentinel ≤ −99.9 °C MUST become wire `−9990` or another value `≤ −999` accepted by lws-ui / mobile). The packer MUST NOT emit engineering °C (or truncated °C ints such as `42`) under `*TempRaw` keys. Attributes absent from the live attr map MUST be **omitted** from the packed object (MUST NOT send JSON `null` for those keys solely because the attr was never seeded — phone clients shallow-merge `stat` patches and a null field would wipe a prior reading).

#### Scenario: TempRaw matches lws-ui register scale

- **WHEN** HAL `telemetry.gun_motor_temp` is engineering `41.9` (°C after scale 0.1)
- **AND** the App packs `deviceData` for Monitor SSE or cloud snapshot
- **THEN** `gunMotorTempRaw` MUST be `419` (MUST NOT be `41` or `42`)

#### Scenario: Unavailable temp on the wire

- **WHEN** HAL reports a gun temperature scaled sentinel ≤ −99.9
- **AND** the App packs `deviceData`
- **THEN** the corresponding `*TempRaw` MUST be `≤ −999` (typically `−9990`)

### Requirement: Camera LAN control routes

- `POST /v1/camera/record` with JSON `{ "switch": "on"|"off" }` → `ApiResult` with `data.switch`; invalid → `invalid_switch`; conflict → `recording_in_progress`.
- `POST /v1/camera/show-overlay` with `{ enable: 0|1, positionx?, positiony? }` → `ApiResult` on success. When the Linux IPC overlay write path is unavailable, the server MUST return structured failure (for example `show_overlay_unavailable`) rather than an indefinite hang or blank 501.
- `GET /v1/camera/ai` SHALL return Server-Sent Events per capability **`device-local-http-ai-inference-sse`** when the App AI daemon is ready; otherwise HTTP `503` plain text `camera_ai_unavailable` or `camera_unavailable`. On success the route MUST NOT return video elementary-stream bytes and MUST NOT wrap frames in `ApiResult`.

Live preview remains `rtsp://<lan-ip>:8554/camera/pr0` (not `GET /v1/camera/live`).

#### Scenario: Record switch on LAN

- **WHEN** a client posts `{ "switch": "on" }` to `/v1/camera/record` and recording can start
- **THEN** the response MUST be `ApiResult` success with `data.switch` equal to `on`

#### Scenario: Camera AI unavailable

- **WHEN** camera AI is not available
- **AND** a client calls `GET /v1/camera/ai`
- **THEN** the status MUST be 503 and the body MUST be plain text naming unavailability

#### Scenario: Camera AI SSE when available

- **WHEN** the AI daemon is ready
- **AND** a client calls `GET /v1/camera/ai`
- **THEN** the status MUST be 200
- **AND** `Content-Type` MUST be `text/event-stream; charset=utf-8`
- **AND** the first SSE event MUST be `idle`

### Requirement: Remote assist endpoint maps to LAN SSH debug

`POST /v1/adb` SHALL enable the product LAN SSH debug capability (Linux equivalent of Android network ADB) or return structured failure `adb_enable_failed`. On logical success, **`data` MUST be `null`**. It MUST NOT claim Android ADB port `5555` success on Linux.

#### Scenario: Assist enable success shape

- **WHEN** a client posts `POST /v1/adb` and SSH-debug enable succeeds
- **THEN** the response MUST be `ApiResult` with `success: true` and `data: null`
