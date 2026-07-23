## MODIFIED Requirements

### Requirement: Live weld path samples PR1 and calls OpenCV stain detect

In Quick Mode and Engineer Mode, when laser is ON and the OpenCV session is active, **`OpencvStainDetectCoordinator`** SHALL obtain live weld stain detect results by subscribing to **`StreamDetectResultBus`** `detect_result` events from `StreamDetectPipeline` with `StainDetectSource.LIVE`. The system MUST NOT sample PR1 I420 in Java or call `opencvStainDetectFromI420` for live RTSP weld samples. Native pipeline sampling SHALL use **500 ms** in normal mode and **100 ms** in burst mode per `laser-detect-frame-rejected-burst`.

Red-frame rejections (`overexposed`, `invalid_non_red`) and saturation skip SHALL still surface as `code=-5` outcomes for burst entry.

#### Scenario: Live weld respects 500 ms gate in normal mode

- **WHEN** native pipeline decodes PR1 at 25 fps, laser is ON, OpenCV session active, and burst mode is not active
- **THEN** at most one live weld stain detect result MUST be produced per 500 ms

#### Scenario: Live weld uses 100 ms gate in burst mode

- **WHEN** burst sampling mode is active after a `code=-5` result (including `reason=overexposed`)
- **THEN** the native pipeline MUST produce at most one stain detect result per 100 ms (subject to busy-drop)

#### Scenario: Laser off stops live weld sampling

- **WHEN** laser turns OFF
- **THEN** live weld OpenCV sampling MUST stop in the native pipeline
- **AND** coordinator burst state MUST reset to normal

### Requirement: AI Vision live and process video use OpenCV stain detect on existing intervals

When OpenCV stain detect is active on **AI Vision live preview**, the system SHALL subscribe to **`StreamDetectResultBus`** for `detect_result` events from the parallel native pipeline at **`AI_VISION_LIVE` (500 ms)** sampling. Java MUST NOT use `TextureView.getBitmap` or I420 callbacks from the preview player to feed live stain detect after Phase 3 migration. **`EasyPlayerClient`** SHALL remain responsible for hard-decode playback only.

When OpenCV stain detect is active on **process video Detect**, the system SHALL continue sampling at **`AI_VISION_PROCESS_VIDEO` (200 ms)** via ExoPlayer/`ProcessVideoAiSession` and **`opencvStainDetectFromI420`** — this offline file path is unchanged.

#### Scenario: Live 500 ms does not block playback

- **WHEN** a 500 ms live sample completes in the native pipeline during RTSP preview
- **THEN** RTSP playback and `TextureView` rendering MUST continue without blocking on detect completion

#### Scenario: Process video 200 ms does not block ExoPlayer

- **WHEN** a 200 ms process-video sample fires during Detect playback
- **THEN** ExoPlayer MUST continue without waiting for OpenCV detect completion

### Requirement: App SHALL pass DeviceModelConfig camera type into stain JNI

The App layer SHALL pass `DeviceModelConfig.getCameraType().getValue()` into every affected native stain-detect call. For **live RTSP** samples, camera type MUST be configured on **`StreamDetectPipeline`** via control JNI at session start. For **offline** paths (`opencvStainDetectFromI420` on ExoPlayer samples, JPG paths), existing JNI call sites MUST continue passing camera type.

#### Scenario: Live native pipeline receives camera type

- **WHEN** `StreamDetectPipeline` starts on a device with `camera_type=1` in ROM
- **THEN** native stain detect in the pipeline MUST receive `cameraType=1`

#### Scenario: Process video session uses ROM camera type

- **WHEN** process video Detect runs on a device with `camera_type=2` in ROM
- **THEN** each OpenCV stain JNI call in that session MUST receive `cameraType=2`

## ADDED Requirements

### Requirement: Live RTSP stain detect results arrive via StreamDetectResultBus

For live weld and AI Vision live RTSP paths, the App SHALL map **`detect_result`** payloads from `StreamDetectResultBus` into `OpencvStainDetectResult` / `AiStainDetectResult` using the same mappers as native JNI JSON responses. Per-frame live detect MUST NOT invoke `nativeOpencvStainDetectFromI420` from Java.

#### Scenario: Bus result maps to AiStainDetectResult

- **WHEN** a live `detect_result` for lens_det contains boxes and dimensions
- **THEN** `AiStainDetectResultMapper` MUST produce an `AiStainDetectResult` suitable for overlay and SSE

#### Scenario: Offline JPG and process video still use JNI one-shot

- **WHEN** `opencvStainDetectFromJpg` or process-video `opencvStainDetectFromI420` is invoked
- **THEN** existing one-shot JNI paths MUST remain unchanged
