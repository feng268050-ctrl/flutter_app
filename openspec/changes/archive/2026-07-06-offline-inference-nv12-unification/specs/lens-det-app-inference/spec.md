## MODIFIED Requirements

### Requirement: OpenCV stain detect one-shot inference mirrors RKNN entry points

The App SHALL expose OpenCV stain detect through one-shot APIs:

- `AiManager.opencvStainDetectFromNv12` for direct NV12 buffers (**process video** and any remaining Java-owned offline OpenCV samples)
- `AiManager.opencvStainDetectFromJpg` for offline image paths
- `AiManager.opencvStainDetectFromI420` **deprecated** — retained for compatibility; new code MUST NOT use it for process video

Live PR1 and AI Vision live detect SHALL NOT use Java one-shot stain APIs; they SHALL consume `StreamDetectResultBus` per existing requirements.

Each NV12/JPG call SHALL invoke the corresponding `NativeBridge.nativeOpencvStainDetectFrom*` JNI on a background executor, using the active **`opencvStainDetectHandle`** from `AiManager`, and SHALL NOT block the UI or Modbus threads.

#### Scenario: NV12 process-video sample invokes native OpenCV stain detect

- **WHEN** a sampled NV12 frame is submitted to `opencvStainDetectFromNv12` during process video Detect
- **AND** `AiManager.isOpencvStainDetectSessionActive()` is true
- **THEN** the App MUST call `nativeOpencvStainDetectFromNv12` with a non-zero session handle and a non-empty `outputDir`
- **AND** MUST return a parsed `OpencvStainDetectResult` on completion

#### Scenario: Offline JPG invokes native OpenCV stain detect

- **WHEN** `opencvStainDetectFromJpg` is called with a readable JPEG path
- **AND** `AiManager.isOpencvStainDetectSessionActive()` is true
- **THEN** the App MUST call `nativeOpencvStainDetectFromJpg`
- **AND** MUST set `source` to `StainDetectSource.OFFLINE` (`offline_stain_detect`)

#### Scenario: OpenCV session not available

- **WHEN** `AiManager.isOpencvStainDetectSessionActive()` is false
- **THEN** OpenCV stain detect MUST fail fast with `success == false`
- **AND** MUST NOT invoke native OpenCV stain detect JNI

### Requirement: AI Vision live and process video use OpenCV stain detect on existing intervals

When OpenCV stain detect is active on **AI Vision live preview**, the system SHALL subscribe to **`StreamDetectResultBus`** for `detect_result` events from the parallel native pipeline at **`AI_VISION_LIVE` (500 ms)** sampling. Java MUST NOT use `TextureView.getBitmap` or I420 callbacks from the preview player to feed live stain detect after Phase 3 migration. **`EasyPlayerClient`** SHALL remain responsible for hard-decode playback only.

When OpenCV stain detect is active on **process video Detect**, the system SHALL continue sampling at **`AI_VISION_PROCESS_VIDEO` (200 ms)** via ExoPlayer/`ProcessVideoAiSession` and **`opencvStainDetectFromNv12`** on NV12 buffers derived from retriever samples.

#### Scenario: Live 500 ms does not block playback

- **WHEN** a 500 ms live sample completes in the native pipeline during RTSP preview
- **THEN** RTSP playback and `TextureView` rendering MUST continue without blocking on detect completion

#### Scenario: Process video 200 ms does not block ExoPlayer

- **WHEN** a 200 ms process-video sample fires during Detect playback
- **THEN** ExoPlayer MUST continue without waiting for OpenCV detect completion

### Requirement: OpenCV busy-drop is orthogonal to interval gating

When a sample is accepted by an OpenCV sampling gate but `isOpencvStainDetectBusy()` is true, the system SHALL drop that detect attempt without resetting the gate timestamp. Video playback and RTSP decode MUST continue; overlay uses hold-forward.

#### Scenario: Accepted sample dropped when OpenCV busy

- **WHEN** the process-video gate accepts a sample and a prior `opencvStainDetectFromNv12` is still running
- **THEN** the new detect MUST NOT start
- **AND** overlay MUST use the last completed timeline sample

### Requirement: Camera-based stain detect JNI SHALL accept cameraType parameter

Native stain-detect JNI entry points used for live and recorded camera video SHALL accept a trailing **`int cameraType`** argument with values defined by `CameraType` (`1` = BLUE_LIGHT, `2` = RED_LIGHT).

Affected methods include at minimum:

- RKNN: `nativeCreate`, `nativeRknnStainDetectFromStream`, `nativeRknnStainDetectFromJpg`, `nativeRknnStainDetectFromRgb`, `nativeRknnStainDetectFromI420`, `nativeRknnStainDetectFromJpgAndSave`, `nativeRknnStainDetectFromVideoAndSave`
- OpenCV stain: `nativeCreateOpencvStainDetectSession`, `nativeOpencvStainDetectFromJpg`, `nativeOpencvStainDetectFromRgb`, `nativeOpencvStainDetectFromNv12`, `nativeOpencvStainDetectFromI420` (deprecated)

Until red-light inference is implemented, native code MUST ignore `cameraType` and MUST preserve current blue-light behavior for all accepted values.

#### Scenario: Blue light call path unchanged

- **WHEN** the App invokes any affected JNI method with `cameraType=1`
- **THEN** detection output and performance MUST match pre-change behavior for the same inputs
