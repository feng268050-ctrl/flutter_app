## RENAMED Requirements

- FROM: `### Requirement: Standard frame sampling intervals` (constant `PRODUCTION_WELD`)
- TO: `### Requirement: Standard frame sampling intervals` (constant `LIVE_WELD`)

## MODIFIED Requirements

### Requirement: Standard frame sampling intervals

The system SHALL define named intervals in `AiFrameSamplingInterval` (code constants; not user-configurable):

| Constant | Interval | Use case |
|----------|----------|----------|
| `LIVE_WELD` | 2000 ms | Live PR1 sub-stream stain detect while welding (Quick / Engineer) |
| `AI_VISION_LIVE` | 500 ms | AI Vision live preview stain detect from TextureView |
| `AI_VISION_PROCESS_VIDEO` | 200 ms | AI Vision selected process video detect sampling |
| `ZERO_POINT_ON_LASER` | 500 ms | Laser-on zero-point detect task (scheduled samples) |

#### Scenario: Live weld interval

- **WHEN** live OpenCV stain detect runs for Quick Mode or Engineer Mode with laser ON
- **THEN** the effective sample interval SHALL be `AiFrameSamplingInterval.LIVE_WELD` (2000 ms)

#### Scenario: AI Vision live interval

- **WHEN** AI Vision live preview stain detect is active
- **THEN** the effective sample interval SHALL be `AiFrameSamplingInterval.AI_VISION_LIVE` (500 ms)

#### Scenario: Zero-point on-laser interval

- **WHEN** the laser-on zero-point detect task schedules samples
- **THEN** sample spacing SHALL follow `AiFrameSamplingInterval.ZERO_POINT_ON_LASER` (500 ms) from the first sample at `T₀ + 500ms`

### Requirement: In-flight unified infer drop is orthogonal to interval gating

Frame sampling gates SHALL continue to enforce `LIVE_WELD`, `AI_VISION_LIVE`, and `AI_VISION_PROCESS_VIDEO` intervals. For **RKNN stain detect** paths, when an accepted frame cannot start because a prior `rknnStainDetectFromI420` or `rknnStainDetectFromJpg` is in flight, the system SHALL drop that frame without resetting the sampling gate timestamp unless documented otherwise.

For **OpenCV stain detect**, when an accepted sample cannot start because a prior `opencvStainDetectFromI420` is in flight, the session SHALL drop that sample similarly; **video playback and RTSP decode MUST NOT stall**.

#### Scenario: Interval accepted but RKNN busy

- **WHEN** `tryAcceptRknnLiveWeldInferSample` returns true and RKNN stain detect is in flight
- **THEN** the frame MUST NOT start a new RKNN stain detect
- **AND** the next eligible frame MUST be determined by the sampling gate on subsequent decode callbacks

#### Scenario: Gate reset on stream stop unchanged

- **WHEN** the live PR1 inference stream stops
- **THEN** the corresponding OpenCV/RKNN sampling gate MUST reset per existing requirement

### Requirement: Lens det uses dedicated sampling gate instances per interval

For each named interval used by OpenCV stain detect (`LIVE_WELD`, `AI_VISION_LIVE`, `AI_VISION_PROCESS_VIDEO`), the system SHALL maintain **separate gate state** for OpenCV vs RKNN so last-accept timestamps do not cross paths.

#### Scenario: OpenCV live weld gate independent of RKNN live weld gate

- **WHEN** the OpenCV live-weld gate accepts a frame at T=0
- **AND** the RKNN live-weld gate is reset or has no prior accept
- **THEN** RKNN MAY accept its next eligible frame according to its own 2000 ms gate without being blocked by the OpenCV accept timestamp

## REMOVED Requirements

### Requirement: Lens det busy-drop is orthogonal to interval gating

**Reason**: Superseded by OpenCV stain detect busy-drop semantics in the in-flight requirement; lens_det naming removed from code.

**Migration**: Use OpenCV gate + `isOpencvStainDetectBusy()` behavior documented in `lens-det-app-inference`.
