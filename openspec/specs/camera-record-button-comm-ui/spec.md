# camera-record-button-comm-ui Specification

## Purpose
TBD - created by archiving change camera-record-button-comm-ui. Update Purpose after archive.
## Requirements
### Requirement: Record button comm-driven visual states

The floating **`CameraController`** record button in Fast Mode and Engineer Mode SHALL expose three operator-visible visual states:

1. **Available** — not recording and camera communication is healthy (`CameraCommStatus.isHealthy()`).
2. **Unavailable** — not recording and camera communication is faulted (`CameraCommStatus.isFault()`).
3. **Recording** — active record session (`isRecord` true): run icon and duration label per existing behavior.

Available vs unavailable SHALL be driven by the same ICMP ping health module used for Monitor camera comm (`CameraPingHealth` / `CacheKey.CAMERA_PING_REACHABLE`), not by a separate ad-hoc probe in the button.

#### Scenario: Available when ping healthy and idle

- **WHEN** `CameraController` is visible, `isRecord` is false, and `CameraCommStatus.isHealthy()` is true
- **THEN** the record button SHALL show the idle (available) icon for the active mode color (orange / green / blue)
- **AND** the duration label SHALL be hidden

#### Scenario: Unavailable when ping fault and idle

- **WHEN** `CameraController` is visible, `isRecord` is false, and `CameraCommStatus.isFault()` is true
- **THEN** the record button SHALL show the unavailable (muted) idle visual distinct from the available idle visual
- **AND** the duration label SHALL remain hidden

#### Scenario: Recording visual takes precedence over comm fault

- **WHEN** `CameraController` is recording (`isRecord` true)
- **AND** camera ping health reports fault during the session
- **THEN** the button SHALL continue to show the recording visual (run icon and timer)
- **AND** the operator SHALL still be able to stop recording with one tap

#### Scenario: Comm recovery updates idle visual

- **WHEN** `CameraController` is visible and not recording
- **AND** ping health transitions from fault to healthy per existing recovery rules
- **THEN** the button visual SHALL update from unavailable to available without requiring an Activity restart

### Requirement: Unavailable visual does not disable clicks

The unavailable visual state SHALL be **presentational only**. The record button click target (`camera_controller_root`) MUST remain clickable while showing unavailable styling.

#### Scenario: Unavailable tap shows camera unavailable feedback

- **WHEN** the operator taps the record button while idle and `CameraCommStatus.isFault()` is true
- **THEN** the app SHALL show localized feedback equivalent to **camera unavailable** (existing `unable_to_open_the_camera_title` or locale translation)
- **AND** the app MUST NOT invoke `CameraRecordCoordinator.runStartPreflight` or start the record timer / PR0 encoder

#### Scenario: Available tap starts existing preflight path

- **WHEN** the operator taps the record button while idle and `CameraCommStatus.isHealthy()` is true
- **THEN** the app SHALL follow the existing `checkAndStartRecord()` / `runStartPreflight` path unchanged

#### Scenario: Recording tap stops session

- **WHEN** the operator taps the record button while `isRecord` is true
- **THEN** the app SHALL stop recording through the existing `stopRecord()` path regardless of current ping health

### Requirement: Comm health listener on camera float lifecycle

`CameraController` SHALL refresh its comm-driven visual state when ping reachability changes while attached to the window.

#### Scenario: Listener registered on attach

- **WHEN** `CameraController` is attached to the window
- **THEN** it SHALL register for `CacheKey.CAMERA_PING_REACHABLE` updates (or equivalent comm status signal)
- **AND** SHALL apply the correct visual state on the main thread

#### Scenario: Listener removed on detach

- **WHEN** `CameraController` is detached from the window
- **THEN** it SHALL remove the comm status listener to avoid leaks

