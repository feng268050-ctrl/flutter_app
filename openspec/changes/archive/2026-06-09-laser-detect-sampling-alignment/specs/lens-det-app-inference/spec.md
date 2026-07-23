## MODIFIED Requirements

### Requirement: Live weld path samples PR1 and calls OpenCV stain detect

In Quick Mode and Engineer Mode, when laser is ON and the OpenCV session is active, **`OpencvStainDetectCoordinator`** SHALL obtain I420 frames from `LivePr1InferenceStreamClient`. The system SHALL apply **`LIVE_WELD` (500 ms)** via `tryAcceptOpencvLiveWeldInferSample` in **normal** sampling mode. When **burst sampling mode** is active (see `laser-detect-frame-rejected-burst`), the live weld gate SHALL use **`FRAME_REJECTED_BURST` (100 ms)** instead. Accepted frames SHALL call `opencvStainDetectFromI420` with `StainDetectSource.LIVE` on a background executor. There is **no fixed maximum sample count** per laser-on event; sampling continues while laser is ON.

#### Scenario: Live weld respects 500 ms gate in normal mode

- **WHEN** PR1 decodes at 25 fps, laser is ON, OpenCV session active, and burst mode is not active
- **THEN** at most one OpenCV stain detect MUST start per 500 ms

#### Scenario: Live weld uses 100 ms gate in burst mode

- **WHEN** burst sampling mode is active after a `code=-5` result
- **THEN** the live weld gate MUST accept at most one stain detect per 100 ms (subject to busy-drop)

#### Scenario: Laser off stops live weld sampling

- **WHEN** laser turns OFF
- **THEN** live weld OpenCV sampling MUST stop
- **AND** `resetOpencvLiveWeldFrameSampling()` MUST run
- **AND** burst sampling mode MUST reset to normal
