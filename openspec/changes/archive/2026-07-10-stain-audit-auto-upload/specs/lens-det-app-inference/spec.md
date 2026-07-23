## ADDED Requirements

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

## MODIFIED Requirements

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
