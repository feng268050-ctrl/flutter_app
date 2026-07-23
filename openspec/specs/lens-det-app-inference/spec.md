# lens-det-app-inference Specification

## Purpose

OpenCV stain detect one-shot inference for live weld PR1, AI Vision live, and process video — unified wire type `AiStainDetectResult` for SSE and overlay.
## Requirements
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

### Requirement: OpenCV stain detect JSON parsing follows native contract

The App SHALL parse OpenCV stain detect native output via `OpencvStainDetectResultMapper` into `OpencvStainDetectResult`, then map to **`AiStainDetectResult`** for SSE, timeline, and overlay consumers.

#### Scenario: Successful detect maps to AiStainDetectResult

- **WHEN** OpenCV stain detect completes with boxes and dimensions
- **THEN** `AiStainDetectResultMapper` MUST produce an `AiStainDetectResult` suitable for `AiInferenceSseJson.runningData`

### Requirement: Live weld path samples PR1 and calls OpenCV stain detect

In Quick Mode and Engineer Mode, when laser is ON and the OpenCV session is active, **`OpencvStainDetectCoordinator`** SHALL obtain live weld stain detect results by subscribing to **`StreamDetectResultBus`** `detect_result` events from `StreamDetectPipeline` with `StainDetectSource.LIVE`. The system MUST NOT sample PR1 I420 in Java or call `opencvStainDetectFromI420` for live RTSP weld samples. Native pipeline sampling SHALL use **500 ms** in normal mode and **100 ms** in burst mode per `laser-detect-frame-rejected-burst`.

When a Live weld result has `code == -3` (`DETECT_FAILED`), the coordinator SHALL additionally attempt stain audit upload enqueue per `stain-audit-auto-upload`. When `code == -5` (`FRAME_REJECTED`), the coordinator SHALL NOT enqueue upload tasks.

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

#### Scenario: Detect failed does not disable consecutive OK gate

- **WHEN** Live weld `lens_det` returns `code=-3`
- **THEN** stain audit upload enqueue MAY proceed
- **AND** `LensDetConsecutiveOkFilter` behavior for subsequent frames SHALL remain unchanged

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

### Requirement: Process video final stain outcome uses temporal reduction

For process video Detect (`StainDetectSource.OFFLINE`), the authoritative dirty/clean outcome for timeline persist, summary SSE, and post-session AI Vision alerts MUST be computed from `LensStainBoxTemporalReducer` output at session end—not from any single per-frame `OpencvStainDetectResult.hasTarget()`.

Per-frame OpenCV calls and `AiStainDetectResult` mapping during sampling MUST remain unchanged for in-progress overlay and per-sample SSE.

#### Scenario: Per-frame target does not imply final dirty

- **WHEN** one sampled frame returns `hasTarget() == true` but temporal reduction yields no persistent boxes
- **THEN** the session summary MUST report clean (no persistent boxes)
- **AND** MUST NOT use that single frame alone as the final dirty verdict

#### Scenario: Summary maps to AiStainDetectResult for SSE

- **WHEN** reduction completes with persistent boxes
- **THEN** the summary `running` payload MUST be an `AiStainDetectResult` derived from the summary frame boxes and dimensions
- **AND** MUST be suitable for `AiInferenceSseJson.runningData`

### Requirement: Camera-based stain detect JNI SHALL accept cameraType parameter

Native stain-detect JNI entry points used for live and recorded camera video SHALL accept a trailing **`int cameraType`** argument with values defined by `CameraType` (`1` = BLUE_LIGHT, `2` = RED_LIGHT).

Affected methods include at minimum:

- RKNN: `nativeCreate`, `nativeRknnStainDetectFromStream`, `nativeRknnStainDetectFromJpg`, `nativeRknnStainDetectFromRgb`, `nativeRknnStainDetectFromI420`, `nativeRknnStainDetectFromJpgAndSave`, `nativeRknnStainDetectFromVideoAndSave`
- OpenCV stain: `nativeCreateOpencvStainDetectSession`, `nativeOpencvStainDetectFromJpg`, `nativeOpencvStainDetectFromRgb`, `nativeOpencvStainDetectFromNv12`, `nativeOpencvStainDetectFromI420` (deprecated)

Until red-light inference is implemented, native code MUST ignore `cameraType` and MUST preserve current blue-light behavior for all accepted values.

#### Scenario: Blue light call path unchanged

- **WHEN** the App invokes any affected JNI method with `cameraType=1`
- **THEN** detection output and performance MUST match pre-change behavior for the same inputs

### Requirement: App SHALL pass DeviceModelConfig camera type into stain JNI

The App layer SHALL pass `DeviceModelConfig.getCameraType().getValue()` into every affected native stain-detect call. For **live RTSP** samples, camera type MUST be configured on **`StreamDetectPipeline`** via control JNI at session start. For **offline** paths (`opencvStainDetectFromI420` on ExoPlayer samples, JPG paths), existing JNI call sites MUST continue passing camera type.

#### Scenario: Live native pipeline receives camera type

- **WHEN** `StreamDetectPipeline` starts on a device with `camera_type=1` in ROM
- **THEN** native stain detect in the pipeline MUST receive `cameraType=1`

#### Scenario: Process video session uses ROM camera type

- **WHEN** process video Detect runs on a device with `camera_type=2` in ROM
- **THEN** each OpenCV stain JNI call in that session MUST receive `cameraType=2`

### Requirement: Native camera type hook SHALL be documented for future work

Native implementations that receive `cameraType` SHALL include a brief comment (e.g. `TODO(camera-type)`) indicating where model selection, ROI, or threshold branching will occur for RED_LIGHT.

#### Scenario: Native source documents deferred branching

- **WHEN** a developer inspects `jni_bridge.cpp` or `opencv_stain_detect_jni.cpp` stain entry points
- **THEN** each `cameraType` parameter MUST have an adjacent comment referencing future RED_LIGHT adaptation

### Requirement: Lens det JNI summary uses unified OpenCV detect codes

When the App invokes `nativeOpencvStainDetectFromI420`, `FromJpg`, or `FromRgb`, it SHALL parse the returned summary JSON using the shared `code` table from `opencv-detect-error-codes`. Invalid session handle MUST surface as `code=-1`; invalid frame dimensions or empty paths MUST surface as `code=-2`; detection failures as `code=-3`; I/O failures as `code=-4`; saturation skip as `code=-5` with `reason=saturated_white_area_exceeds_limit`.

#### Scenario: Busy or deferred App codes remain separate

- **WHEN** the App returns `AiManager.CODE_OPENCV_STAIN_DETECT_DEFERRED` or `CODE_INFER_BUSY` without calling native
- **THEN** those App-level codes MUST NOT be conflated with native OpenCV detect `code` values

#### Scenario: Native saturation skip is FRAME_REJECTED

- **WHEN** native summary is `{"ok":false,"code":-5,"reason":"saturated_white_area_exceeds_limit","files":[]}`
- **THEN** the App MUST map the result through `OpencvDetectCodes.FRAME_REJECTED`
- **AND** MUST NOT interpret `code=-5` as a zero-point spot-size error

#### Scenario: Invalid dimensions are INVALID_INPUT not INVALID_HANDLE

- **WHEN** native summary is `{"ok":false,"code":-2,"reason":"invalid_i420_dimensions","files":[]}`
- **THEN** the App MUST classify the failure as invalid input
- **AND** MUST NOT log it as an invalid session handle

### Requirement: Production lens det coordinator publishes heavy dirty-alert side effects immediately

`OpencvStainDetectCoordinator` SHALL publish production dirty-alert side effects for heavy (`level == 2`) results only. Presentation SHALL follow **immediate** L001 coded-alarm policy via `LensHeavyContaminationWarnAlarm`, not deferred dialog on laser stop.

#### Scenario: Infer completion shows L001 immediately in eligible scope

- **WHEN** live weld OpenCV stain detect detects heavy contamination in eligible weld scope
- **THEN** the coordinator MUST publish `LensCheckResultEvent` with `level == 2`
- **AND** `LensHeavyContaminationWarnAlarm` MUST show the L001 passive warn dialog when scope and toggles allow
- **AND** MUST NOT wait for laser to turn OFF

#### Scenario: OpenCV session inactive

- **WHEN** `AiManager.isOpencvStainDetectSessionActive()` is false
- **THEN** production dirty-alert events MUST NOT be published from the live weld path

### Requirement: Lens det native path SHALL apply red-frame gate before fixed ROI pipeline

Before `runFixedRoiTargetPipeline`, `analyzeFrame` SHALL invoke the shared red-frame validator. Rejected frames MUST NOT run CLAHE/erode/blob analysis.

The legacy full-image `max_saturated_white_area_px` gate MAY be removed or superseded by the shared `overexposed` check; when both exist, the red-frame gate SHALL take precedence.

#### Scenario: Overexposed stain detect sample rejected at gate

- **WHEN** `opencvStainDetectFromI420` receives an overexposed PR1 frame
- **THEN** native MUST return before fixed ROI pipeline with `code=-5`, `reason=overexposed`
- **AND** `AiStainDetectResult` mapping MUST surface frame rejection to coordinators

#### Scenario: Purple stain detect sample rejected at gate

- **WHEN** a non-red frame is submitted to OpenCV stain detect
- **THEN** native MUST return `code=-5`, `reason=invalid_non_red`
- **AND** no `target.json` SHALL be written

### Requirement: Live RTSP stain detect results arrive via StreamDetectResultBus

For live weld and AI Vision live RTSP paths, the App SHALL map **`detect_result`** payloads from `StreamDetectResultBus` into `OpencvStainDetectResult` / `AiStainDetectResult` using the same mappers as native JNI JSON responses. Per-frame live detect MUST NOT invoke `nativeOpencvStainDetectFromI420` from Java.

#### Scenario: Bus result maps to AiStainDetectResult

- **WHEN** a live `detect_result` for lens_det contains boxes and dimensions
- **THEN** `AiStainDetectResultMapper` MUST produce an `AiStainDetectResult` suitable for overlay and SSE

#### Scenario: Offline JPG and process video still use JNI one-shot

- **WHEN** `opencvStainDetectFromJpg` or process-video `opencvStainDetectFromI420` is invoked
- **THEN** existing one-shot JNI paths MUST remain unchanged

### Requirement: Live weld lens_det DETECT_FAILED SHALL trigger stain audit upload enqueue

In Quick Mode and Engineer Mode, when `OpencvStainDetectCoordinator` receives a `StreamDetectResultBus` `lens_det` `detect_result` with `code == -3` (`OpencvDetectCodes.DETECT_FAILED`) during an active Live infer window, the coordinator SHALL invoke the stain audit upload path per `stain-audit-auto-upload` before or alongside existing consecutive-OK and L001 alert handling.

The coordinator SHALL NOT invoke stain audit upload enqueue for `code == -5` (`FRAME_REJECTED`) or for successful detections (`ok == true`, `code == 0`).

#### Scenario: Coordinator enqueues on detect failed

- **WHEN** `OpencvStainDetectCoordinator` applies a Live weld result with `code=-3` and a readable failure image
- **THEN** the stain audit upload helper SHALL be invoked exactly once for that detect result

#### Scenario: Coordinator does not enqueue on frame rejected

- **WHEN** `OpencvStainDetectCoordinator` applies a Live weld result with `code=-5`
- **THEN** the stain audit upload helper MUST NOT be invoked
- **AND** `nativeSetStreamDetectBurstMode(true)` behavior SHALL remain unchanged

