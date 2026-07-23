## ADDED Requirements

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
