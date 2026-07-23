## ADDED Requirements

### Requirement: Camera record control HTTP endpoint

The system SHALL expose **`POST /v1/camera/record`** on the embedded local HTTP server (`0.0.0.0:8080`). The request SHALL have **`Content-Type: application/json`** and body **`{ "switch": "on" | "off" }`** where **`switch`** is a lowercase string enum. The response SHALL use the standard **`ApiResult`** JSON envelope. On logical success, **`data`** SHALL be an object **`{ "switch": "on" | "off" }`** describing the **effective** recording state after the operation.

#### Scenario: Start recording via HTTP

- **WHEN** a client sends `POST /v1/camera/record` with body `{ "switch": "on" }` while preflight checks pass and recording is not active
- **THEN** the response status MUST be 200, `success` MUST be true, `data.switch` MUST be `"on"`, and PR0 recording via `EasyPlayerClientManger` MUST begin using the same rules as `CameraController` in Fast / Engineer mode

#### Scenario: Stop recording via HTTP

- **WHEN** a client sends `POST /v1/camera/record` with body `{ "switch": "off" }` while recording is active
- **THEN** the response status MUST be 200, `success` MUST be true, `data.switch` MUST be `"off"`, and recording MUST stop through the same stop path as the on-screen record button (including save pipeline when applicable)

#### Scenario: Invalid switch value

- **WHEN** a client sends `POST /v1/camera/record` with a body where `switch` is missing, not a string, or not exactly `"on"` or `"off"`
- **THEN** the response MUST be `ApiResult` failure with a diagnosable error code (for example `invalid_switch`) and MUST NOT start or stop recording

#### Scenario: Wrong HTTP method

- **WHEN** a client sends `GET`, `PUT`, or `DELETE` to `/v1/camera/record`
- **THEN** the server MUST NOT return a successful record-control `ApiResult` for that request

### Requirement: Shared recording preconditions with Fast and Engineer mode

Starting recording via **`POST /v1/camera/record`** with **`switch: "on"`** SHALL apply the **same preconditions** as `CameraController.checkAndStartRecord()`:

- `EasyPlayerClientManger.getInstance().isRecorderReady()` MUST be true; otherwise the operation MUST fail without starting record.
- When YNH local storage info is available, free space on **`TYPE_LOCAL_STORAGE`** MUST be at least **`CameraConfig.MAX_VIDEO_SIZE`** (same byte comparison as UI); otherwise the operation MUST fail without starting record.
- `CameraUtils.checkCamera` MUST succeed before record starts; on failure the operation MUST fail without starting record.
- Before start, the system SHALL invoke **`CameraRemote.updateCameraTime`** on a background executor, matching UI behavior.

Stopping via **`switch: "off"`** SHALL end the active record session the same way as `CameraController.stopRecord()` (timer end, `EasyPlayerClientManger.stop()`, duration UI reset).

#### Scenario: Camera not ready

- **WHEN** `POST /v1/camera/record` with `{ "switch": "on" }` is called and `isRecorderReady()` is false
- **THEN** the response MUST be `ApiResult` failure (for example `camera_not_ready`) and recording MUST NOT start

#### Scenario: Insufficient storage

- **WHEN** `POST /v1/camera/record` with `{ "switch": "on" }` is called, YNH storage info is available, and local free space is below `CameraConfig.MAX_VIDEO_SIZE`
- **THEN** the response MUST be `ApiResult` failure (for example `insufficient_storage`) and recording MUST NOT start

#### Scenario: Camera check fails

- **WHEN** `POST /v1/camera/record` with `{ "switch": "on" }` is called and `CameraUtils.checkCamera` reports failure
- **THEN** the response MUST be `ApiResult` failure (for example `camera_unavailable`) and recording MUST NOT start

### Requirement: Idempotent record control

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

### Requirement: UI synchronization when Fast or Engineer camera control is visible

When **Fast Mode** or **Engineer Mode** has an attached visible **`CameraController`** registered for remote sync, a successful HTTP transition to **`on`** SHALL set the same view-bound recording state as a user tap (record flag true, timer animation running, duration label updating). A successful HTTP transition to **`off`** SHALL stop the timer animation and reset the record button state like a user stop.

#### Scenario: HTTP start while Quick Mode camera float is shown

- **WHEN** Quick Mode displays the camera float with `CameraController` attached and the client posts `{ "switch": "on" }` successfully
- **THEN** the record button visual state and timer animation MUST match an on-screen start initiated by the operator

#### Scenario: HTTP stop while Engineer Mode camera float is shown

- **WHEN** Engineer Mode displays the camera float with `CameraController` attached, recording is active, and the client posts `{ "switch": "off" }` successfully
- **THEN** the record button and timer UI MUST reflect stopped state consistent with tapping stop

### Requirement: Process parameters on save

When recording stops, process parameters attached to the saved video row SHALL be resolved using the same rules as `CameraController` (listener snapshot at start, fallback to temp snapshot if process type changed). When an active `CameraController` with `CameraControllerListener` is registered, that listener MUST supply parameters. When no listener is available, save MAY proceed with null process parameters JSON, matching current UI behavior when parameters are unavailable.

#### Scenario: Save uses listener when float is active

- **WHEN** recording started via HTTP while Engineer Mode float is visible and stops via HTTP or UI
- **THEN** the inserted `t_params_process_video` row MUST use process parameters from the same listener used for manual recording in that mode

### Requirement: Coexistence with camera live HTTP and PR0 recording

`POST /v1/camera/record` MUST NOT break **`GET /v1/camera/live`** semantics. While PR0 recording is active, live HTTP bridging SHALL follow existing coexistence rules in **`device-local-http-camera-live`** (shared or logged duplicate RTSP as today). Starting record via HTTP while live viewers are connected MUST remain supported to the same extent as UI-initiated recording.

#### Scenario: Live viewers during HTTP record

- **WHEN** one or more clients hold `GET /v1/camera/live` open and another client starts recording via `POST /v1/camera/record` with `{ "switch": "on" }`
- **THEN** live connections MUST remain valid per existing live publisher behavior and recording MUST start without requiring clients to disconnect

### Requirement: Off-main-thread record handler work

Camera checks, `CameraRemote.updateCameraTime`, and `EasyPlayerClientManger` start/stop invoked by the HTTP route SHALL NOT run on the Android main thread. JSON parsing MAY occur on the HTTP thread; blocking camera I/O and recorder control SHALL use the same background executor pattern as other local HTTP handlers.

#### Scenario: HTTP record does not block UI thread

- **WHEN** `POST /v1/camera/record` is invoked
- **THEN** `CameraUtils.checkCamera` and recorder start/stop MUST complete off the main thread
