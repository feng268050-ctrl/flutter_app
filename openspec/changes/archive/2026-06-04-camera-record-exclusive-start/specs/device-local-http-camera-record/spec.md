## RENAMED Requirements

- FROM: `### Requirement: Idempotent record control`
- TO: `### Requirement: Exclusive record start and idempotent stop`

## MODIFIED Requirements

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

## ADDED Requirements

### Requirement: Serialized record start orchestration

All PR0 record **start** orchestration (`runStartPreflight` worker phase, `applySwitch("on")`, and headless `finishApplyOn` before `EasyPlayerClientManger.start()`) SHALL run on a **single dedicated serial executor thread** inside `CameraRecordCoordinator` so at most one start sequence executes at a time.

#### Scenario: Concurrent HTTP start posts

- **WHEN** two clients post `{ "switch": "on" }` nearly simultaneously while idle
- **THEN** exactly one start sequence MUST run to completion and the other MUST either succeed as the sole session or fail with `recording_in_progress` without overlapping preflight or `start()` calls
