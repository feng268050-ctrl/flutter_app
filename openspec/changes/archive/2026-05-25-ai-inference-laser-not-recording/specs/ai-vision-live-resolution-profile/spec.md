## MODIFIED Requirements

### Requirement: Live inference resolution follows IPC sub-stream configuration

The system SHALL use the configured **sub-stream** RTSP endpoint for live inference frame push. The effective pixel dimensions SHALL come from the decoded stream (e.g. `RESULT_VIDEO_SIZE` / `LIVE_VIDEO_SIZE` logs) and SHALL NOT assume a fixed width/height in application code. In Quick Mode and Engineer Mode, sub-stream inference SHALL remain active whenever laser is ON, regardless of recording state.

Field reference for IPC configuration includes **640×512** sub-stream with **H.264 Baseline**, **768K CBR**, explicit frame rate, and a **short I-frame interval** (see `docs/dual-stream-workflow.md`). **1280×720** remains an acceptable alternative sub-stream resolution when configured on the IPC.

#### Scenario: Default live profile selection
- **WHEN** live AI Vision starts on a supported camera profile
- **THEN** the app SHALL connect to the configured sub-stream URL first
- **AND** logs SHALL record effective video width and height after decode

#### Scenario: Production mode laser-on inference
- **WHEN** Quick Mode or Engineer Mode turns laser ON
- **THEN** the app SHALL connect to `CameraConfig.liveInferenceRtspUrl` (sub-stream) for frame push
- **AND** frame dimensions SHALL be taken from decode callbacks on that connection, not from the main-stream recorder

## ADDED Requirements

### Requirement: Main-stream recorder is not a production inference source

The virtual-surface `EasyPlayerClientManger` used for process video recording SHALL NOT be the only component supplying I420 frames to `LensGuardManager` during Quick Mode or Engineer Mode welding.

#### Scenario: Inference without record session
- **WHEN** laser is ON and `LensGuardManager.isRunning()` is true but `EasyPlayerClientManger` is not recording
- **THEN** `LensGuardManager.onI420Frame` SHALL still receive frames from the sub-stream inference client
