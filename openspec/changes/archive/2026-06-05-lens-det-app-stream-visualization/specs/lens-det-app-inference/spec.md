## ADDED Requirements

### Requirement: Lens det one-shot inference mirrors RKNN infer entry points

The App SHALL expose lens_det inference through one-shot APIs analogous to RKNN unified infer:

- `inferLensDetFromI420` for direct I420 buffers (live PR1, AI Vision live, process video)
- `inferLensDetFromJpg` for offline image paths

Each call SHALL invoke the corresponding `NativeBridge.nativeOpencvStainDetectFrom*` JNI on a background executor, using the active RKNN engine `handle` from `AiManager`, and SHALL NOT block the UI or Modbus threads.

#### Scenario: I420 live sample invokes native lens det

- **WHEN** a sampled I420 frame is submitted to `inferLensDetFromI420`
- **AND** `AiManager.isRunning()` is true
- **THEN** the App MUST call `nativeOpencvStainDetectFromI420` with a non-empty `outputDir`
- **AND** MUST return a parsed `LensDetDetectResult` on completion

#### Scenario: Offline JPG invokes native lens det

- **WHEN** `inferLensDetFromJpg` is called with a readable JPEG path
- **THEN** the App MUST call `nativeOpencvStainDetectFromJpg`
- **AND** MUST set `source` to a documented offline value (e.g. `offline_lens_det`)

#### Scenario: Engine not running

- **WHEN** `AiManager.isRunning()` is false
- **THEN** lens det infer MUST fail fast with `success == false`
- **AND** MUST NOT invoke native lens det JNI

### Requirement: Lens det JSON parsing follows native two-step contract

The App SHALL parse lens_det native output without re-implementing OpenCV detection:

1. Parse JNI **summary JSON** for `ok`, `code`, `reason`, and `files`.
2. When `ok == true` and `files[0]` is present, read **`target.json`** at that path and parse `name`, `x`, `y`.

The unified App type `LensDetDetectResult` SHALL expose at minimum: `success`, `code`, `message`, `targetX`, `targetY`, `imageWidth`, `imageHeight`, `source`, `timestampMs`.

#### Scenario: Successful detect reads target file

- **WHEN** summary JSON is `{"ok":true,"code":0,"files":["/data/.../target.json"]}`
- **AND** `target.json` contains `{"name":"target","x":923.4,"y":563.2}`
- **THEN** `LensDetDetectResult.success` MUST be true
- **AND** `targetX` MUST be `923.4` and `targetY` MUST be `563.2`

#### Scenario: Native failure without target file

- **WHEN** summary JSON is `{"ok":false,"code":-3,"reason":"no target meets min_target_area_px","files":[]}`
- **THEN** `success` MUST be false
- **AND** `message` MUST reflect the native reason
- **AND** the App MUST NOT attempt to read `target.json`

### Requirement: Real-time production path samples PR1 like RKNN but calls one-shot lens det

In Quick Mode and Engineer Mode, when lens_det production mode is enabled and laser is ON, the system SHALL obtain I420 frames from the same PR1 inference stream used for RKNN production inference. The system SHALL apply the **`PRODUCTION_WELD` (2000 ms)** sampling gate with a **dedicated lens_det gate instance** (separate last-accept state from the RKNN production gate). Accepted frames SHALL call `inferLensDetFromI420` on a **`lens-det-infer`** executor, not `guardedRknnStainDetectFromStream`.

#### Scenario: Production lens det respects 2000 ms gate

- **WHEN** PR1 decodes at 25 fps and laser is ON with lens_det production enabled
- **THEN** at most one lens_det infer MUST start per 2000 ms
- **AND** RKNN stream push behavior MUST remain unchanged when RKNN is enabled

#### Scenario: Laser off stops lens det production sampling

- **WHEN** laser turns OFF
- **THEN** lens_det production sampling MUST stop
- **AND** the lens_det production gate MUST reset

### Requirement: AI Vision live and process video use one-shot lens det on existing intervals

When lens_det is enabled on AI Vision live preview, the system SHALL sample at **`AI_VISION_LIVE` (500 ms)** and call `inferLensDetFromI420` without blocking RTSP or TextureView rendering. When lens_det is enabled on process video Detect, the system SHALL sample at **`AI_VISION_PROCESS_VIDEO` (500 ms)** and call `inferLensDetFromI420` on the session worker without blocking the encode/playback clock.

#### Scenario: Live 500 ms lens det does not block playback

- **WHEN** a 500 ms live sample fires during RTSP preview
- **THEN** the sample callback MUST return without waiting for lens det native completion on the main thread

#### Scenario: Process video continues when lens det infer is slow

- **WHEN** a process-video sample is accepted but lens det infer is still in flight
- **THEN** the session MUST drop starting a second lens det infer for that tick
- **AND** playback/compositing MUST continue using hold-forward visualization from the last completed lens det result

### Requirement: Lens det infer uses dedicated executor and documents concurrency with RKNN

Lens det native calls SHALL run on a dedicated single-thread executor. The App MUST NOT assume lens_det and RKNN unified infer can safely run concurrently on the same handle unless verified; until verified, lens_det production ticks SHOULD defer or skip when RKNN unified infer is in flight, logging `reason=stain_infer_busy`.

#### Scenario: Skip when RKNN unified infer busy

- **WHEN** a lens_det sample tick occurs while `AiManager.isStainInferBusy()` is true
- **THEN** the App MAY skip that lens_det sample
- **AND** MUST log the skip without resetting the lens_det sampling gate
