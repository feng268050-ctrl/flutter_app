## ADDED Requirements

### Requirement: Local HTTP server bind and lifecycle

The system SHALL run an embedded HTTP server bound to `0.0.0.0:5580` while the application process is active and the local API component is enabled. The server SHALL start from application scope after first frame and SHALL stop on application termination without crashing if the port is unavailable (MUST log the failure). Port `8080` MUST NOT be used for new LAN integrations.

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

JSON API routes on `:5580` SHALL return an `ApiResult` object with `success`, `code`, `message`, and `data` fields. Logical success MUST set `success: true`.

#### Scenario: Successful JSON route uses ApiResult

- **WHEN** a client calls an implemented JSON success route on `:5580`
- **THEN** the body MUST be `ApiResult` with `success` true

### Requirement: Process videos LAN API

When local process-video storage is available, the system SHALL expose list/read/stream/delete/upload routes compatible with lws-ui `/v1/videos` (pagination and filters as backends allow). Row serialization MUST match the WebSocket video list item rules for shared fields.

#### Scenario: Default video list page

- **WHEN** a client calls `GET /v1/videos` without query parameters and videos backend is enabled
- **THEN** the response MUST be `ApiResult` success with a `data.list` array and `data.total` count

### Requirement: Process library LAN API

When local process-library storage is available, the system SHALL expose list/CRUD routes compatible with lws-ui `/v1/process-library` and `/v1/process-parameters/*`, writing through the shared importer/repository rules.

#### Scenario: Library list returns ApiResult

- **WHEN** a client calls `GET /v1/process-library` with a valid `processType` and the library backend is enabled
- **THEN** the response MUST be `ApiResult` success with library data

### Requirement: Monitor and camera LAN routes as backends allow

The system SHALL expose monitor SSE and camera control routes (`/v1/monitor/stat`, `/v1/monitor/alerts`, `/v1/camera/ai`, `/v1/camera/record`, `/v1/camera/show-overlay`) when the corresponding App backends exist. Unimplemented routes MUST return a structured failure rather than hanging.

#### Scenario: Unimplemented route fails structured

- **WHEN** a client calls a documented camera/monitor route that is not yet wired
- **THEN** the server MUST return an HTTP error or `ApiResult` failure
- **AND** MUST NOT leave the connection open indefinitely without response

### Requirement: Remote assist endpoint maps to LAN SSH debug

`POST /v1/adb` SHALL either enable the product LAN SSH debug capability (Linux equivalent of Android network ADB) or return a structured not-supported failure. It MUST NOT claim Android ADB port `5555` success on Linux.

#### Scenario: Assist enable uses SSH debug semantics

- **WHEN** a client posts `POST /v1/adb` and SSH-debug mapping is enabled
- **THEN** the system MUST attempt to enable LAN SSH debug
- **AND** MUST NOT report success for Android ADB `:5555` listening
