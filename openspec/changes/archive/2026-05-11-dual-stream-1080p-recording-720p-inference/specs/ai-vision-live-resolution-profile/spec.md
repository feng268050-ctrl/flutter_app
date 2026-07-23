## ADDED Requirements

### Requirement: Live inference resolution follows IPC sub-stream configuration

The system SHALL use the configured **sub-stream** RTSP endpoint for live AI Vision preview and inference. The effective pixel dimensions SHALL come from the decoded stream (e.g. `RESULT_VIDEO_SIZE` / `LIVE_VIDEO_SIZE` logs) and SHALL NOT assume a fixed width/height in application code.

Field reference for IPC configuration includes **640×512** sub-stream with **H.264 Baseline**, **768K CBR**, explicit frame rate, and a **short I-frame interval** (see `docs/dual-stream-workflow.md`). **1280×720** remains an acceptable alternative sub-stream resolution when configured on the IPC.

#### Scenario: Default live profile selection
- **WHEN** live AI Vision starts on a supported camera profile
- **THEN** the app SHALL connect to the configured sub-stream URL first
- **AND** logs SHALL record effective video width and height after decode

### Requirement: 640x640 is inference input transform, not camera output default

The system MUST treat 640x640 as an optional model-input transform profile (letterbox/resize) and SHALL NOT require camera output to be 640x640 by default.

#### Scenario: Model input adaptation enabled
- **WHEN** model runtime requires 640x640 input
- **THEN** frames SHALL be transformed from the live stream to 640x640 in preprocessing
- **AND** display/render resolution SHALL keep camera aspect ratio behavior

### Requirement: Resolution-aware performance validation

The system SHALL provide measurable validation for motion smoothness and latency before and after enabling the sub-stream live profile.

#### Scenario: Resolution policy rollout
- **WHEN** sub-stream live policy is enabled in field test
- **THEN** validation logs/checklist SHALL capture first-frame time, decode type, effective resolution, and motion-stutter observations for comparison with prior profile
