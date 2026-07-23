## MODIFIED Requirements

### Requirement: Process video lens_det gate (not zero_point)

Process-video offline OpenCV detection SHALL use `lens_det` with `tryAcceptLensDetProcessVideoInferSample()` and `AI_VISION_PROCESS_VIDEO` (500 ms). The system MUST NOT add a process-video zero point sampling gate or `inferZeroPointFromI420` on the process video path.

#### Scenario: Independent from RKNN gate

- **WHEN** the RKNN process-video gate accepts at `t0`
- **THEN** the lens_det process-video gate MUST still be eligible on its own last-accept clock

#### Scenario: Production zero point unchanged

- **WHEN** laser turns ON
- **THEN** `ZeroPointDetectCoordinator` MUST still use `ZERO_POINT_ON_LASER` deadlines
- **AND** MUST NOT use the process-video lens_det gate
