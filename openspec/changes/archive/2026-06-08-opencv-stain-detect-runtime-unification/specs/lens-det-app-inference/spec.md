## RENAMED Requirements

- FROM: `### Requirement: Lens det one-shot inference mirrors RKNN infer entry points`
- TO: `### Requirement: OpenCV stain detect one-shot inference mirrors RKNN entry points`

- FROM: `### Requirement: Lens det JSON parsing follows native two-step contract`
- TO: `### Requirement: OpenCV stain detect JSON parsing follows native contract`

- FROM: `### Requirement: Real-time production path samples PR1 like RKNN but calls one-shot lens det`
- TO: `### Requirement: Live weld path samples PR1 and calls OpenCV stain detect`

- FROM: `### Requirement: AI Vision live and process video use one-shot lens det on existing intervals`
- TO: `### Requirement: AI Vision live and process video use OpenCV stain detect on existing intervals`

## MODIFIED Requirements

### Requirement: OpenCV stain detect one-shot inference mirrors RKNN entry points

The App SHALL expose OpenCV stain detect through one-shot APIs:

- `AiManager.opencvStainDetectFromI420` for direct I420 buffers (live PR1, AI Vision live, process video)
- `AiManager.opencvStainDetectFromJpg` for offline image paths

Each call SHALL invoke `NativeBridge.nativeOpencvStainDetectFrom*` JNI on a background executor using the active **`opencvStainDetectHandle`** from `AiManager`, and SHALL NOT block the UI or Modbus threads.

#### Scenario: I420 live sample invokes native OpenCV stain detect

- **WHEN** a gated I420 frame is submitted to `opencvStainDetectFromI420`
- **AND** `AiManager.isOpencvStainDetectSessionActive()` is true
- **THEN** the App MUST call `nativeOpencvStainDetectFromI420` with a non-zero session handle and non-empty `outputDir`
- **AND** MUST return a parsed `OpencvStainDetectResult` on completion

#### Scenario: Offline JPG invokes native OpenCV stain detect

- **WHEN** `opencvStainDetectFromJpg` is called with a readable JPEG path
- **THEN** the App MUST call `nativeOpencvStainDetectFromJpg`
- **AND** MUST set result `source` to `StainDetectSource.OFFLINE` (`offline_stain_detect`)

#### Scenario: OpenCV session not active

- **WHEN** `isOpencvStainDetectSessionActive()` is false
- **THEN** OpenCV stain detect MUST fail fast with `success == false`
- **AND** MUST NOT invoke native OpenCV stain detect JNI

### Requirement: OpenCV stain detect JSON parsing follows native contract

The App SHALL parse OpenCV stain detect native output via `OpencvStainDetectResultMapper` into `OpencvStainDetectResult`, then map to **`AiStainDetectResult`** for SSE, timeline, and overlay consumers.

The unified wire type **`AiStainDetectResult`** SHALL expose at minimum: `success`, `code`, `level`, `status`, `message`, `imageWidth`, `imageHeight`, `boxes`, `source`, `timestampMs`.

#### Scenario: Successful detect maps to AiStainDetectResult

- **WHEN** OpenCV stain detect completes with boxes and dimensions
- **THEN** `AiStainDetectResultMapper` MUST produce an `AiStainDetectResult` suitable for `AiInferenceSseJson.runningData`

### Requirement: Live weld path samples PR1 and calls OpenCV stain detect

In Quick Mode and Engineer Mode, when laser is ON and the OpenCV session is active, **`OpencvStainDetectCoordinator`** SHALL obtain I420 frames from `LivePr1InferenceStreamClient`. The system SHALL apply **`LIVE_WELD` (2000 ms)** via `tryAcceptOpencvLiveWeldInferSample`. Accepted frames SHALL call `opencvStainDetectFromI420` with `StainDetectSource.LIVE` on a background executor.

#### Scenario: Live weld respects 2000 ms gate

- **WHEN** PR1 decodes at 25 fps and laser is ON with OpenCV session active
- **THEN** at most one OpenCV stain detect MUST start per 2000 ms

#### Scenario: Laser off stops live weld sampling

- **WHEN** laser turns OFF
- **THEN** live weld OpenCV sampling MUST stop
- **AND** `resetOpencvLiveWeldFrameSampling()` MUST run

### Requirement: AI Vision live and process video use OpenCV stain detect on existing intervals

When OpenCV stain detect is active on AI Vision live preview, the system SHALL sample at **`AI_VISION_LIVE` (500 ms)** via `tryAcceptOpencvAiVisionLiveInferSample` and call `opencvStainDetectFromI420` without blocking RTSP or TextureView rendering.

When OpenCV stain detect is active on process video Detect, the system SHALL sample at **`AI_VISION_PROCESS_VIDEO` (200 ms)** via `tryAcceptOpencvProcessVideoInferSample` on the session worker without blocking ExoPlayer playback.

#### Scenario: Live 500 ms does not block playback

- **WHEN** a 500 ms live sample fires during RTSP preview
- **THEN** the sample callback MUST return without waiting for OpenCV detect completion on the main thread

#### Scenario: Process video 200 ms does not block ExoPlayer

- **WHEN** a 200 ms process-video sample fires during Detect playback
- **THEN** ExoPlayer MUST continue without waiting for OpenCV detect completion

## REMOVED Requirements

### Requirement: Lens det busy-drop is orthogonal to interval gating

**Reason**: Documented under `ai-frame-sampling-inference` OpenCV busy-drop; `inferLensDetFromI420` removed.

**Migration**: Use `isOpencvStainDetectBusy()` and hold-forward stores.
