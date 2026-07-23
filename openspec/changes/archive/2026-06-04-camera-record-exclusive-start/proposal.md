## Why

`POST /v1/camera/record`, headless `EasyPlayerClientManger` start, and Fast / Engineer `CameraController` can all initiate PR0 recording from different threads. Today duplicate `switch: "on"` is treated as **idempotent success**, which hides concurrent integrators and can still race before `isRecordingActive()` settles. Operators and LAN clients need a single active recording session and an explicit failure when something else is already recording.

## What Changes

- Serialize PR0 record **start** orchestration (HTTP `applySwitch("on")`, headless start, and UI preflight completion) on a **single dedicated executor thread** so only one start sequence runs at a time.
- **BREAKING**: When a start is requested while a recording session is already active (`EasyPlayerClientManger` or visible `CameraController` UI state), the operation MUST **fail** instead of returning success with `data.switch: "on"`.
- Surface the user-visible message **`另一个线程正在录制中`** (localized string resources for zh/en) on UI paths; HTTP `ApiResult` failure MUST use a stable machine code (for example `recording_in_progress`) and a message field carrying the same text for integrators.
- Keep **`switch: "off"`** idempotent when idle (no second stop side effects).
- Update `docs/network-api-reference.md`, coordinator/route tests, and capability specs that today require idempotent duplicate start.

## Capabilities

### New Capabilities

_(none)_

### Modified Capabilities

- `device-local-http-camera-record`: Replace idempotent duplicate-start requirement with exclusive start + conflict failure semantics and message contract.
- `device-local-http-api`: Document `POST /v1/camera/record` failure when recording is already active (error code and message).

## Impact

- `CameraRecordCoordinator` — serial executor for start paths; conflict detection before preflight; new failure `Result` / preflight enum.
- `CameraController` — `checkAndStartRecord` / `runStartPreflight` failure toast for conflict.
- `EasyPlayerClientManger` — remain single encoder instance; coordinator owns exclusivity (no second `start()` when active).
- `DeviceLocalHttpServer` / `CameraRecordSwitchBody` — unchanged JSON success shape; new failure responses for duplicate start.
- Tests: `DeviceLocalHttpCameraRecordRouteTest`, new or extended coordinator unit tests.
- Docs: `docs/network-api-reference.md`.
