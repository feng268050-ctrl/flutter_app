## MODIFIED Requirements

### Requirement: Live inference resolution follows IPC sub-stream configuration

The system SHALL use the configured **sub-stream** RTSP endpoint for live inference. **Java playback** (`EasyPlayerClient`) and **native detection** (`StreamDetectPipeline`) SHALL each open independent reader sessions to the MediaMTX relay sub-stream (e.g. `rtsp://127.0.0.1:8554/camera/pr1`). Effective pixel dimensions SHALL come from each session's decoded stream and SHALL NOT assume fixed width/height in application code. In Quick Mode and Engineer Mode, native sub-stream detection SHALL remain active whenever laser is ON, regardless of recording state.

Field reference for IPC configuration includes **640×512** sub-stream with **H.264 Baseline**, **768K CBR**, explicit frame rate, and a **short I-frame interval** (see `docs/dual-stream-workflow.md`). **1280×720** remains an acceptable alternative sub-stream resolution when configured on the IPC.

#### Scenario: Default live profile selection

- **WHEN** live AI Vision starts on a supported camera profile
- **THEN** Java playback SHALL connect to the configured sub-stream URL for preview
- **AND** native detect pipeline SHALL connect to the same relay sub-stream on a separate session when detect is enabled
- **AND** logs SHALL record effective video width and height after decode for each session

#### Scenario: Production mode laser-on inference

- **WHEN** Quick Mode or Engineer Mode turns laser ON
- **THEN** native `StreamDetectPipeline` SHALL consume `CameraConfig.LIVE_INFERENCE_RTSP_URL` (MediaMTX relay sub-stream)
- **AND** frame dimensions SHALL be taken from native decode, not from the main-stream recorder

### Requirement: Main-stream recorder is not a production inference source

The virtual-surface `EasyPlayerClientManger` used for process video recording SHALL NOT supply frames to live detect paths. Production weld detect SHALL use **`StreamDetectPipeline`** only, not `LensGuardManager.onI420Frame` from a Java PR1 client.

#### Scenario: Inference without record session

- **WHEN** laser is ON and native detect pipeline is running but `EasyPlayerClientManger` is not recording
- **THEN** native pipeline SHALL decode PR1 and run gated detect without any Java PR1 inference client
- **AND** this behavior SHALL differ from AI Vision live preview, which uses Java hard-decode playback plus parallel native detect at `AI_VISION_LIVE` (500 ms) after Phase 3

### Requirement: 640x640 is inference input transform, not camera output default

The system MUST treat 640×640 as a **native engine** ROI transform (center crop of the decoded full frame to model input), not as a default camera output resolution and not as an App-side letterbox or resize before native detect.

The native pipeline SHALL decode sub-stream frames at native resolution when both width and height are at least 640. App-side letterbox-to-640 before live native detect SHALL be disabled in production.

#### Scenario: Model input adaptation inside native

- **WHEN** the Lens Guard or OpenCV engine runs stain detection on a live frame at 1920×1080 in the native pipeline
- **THEN** center crop to 640×640 with offsets (640, 220) SHALL occur inside native code
- **AND** Java display/render resolution SHALL keep camera aspect ratio on the preview surface

#### Scenario: Legacy App letterbox preference off

- **WHEN** `CameraConfig.isAiInputLetterbox640Enabled` is false (default)
- **THEN** live native detect MUST NOT apply `AiI420Letterbox640` in Java
- **AND** detection overlays SHALL use full-frame box coordinates from bus results without client crop offset

### Requirement: Resolution-aware performance validation

The system SHALL provide measurable validation for motion smoothness, latency, CPU, and thermal behavior before and after enabling dual-link AI Vision (Java playback + native detect on the same relay sub-stream).

#### Scenario: Dual-link AI Vision rollout

- **WHEN** Phase 3 dual-link policy is enabled on RK3566 field test
- **THEN** validation logs/checklist SHALL capture first-frame time, decode type, effective resolution, CPU/thermal observations, and overlay sync tolerance for both Java playback and native detect sessions

#### Scenario: Weld-only native single link baseline

- **WHEN** Phase 1 weld path is enabled without AI Vision dual-link
- **THEN** validation SHALL capture native pipeline decode metrics without Java PR1 detect client overhead

## ADDED Requirements

### Requirement: AI Vision live uses dual independent decode links

When AI Vision live preview and live detect are both active, the App SHALL run **two independent decode links** to the same MediaMTX relay sub-stream:

- **Playback link:** Java `EasyPlayerClient` + Android MediaCodec hard decode → `TextureView` / Surface
- **Detect link:** C++ `StreamDetectPipeline` + NdkMediaCodec → native detect → `StreamDetectResultBus`

Neither link SHALL transfer image frames to the other.

#### Scenario: Preview continues when detect fails

- **WHEN** native detect pipeline errors or reconnects
- **THEN** Java playback MUST continue on its separate RTSP session
- **AND** overlay MUST reflect detect inactive or stale state per bus timeout rules

#### Scenario: Detect continues when preview pauses

- **WHEN** AI Vision preview is stopped but product policy keeps live SSE detect active
- **THEN** behavior MUST follow product lifecycle rules documented in implementation
- **AND** MUST NOT implicitly restart Java PR1 detect decode clients removed by this change

### Requirement: AI Vision fallback when dual-link stress test fails

When RK3566 dual-link stress test does not pass, the product SHALL keep Java PR1 playback while disabling native AI Vision detect and live stain overlay independently of weld native detect.

#### Scenario: 4.4 playback-only fallback

- **WHEN** `isNativeAiVisionStreamDetectEnabled()` is false and `isAiVisionLiveBitmapDetectEnabled()` is false
- **THEN** AI Vision live preview SHALL continue on Java `EasyPlayerClient` connected to PR1 relay candidates
- **AND** C++ `StreamDetectPipeline` SHALL NOT acquire the `ai_vision` holder
- **AND** live stain-detect overlay SHALL be hidden
- **AND** weld native detect MAY remain enabled via `isNativeWeldStreamDetectEnabled()` without AI Vision dual-link

#### Scenario: Resolution profile logging for field test

- **WHEN** `isAiVisionResolutionProfileLoggingEnabled()` is true during AI Vision live start
- **THEN** logs tagged `AiVisionResolutionProfile` SHALL record detect policy, RTSP candidate policy, playback decode size, and native detect decode size when detect is active
