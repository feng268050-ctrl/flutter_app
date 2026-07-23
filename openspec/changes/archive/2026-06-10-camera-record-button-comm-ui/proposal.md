## Why

Fast / Engineer mode operators use the floating `CameraController` record button without knowing whether the industrial camera is reachable until they tap and see a toast. The app already maintains continuous camera communication health via ICMP ping (`CameraPingHealth` → `CameraCommStatus`), but the record button only distinguishes **idle** vs **recording** and does not surface comm fault as a persistent visual state.

## What Changes

- Add a third **unavailable** visual style on the floating record button when camera communication is faulted (`CameraCommStatus.isFault()`), driven by the same ping health cache as Monitor C002 (`CacheKey.CAMERA_PING_REACHABLE`).
- Keep **available** (idle, comm healthy) and **recording** (timer + run icon) behaviors unchanged.
- **Unavailable is visual-only**: the button remains **clickable**; a tap shows the existing localized **camera unavailable** feedback (`unable_to_open_the_camera_title` / equivalent) and does **not** start preflight or recording.
- Refresh button appearance when ping health changes (1 Hz scheduler + cache listener), without blocking stop while recording if comm drops mid-session.
- Update `camera_*_icon.xml` selectors (orange / green / blue) to support unavailable styling without using `android:enabled=false` on the click target.

## Capabilities

### New Capabilities

- `camera-record-button-comm-ui`: Three-state record button visuals (available / unavailable / recording) tied to `CameraCommStatus`, with clickable unavailable taps showing camera-unavailable feedback only.

### Modified Capabilities

- `device-local-http-camera-record`: Document that visible `CameraController` reflects comm-unavailable visual state when ping health is faulted; HTTP record preconditions unchanged (still fail on camera check).

## Impact

- **UI**: `CameraController`, `camera_controller.xml`, `camera_orange_icon.xml`, `camera_green_icon.xml`, `camera_blue_icon.xml`; optional `ImageButtonStateAdapter` extension for visual-only “muted” state.
- **State source**: `CameraCommStatus`, `CameraPingHealth`, `MemoryCacheManager` listener on `CAMERA_PING_REACHABLE` (same signal as `WarnInfoFragment`).
- **Tests**: Unit tests for state resolution (recording overrides unavailable visual; comm recovery updates idle visual; unavailable tap does not call `runStartPreflight`).
- **Non-goals**: Changing C002 alarm pipeline, ping scheduler interval, HTTP record API contract, or storage/recorder-ready preflight rules.
