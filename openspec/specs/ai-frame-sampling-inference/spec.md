# ai-frame-sampling-inference Specification

## Purpose

Shared time-based gate for live LensGuard frame push: production sub-stream (I420) and AI Vision live preview (TextureView bitmap) use different `AiFrameSamplingInterval` code constants.
## Requirements
### Requirement: Configurable frame-sampling gate before LensGuard push

The system SHALL provide a reusable frame-sampling gate for paths where Java still owns frame input. For **live RTSP PR1 detect** (production weld and AI Vision live after migration), sampling SHALL occur in **`StreamDetectPipeline`**; Java gates for `LIVE_WELD`, `AI_VISION_LIVE`, `ZERO_POINT_ON_LASER`, and `FRAME_REJECTED_BURST` on live PR1 MUST NOT accept I420 or bitmap frames for detect after migration.

Java gates SHALL remain for **RKNN/LensGuard push** where still used, **process video** (500 ms), and any transitional paths explicitly flagged until Phase 3 completion.

#### Scenario: Live PR1 detect does not use Java gate

- **WHEN** laser is ON and live weld stain detect is active via native pipeline
- **THEN** Java live-weld I420 sampling gates MUST NOT accept PR1 frames for stain detect
- **AND** native scheduling MUST enforce the 500 ms interval

#### Scenario: Process video gate unchanged

- **WHEN** `ProcessVideoAiSession` schedules a sample for detect
- **THEN** `tryAcceptOpencvProcessVideoInferSample` MUST still enforce `AI_VISION_PROCESS_VIDEO` (500 ms)

### Requirement: Standard frame sampling intervals

The system SHALL define named intervals in `AiFrameSamplingInterval` (code constants; not user-configurable):

| Constant | Interval | Use case |
|----------|----------|----------|
| `LIVE_WELD` | **500 ms** | Live PR1 OpenCV stain detect while welding — **enforced in native pipeline** |
| `AI_VISION_LIVE` | 500 ms | AI Vision live inference — **enforced in native pipeline** after Phase 3 |
| `AI_VISION_PROCESS_VIDEO` | 500 ms | AI Vision selected process video detect sampling — **Java gate** |
| `ZERO_POINT_ON_LASER` | 500 ms | Laser-on zero-point detect — **enforced in native pipeline** |
| `FRAME_REJECTED_BURST` | 100 ms | Live PR1 zero_point + lens_det burst — **enforced in native pipeline** |

#### Scenario: Live weld interval in normal mode

- **WHEN** native pipeline runs live weld stain detect in normal sampling mode
- **THEN** the effective gate SHALL be `LIVE_WELD` (**500 ms**)

#### Scenario: Zero point interval in normal mode

- **WHEN** a laser-on zero-point round accepts samples in normal mode via native pipeline
- **THEN** the effective gate SHALL be `ZERO_POINT_ON_LASER` (500 ms) between accepted attempts

#### Scenario: Live weld constant value

- **WHEN** code reads `AiFrameSamplingInterval.LIVE_WELD.getIntervalMs()`
- **THEN** the value SHALL be `500L`

### Requirement: Gate reset on stream lifecycle boundaries

The system SHALL reset Java-side sampling gates when the corresponding **Java-owned** inference input stops or restarts. Native pipeline sampling state SHALL reset on native `stopStreamDetect`, laser OFF, and session release independently of Java preview gates.

#### Scenario: Production native pipeline stops

- **WHEN** native detect pipeline stops (laser OFF, release, or coordinator disable)
- **THEN** native sampling and burst state SHALL reset
- **AND** Java live-weld gates if any remain for transitional paths SHALL reset

#### Scenario: AI Vision live Java preview stops

- **WHEN** AI Vision stops live preview playback (`stopAiFrameSampling` or fragment inactive)
- **THEN** Java AI Vision live gates for any legacy path SHALL reset
- **AND** native AI Vision live detect session MAY stop per product lifecycle rules

### Requirement: AI Vision recorded-video path uses AI_VISION_PROCESS_VIDEO interval

When `ProcessVideoAiSession` samples a **selected process video** for detect (including subscribers on **`GET /v1/videos/:video_id/ai`**), the system SHALL apply the **`AiFrameSamplingInterval.AI_VISION_PROCESS_VIDEO`** gate (**200 ms** in code)—not **`PRODUCTION_WELD`**, not **`AI_VISION_LIVE`**, and not an unconstrained per-frame loop.

Detect work SHALL use the OpenCV process-video gate (`tryAcceptOpencvProcessVideoInferSample`) when OpenCV stain detect is active, independent of RKNN unified infer gates.

#### Scenario: Recorded video detects at process-video interval

- **WHEN** a process video session schedules a sample for detect
- **THEN** samples rejected by the process-video gate MUST NOT invoke OpenCV stain detect
- **AND** accepted samples MUST be processed at most once per `AI_VISION_PROCESS_VIDEO` interval on the session sample grid

#### Scenario: Not batch-all-frames-before-play

- **WHEN** the user starts Detect on a selected recording
- **THEN** the system MUST NOT run a whole-file loop that completes all detects before ExoPlayer playback and overlay are shown

### Requirement: In-flight unified infer drop is orthogonal to interval gating

For **live RTSP native pipeline** paths, when a gated sample cannot start because a prior detect for that module is in flight, the native pipeline SHALL drop that sample without resetting the sampling timestamp unless documented otherwise.

For **OpenCV process-video detect** and **offline** paths, existing Java busy-drop rules remain unchanged; **ExoPlayer playback MUST NOT stall**.

For **AI Vision overlay** on live RTSP, overlay MUST follow last completed bus result with documented stale timeout; MUST NOT hold-forward boxes incorrectly when the latest completed sample has none.

#### Scenario: Native busy drop on live weld

- **WHEN** native pipeline accepts a live-weld gate tick and OpenCV stain detect is still running for the prior sample
- **THEN** the new sample MUST NOT start
- **AND** the next eligible sample MUST be determined by native gate on subsequent decode callbacks

#### Scenario: Process video playback does not wait for detect

- **WHEN** OpenCV process-video detect is in flight for sample `T`
- **THEN** ExoPlayer MUST continue advancing
- **AND** AI Vision overlay MUST show boxes only per the sample at playback position

### Requirement: Zero-point on-laser sampling interval

The system SHALL define **`AiFrameSamplingInterval.ZERO_POINT_ON_LASER`** with interval **500 ms** for the laser-triggered zero-point detect task. This interval SHALL use a **separate gate or scheduler instance** so zero-point sampling does not share last-accept timestamps with AI Vision live preview, process-video detect, or production weld gates.

#### Scenario: Named constant exists

- **WHEN** the App enumerates `AiFrameSamplingInterval`
- **THEN** `ZERO_POINT_ON_LASER` SHALL be present with `getIntervalMs() == 500L`

#### Scenario: Independent gate lifecycle

- **WHEN** a zero-point task completes or is cancelled
- **THEN** any zero-point-specific sampling state SHALL reset
- **AND** production (`PRODUCTION_WELD`) and AI Vision live gates SHALL remain unaffected

### Requirement: FRAME_REJECTED burst interval for coordinated live detect

The system SHALL define `FRAME_REJECTED_BURST` with interval **100 ms** for coordinated live PR1 detect paths when burst sampling mode is active. Burst enforcement for live PR1 SHALL be in **`StreamDetectPipeline`**, not Java `AiFrameSamplingGate` instances.

#### Scenario: Burst interval constant

- **WHEN** burst sampling mode is active on the live PR1 weld path in native pipeline
- **THEN** participating modules MUST use `FRAME_REJECTED_BURST` (100 ms)

