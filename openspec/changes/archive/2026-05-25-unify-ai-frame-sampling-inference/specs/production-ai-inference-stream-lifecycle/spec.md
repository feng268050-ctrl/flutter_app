## ADDED Requirements

### Requirement: Production sub-stream frames are decimated before LensGuard push

In Quick Mode and Engineer Mode, when the sub-stream inference client delivers decoded I420 frames, the system SHALL apply the `PRODUCTION_WELD` frame-sampling profile (2000 ms) before copying frame payload and calling `LensGuardManager` push logic. Decode callbacks MAY continue at full frame rate; only sampled frames SHALL reach `guardedPushFrame`.

#### Scenario: Laser on with sub-stream at video frame rate

- **WHEN** laser is ON and the inference RTSP client decodes at typical video frame rate (e.g. 25 fps)
- **THEN** at most one frame per 2000 ms SHALL be pushed to LensGuard for live weld inference
- **AND** inference stream lifecycle (start/stop on laser) SHALL remain unchanged

#### Scenario: Laser off stops push regardless of sampling

- **WHEN** laser turns OFF and the inference client stops
- **THEN** frame push to LensGuard from that client SHALL cease
- **AND** the production sampling gate SHALL reset

## MODIFIED Requirements

### Requirement: Production-mode inference stream follows laser state

In Quick Mode and Engineer Mode, the system SHALL start the live inference RTSP client when the device laser is ON and SHALL stop it when the laser is OFF. This lifecycle SHALL NOT depend on whether process video recording is active.

#### Scenario: Laser on without recording

- **WHEN** the user enables laser in Quick Mode or Engineer Mode and video recording is not started
- **THEN** the app SHALL connect to the configured sub-stream URL (`CameraConfig.liveInferenceRtspUrl`, typically `/PR1`)
- **AND** decoded frames SHALL be subject to the production frame-sampling gate (2000 ms) before push to `LensGuardManager` while the engine is running
- **AND** `nativeSetLaserOn` SHALL reflect the actual laser state from device status

#### Scenario: Laser off stops inference stream

- **WHEN** the user disables laser while inference stream is active
- **THEN** the inference RTSP client SHALL stop
- **AND** frame push to `LensGuardManager` from that client SHALL cease
- **AND** the production frame-sampling gate SHALL reset
- **AND** recording MAY continue if the user had started it independently (until user stops recording)

#### Scenario: Recording without laser does not drive weld inference

- **WHEN** the user starts process video recording with laser OFF
- **THEN** the main stream (`CameraConfig.recordingRtspUrl`, typically `/PR0`) MAY be used for mux/file output only
- **AND** the app SHALL NOT treat recording start as the sole trigger for production weld-time inference frame push
