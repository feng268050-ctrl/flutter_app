## ADDED Requirements

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

## MODIFIED Requirements

### Requirement: Live weld path samples PR1 and calls OpenCV stain detect

In Quick Mode and Engineer Mode, when laser is ON and the OpenCV session is active, **`OpencvStainDetectCoordinator`** SHALL obtain I420 frames from `LivePr1InferenceStreamClient`. The system SHALL apply **`LIVE_WELD` (500 ms)** via `tryAcceptOpencvLiveWeldInferSample` in **normal** sampling mode. When **burst sampling mode** is active (see `laser-detect-frame-rejected-burst`), the live weld gate SHALL use **`FRAME_REJECTED_BURST` (100 ms)** instead. Accepted frames SHALL call `opencvStainDetectFromI420` with `StainDetectSource.LIVE` on a background executor. There is **no fixed maximum sample count** per laser-on event; sampling continues while laser is ON.

Red-frame rejections (`overexposed`, `invalid_non_red`) SHALL count as `code=-5` outcomes for burst entry per `laser-detect-frame-rejected-burst`.

#### Scenario: Live weld respects 500 ms gate in normal mode

- **WHEN** PR1 decodes at 25 fps, laser is ON, OpenCV session active, and burst mode is not active
- **THEN** at most one OpenCV stain detect MUST start per 500 ms

#### Scenario: Live weld uses 100 ms gate in burst mode

- **WHEN** burst sampling mode is active after a `code=-5` result (including `reason=overexposed`)
- **THEN** the live weld gate MUST accept at most one stain detect per 100 ms (subject to busy-drop)

#### Scenario: Laser off stops live weld sampling

- **WHEN** laser turns OFF
- **THEN** live weld OpenCV sampling MUST stop
- **AND** `resetOpencvLiveWeldFrameSampling()` MUST run
- **AND** burst sampling mode MUST reset to normal
