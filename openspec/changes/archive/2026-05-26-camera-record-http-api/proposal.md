## Why

LAN clients (mobile apps, factory tools, support dashboards) can already view the camera live feed and manage process videos over the device’s embedded HTTP API on port **8080**, but they cannot **start or stop PR0 process-video recording** remotely. Operators need the same recording behavior as **Fast Mode** and **Engineer Mode** (camera checks, storage guard, `EasyPlayerClientManger` PR0 record, save-to-library flow) without tapping the on-screen record button—while keeping the HMI in sync when those modes are active.

## What Changes

- Add **`POST /v1/camera/record`** on `DeviceLocalHttpServer` (`0.0.0.0:8080`).
- Request body: JSON **`{ "switch": "on" | "off" }`** (string enum, lowercase).
- Response: standard **`ApiResult`** envelope; on logical success **`data`** SHALL be **`{ "switch": "on" | "off" }`** reflecting the **effective** recording state after the operation (or unchanged state on idempotent no-op).
- **`switch: "on"`** SHALL run the **same preconditions and start path** as `CameraController` in Fast / Engineer mode (`isRecorderReady`, YNH storage free space when available, `CameraUtils.checkCamera`, `CameraRemote.updateCameraTime`, timer animation + `EasyPlayerClientManger.start()`).
- **`switch: "off"`** SHALL stop recording the same way as the UI stop action (`timerAnimator.end()`, save pipeline via existing `EasyPlayerClientManger` listener).
- When **Quick Mode** or **Engineer Mode** is foreground and hosts a visible `CameraController`, a successful HTTP toggle SHALL also drive the **same button / duration UI state** (record animation and timer) as a physical tap.
- Document the endpoint in `docs/network-api-reference.md`.
- Non-goals: cloud Worker exposure, TLS or auth on local HTTP (same LAN trust model as other `/v1/*` routes), recording from pages other than Fast / Engineer semantics (no new recording rules), WebSocket control channel.

## Capabilities

### New Capabilities

- `device-local-http-camera-record`: Embedded route `POST /v1/camera/record`, JSON contract, shared recording orchestration with `CameraController`, UI sync when Fast / Engineer is active, error codes, and coexistence with `GET /v1/camera/live` / in-flight PR0 recording.

### Modified Capabilities

- `device-local-http-api`: Extend LAN HTTP surface requirements to include `POST /v1/camera/record` alongside existing camera routes.

## Impact

- **Code**: `DeviceLocalHttpServer` (new route), new small handler or coordinator delegating to extracted/shared logic from `CameraController` / `EasyPlayerClientManger`; optional registry or event bus so visible `CameraController` instances update animation; `QuickModeActivity` / `EngineerModeActivity` unchanged except wiring sync if needed.
- **Dependencies**: Reuse existing camera stack (`EasyPlayerClientManger`, `CameraUtils`, `YNHAPI` storage probe, `CameraRemote`); no new cloud APIs.
- **Performance / device**: Same PR0 recording load as UI-initiated record; must not open duplicate incompatible record sessions.
- **Network**: `http://<device-lan-ip>:8080/v1/camera/record`; no camera credentials in JSON responses.
- **Docs**: `docs/network-api-reference.md`, route-level JVM test mirroring other local HTTP probes.
