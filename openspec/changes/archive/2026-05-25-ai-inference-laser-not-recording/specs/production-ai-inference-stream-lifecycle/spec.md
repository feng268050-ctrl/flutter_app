## ADDED Requirements

### Requirement: Production-mode inference stream follows laser state

In Quick Mode and Engineer Mode, the system SHALL start the live inference RTSP client when the device laser is ON and SHALL stop it when the laser is OFF. This lifecycle SHALL NOT depend on whether process video recording is active.

#### Scenario: Laser on without recording
- **WHEN** the user enables laser in Quick Mode or Engineer Mode and video recording is not started
- **THEN** the app SHALL connect to the configured sub-stream URL (`CameraConfig.liveInferenceRtspUrl`, typically `/PR1`)
- **AND** decoded frames SHALL be pushed to `LensGuardManager` while the engine is running
- **AND** `nativeSetLaserOn` SHALL reflect the actual laser state from device status

#### Scenario: Laser off stops inference stream
- **WHEN** the user disables laser while inference stream is active
- **THEN** the inference RTSP client SHALL stop
- **AND** frame push to `LensGuardManager` from that client SHALL cease
- **AND** recording MAY continue if the user had started it independently (until user stops recording)

#### Scenario: Recording without laser does not drive weld inference
- **WHEN** the user starts process video recording with laser OFF
- **THEN** the main stream (`CameraConfig.recordingRtspUrl`, typically `/PR0`) MAY be used for mux/file output only
- **AND** the app SHALL NOT treat recording start as the sole trigger for production weld-time inference frame push

### Requirement: Recording and inference streams are independent clients

The system SHALL use separate RTSP player instances (or equivalent isolated sessions) for main-stream recording and sub-stream inference so that starting or stopping one does not implicitly start or stop the other.

#### Scenario: Laser on and recording on concurrently
- **WHEN** laser is ON and the user starts video recording
- **THEN** main stream recording and sub-stream inference SHALL both be active
- **AND** stopping recording SHALL NOT stop sub-stream inference while laser remains ON
- **AND** turning laser OFF SHALL stop sub-stream inference without requiring the user to stop recording first (recording stop policy MAY follow existing UX)

### Requirement: Inference stream lifecycle observability

Diagnostics logs SHALL distinguish inference stream lifecycle from recording lifecycle.

#### Scenario: Inference stream starts for laser
- **WHEN** sub-stream inference client starts due to laser ON
- **THEN** logs SHALL include reason `laser_on`, profile `sub`, and the RTSP path suffix (e.g. `/PR1`)

#### Scenario: Recording starts without stopping inference
- **WHEN** recording starts while inference stream is already active
- **THEN** logs SHALL include reason `record_start` with profile `main` (e.g. `/PR0`)
- **AND** logs SHALL NOT report `record_start` as the only reason inference stream started if laser was already ON
