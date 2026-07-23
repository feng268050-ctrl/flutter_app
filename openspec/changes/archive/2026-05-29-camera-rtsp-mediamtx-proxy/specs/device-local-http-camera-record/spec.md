## Purpose

Define **`POST /v1/camera/record`** on the embedded LAN HTTP server: remote start/stop of **PR0 process-video recording** with the same preconditions and encoder path as Fast / Engineer Mode `CameraController`, optional UI sync when the camera float is visible, and coexistence with the **MediaMTX RTSP relay** for LAN preview.

## MODIFIED Requirements

### Requirement: Camera record control HTTP endpoint

The system SHALL expose **`POST /v1/camera/record`** on the embedded local HTTP server (`0.0.0.0:8080`). The request SHALL have **`Content-Type: application/json`** and body **`{ "switch": "on" | "off" }`** where **`switch`** is a lowercase string enum. The response SHALL use the standard **`ApiResult`** JSON envelope. On logical success, **`data`** SHALL be an object **`{ "switch": "on" | "off" }`** describing the **effective** recording state after the operation.

#### Scenario: Start recording via HTTP

- **WHEN** a client sends `POST /v1/camera/record` with body `{ "switch": "on" }` while preflight checks pass and recording is not active
- **THEN** the response status MUST be 200, `success` MUST be true, `data.switch` MUST be `"on"`, and PR0 recording via `EasyPlayerClientManger` MUST begin using the same rules as `CameraController` in Fast / Engineer mode, ingesting from the MediaMTX relay at `rtsp://127.0.0.1:8554/camera/pr0`

#### Scenario: Stop recording via HTTP

- **WHEN** a client sends `POST /v1/camera/record` with body `{ "switch": "off" }` while recording is active
- **THEN** the response status MUST be 200, `success` MUST be true, `data.switch` MUST be `"off"`, and recording MUST stop through the same stop path as the on-screen record button (including save pipeline when applicable)

#### Scenario: Invalid switch value

- **WHEN** a client sends `POST /v1/camera/record` with a body where `switch` is missing, not a string, or not exactly `"on"` or `"off"`
- **THEN** the response MUST be `ApiResult` failure with a diagnosable error code (for example `invalid_switch`) and MUST NOT start or stop recording

#### Scenario: Wrong HTTP method

- **WHEN** a client sends `GET`, `PUT`, or `DELETE` to `/v1/camera/record`
- **THEN** the server MUST NOT return a successful record-control `ApiResult` for that request

### Requirement: Coexistence with camera live HTTP and PR0 recording

The system SHALL ensure `POST /v1/camera/record` does not break PR0 live viewing. HTTP live bridging is removed; LAN viewers and in-app recording MUST both consume **`camera/pr0`** on MediaMTX so only MediaMTX holds the upstream PR0 session to the camera. Starting record via HTTP while LAN RTSP viewers are connected MUST remain supported without opening a direct `RECORDING_RTSP_URL` session from the app.

#### Scenario: Live viewers during HTTP record

- **WHEN** one or more clients read `rtsp://<device-lan-ip>:8554/camera/pr0` and another client starts recording via `POST /v1/camera/record` with `{ "switch": "on" }`
- **THEN** relay viewers MUST continue to receive video, recording MUST start via `rtsp://127.0.0.1:8554/camera/pr0`, and the app MUST NOT open a second upstream RTSP session to the camera

### Requirement: Idempotent record control

The system SHALL treat duplicate record-control requests idempotently:

- **WHEN** `POST /v1/camera/record` with `{ "switch": "on" }` is called while recording is already active
- **THEN** the response MUST be `ApiResult` success with `data.switch` equal to `"on"` and the system MUST NOT start a second PR0 record session

- **WHEN** `POST /v1/camera/record` with `{ "switch": "off" }` is called while recording is not active
- **THEN** the response MUST be `ApiResult` success with `data.switch` equal to `"off"` and the system MUST NOT invoke stop on an idle recorder

#### Scenario: Duplicate start

- **WHEN** recording is already active and the client posts `{ "switch": "on" }` again
- **THEN** `data.switch` MUST remain `"on"` and only one PR0 record session MUST exist

#### Scenario: Duplicate stop

- **WHEN** recording is not active and the client posts `{ "switch": "off" }`
- **THEN** `data.switch` MUST be `"off"` without error side effects
