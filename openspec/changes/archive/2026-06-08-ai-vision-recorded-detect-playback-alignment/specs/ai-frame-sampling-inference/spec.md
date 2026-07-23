## MODIFIED Requirements

### Requirement: Standard frame sampling intervals

The system SHALL define named intervals in `AiFrameSamplingInterval` (code constants; not user-configurable):

| Constant | Interval | Use case |
|----------|----------|----------|
| `PRODUCTION_WELD` | 2000 ms | Quick Mode and Engineer Mode sub-stream live inference |
| `AI_VISION_LIVE` | 500 ms | AI Vision live preview inference from TextureView |
| `AI_VISION_PROCESS_VIDEO` | 200 ms | AI Vision selected process video detect sampling |
| `ZERO_POINT_ON_LASER` | 500 ms | Laser-on zero-point detect task (scheduled samples) |

#### Scenario: Production interval

- **WHEN** live inference runs for Quick Mode or Engineer Mode with laser ON
- **THEN** the effective sample interval SHALL be `AiFrameSamplingInterval.PRODUCTION_WELD` (2000 ms)

#### Scenario: AI Vision live interval

- **WHEN** AI Vision live preview inference is active
- **THEN** the effective sample interval SHALL be `AiFrameSamplingInterval.AI_VISION_LIVE` (500 ms)

#### Scenario: Zero-point on-laser interval

- **WHEN** the laser-on zero-point detect task schedules samples
- **THEN** sample spacing SHALL follow `AiFrameSamplingInterval.ZERO_POINT_ON_LASER` (500 ms) from the first sample at `T₀ + 500ms`

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

Frame sampling gates SHALL continue to enforce `PRODUCTION_WELD`, `AI_VISION_LIVE`, and `AI_VISION_PROCESS_VIDEO` intervals. For **RKNN unified infer** paths, when an accepted frame cannot start because a prior `inferFromI420` or `inferFromJpg` is in flight, the system SHALL drop that frame without resetting the sampling gate timestamp unless documented otherwise.

For **OpenCV process-video detect**, when an accepted sample cannot start because a prior `opencvStainDetectFromI420` is in flight, the session SHALL drop that sample similarly; **ExoPlayer playback MUST NOT stall**.

#### Scenario: Process video playback does not wait for detect

- **WHEN** OpenCV process-video detect is in flight for sample `T`
- **THEN** ExoPlayer MUST continue advancing
- **AND** overlay MUST use hold-forward from the last completed timeline sample

#### Scenario: Interval accepted but infer busy

- **WHEN** `tryAccept` returns true for a production frame and unified infer is in flight
- **THEN** the frame MUST NOT start a new unified infer
- **AND** the next eligible frame MUST be determined by the sampling gate on subsequent decode callbacks

#### Scenario: Gate reset on stream stop unchanged

- **WHEN** the production inference stream stops
- **THEN** the production sampling gate MUST still reset per existing requirement
- **AND** any in-flight unified infer lock MUST be cleared or allowed to complete with timeout
