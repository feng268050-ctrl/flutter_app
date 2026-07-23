## Purpose

Define **`POST /v1/camera/record`** on the embedded LAN HTTP server: remote start/stop of **PR0 process-video recording** with the same preconditions and encoder path as Fast / Engineer Mode `CameraController`, optional UI sync when the camera float is visible, and coexistence with **`GET /v1/camera/live`**.
## Requirements
### Requirement: Camera record control HTTP endpoint

The system SHALL expose **`POST /v1/camera/record`** on the embedded local HTTP server (`0.0.0.0:5580`; port **8080** deprecated). The request SHALL have **`Content-Type: application/json`** and body **`{ "switch": "on" | "off" }`** where **`switch`** is a lowercase string enum. The response SHALL use the standard **`ApiResult`** JSON envelope. On logical success, **`data`** SHALL be an object **`{ "switch": "on" | "off" }`** describing the **effective** recording state after the operation.

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

### Requirement: Exclusive record start and idempotent stop

The system SHALL treat duplicate **stop** requests idempotently and duplicate **start** requests as **conflicts**:

- **WHEN** `POST /v1/camera/record` with `{ "switch": "on" }` is called while recording is already active (PR0 encoder session and/or visible `CameraController` recording UI state)
- **THEN** the response MUST be `ApiResult` failure with HTTP status **409**, machine-readable code **`recording_in_progress`**, human-readable **`message`** equal to **`另一个线程正在录制中`** (or the active locale translation of that string), `data.switch` reflecting the effective state **`"on"`**, and the system MUST NOT start a second PR0 record session

- **WHEN** `POST /v1/camera/record` with `{ "switch": "off" }` is called while recording is not active
- **THEN** the response MUST be `ApiResult` success with `data.switch` equal to `"off"` and the system MUST NOT invoke stop on an idle recorder

#### Scenario: Duplicate start rejected

- **WHEN** recording is already active and the client posts `{ "switch": "on" }` again (same or different HTTP client)
- **THEN** `success` MUST be false, `code` MUST be 409, `message` MUST indicate another recording is in progress (`另一个线程正在录制中` in zh-CN), and only one PR0 record session MUST exist

#### Scenario: Duplicate stop

- **WHEN** recording is not active and the client posts `{ "switch": "off" }`
- **THEN** `data.switch` MUST be `"off"` without error side effects

#### Scenario: UI start while HTTP recording active

- **WHEN** PR0 recording was started via HTTP without a visible `CameraController`, and the operator taps the record button in Fast or Engineer mode to start recording
- **THEN** the UI MUST NOT start a second session and MUST show **`另一个线程正在录制中`** (toast)

#### Scenario: HTTP start while UI recording active

- **WHEN** `CameraController` is recording and a client posts `{ "switch": "on" }`
- **THEN** the HTTP response MUST be the `recording_in_progress` failure described above and MUST NOT start a second encoder session

### Requirement: Serialized record start orchestration

All PR0 record **start** orchestration (`runStartPreflight` worker phase, `applySwitch("on")`, and headless `finishApplyOn` before `EasyPlayerClientManger.start()`) SHALL run on a **single dedicated serial executor thread** inside `CameraRecordCoordinator` so at most one start sequence executes at a time.

#### Scenario: Concurrent HTTP start posts

- **WHEN** two clients post `{ "switch": "on" }` nearly simultaneously while idle
- **THEN** exactly one start sequence MUST run to completion and the other MUST either succeed as the sole session or fail with `recording_in_progress` without overlapping preflight or `start()` calls

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

The system SHALL ensure `POST /v1/camera/record` does not break PR0 live viewing. HTTP live bridging is removed; LAN viewers and in-app recording MUST both consume **`camera/pr0`** on MediaMTX so only MediaMTX holds the upstream PR0 session to the camera. Starting record via HTTP while LAN RTSP viewers are connected MUST remain supported without opening a direct `RECORDING_RTSP_URL` session from the app.

#### Scenario: Live viewers during HTTP record

- **WHEN** one or more clients read `rtsp://<device-lan-ip>:8554/camera/pr0` and another client starts recording via `POST /v1/camera/record` with `{ "switch": "on" }`
- **THEN** relay viewers MUST continue to receive video, recording MUST start via `rtsp://127.0.0.1:8554/camera/pr0`, and the app MUST NOT open a second upstream RTSP session to the camera

### Requirement: Off-main-thread record handler work

Camera checks, `CameraRemote.updateCameraTime`, and `EasyPlayerClientManger` start/stop invoked by the HTTP route SHALL NOT run on the Android main thread. JSON parsing MAY occur on the HTTP thread; blocking camera I/O and recorder control SHALL use the same background executor pattern as other local HTTP handlers.

#### Scenario: HTTP record does not block UI thread

- **WHEN** `POST /v1/camera/record` is invoked
- **THEN** `CameraUtils.checkCamera` and recorder start/stop MUST complete off the main thread

### Requirement: Visible CameraController reflects comm-unavailable idle visual

When Fast Mode or Engineer Mode displays an attached **`CameraController`** and recording is **not** active, the on-screen record button visual SHALL reflect camera ping communication health: **unavailable** styling when `CameraCommStatus.isFault()`, **available** styling when healthy. This requirement applies to idle UI only and does not change HTTP record preconditions or encoder start/stop logic.

#### Scenario: HTTP idle float shows unavailable when ping fault

- **WHEN** the camera float is visible, recording is not active, and `CameraCommStatus.isFault()` is true
- **THEN** the record button SHALL display the comm-unavailable idle visual
- **AND** a subsequent successful HTTP `POST /v1/camera/record` with `{ "switch": "on" }` SHALL still be governed solely by existing preflight rules (including `CameraUtils.checkCamera`)

#### Scenario: HTTP start while float visible still syncs recording visual

- **WHEN** Quick Mode or Engineer Mode displays `CameraController`, comm is healthy, and HTTP start succeeds
- **THEN** the record button SHALL transition to the recording visual per existing UI synchronization requirements
- **AND** comm-unavailable idle styling SHALL NOT block HTTP-initiated recording

