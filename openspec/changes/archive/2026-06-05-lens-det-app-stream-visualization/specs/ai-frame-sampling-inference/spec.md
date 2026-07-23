## ADDED Requirements

### Requirement: Lens det uses dedicated sampling gate instances per interval

For each named interval used by lens_det (`PRODUCTION_WELD`, `AI_VISION_LIVE`, `AI_VISION_PROCESS_VIDEO`), the system SHALL maintain a **separate `AiFrameSamplingGate` instance** for lens_det that does not share last-accept timestamps with the RKNN gate for the same interval or with other lens_det intervals.

#### Scenario: Lens det production gate independent of RKNN production gate

- **WHEN** RKNN production gate accepts a frame at T=0
- **AND** lens_det production gate is reset or has no prior accept
- **THEN** lens_det MAY accept its next eligible frame according to its own 2000 ms gate without being blocked by the RKNN accept timestamp

#### Scenario: Lens det gate reset on stream stop

- **WHEN** the PR1 inference stream stops or AI Vision live sampling stops
- **THEN** the corresponding lens_det sampling gate MUST reset using the same lifecycle boundaries as the RKNN gate for that path

### Requirement: Lens det busy-drop is orthogonal to interval gating

When a frame is accepted by a lens_det sampling gate but lens det infer cannot start (prior infer in flight or RKNN busy deferral), the system SHALL drop that infer attempt without resetting the lens_det gate timestamp unless explicitly documented otherwise.

#### Scenario: Accepted frame dropped when lens det busy

- **WHEN** lens_det gate accepts a PR1 frame and a prior `inferLensDetFromI420` is still running
- **THEN** the new infer MUST NOT start
- **AND** the next eligible frame MUST be determined by subsequent decode callbacks and the gate interval
