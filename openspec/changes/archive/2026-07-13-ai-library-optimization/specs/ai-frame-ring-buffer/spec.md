## ADDED Requirements

### Requirement: CentralScheduler SHALL use dual-slot frame ring buffer

`CentralScheduler` (formerly in `main.cpp`) MUST replace triple BGR `clone()` frame handoff with a `FrameRingBuffer` of at least two slots. `publish()` MUST write BGR `cv::Mat` and PTS into the next slot and swap write index; `consume()` MUST return the latest ready slot without deep-copying the `cv::Mat` (relying on OpenCV reference counting).

#### Scenario: Stain path reduces frame copies

- **WHEN** `LENS_INFER_TIMING=1` build runs live stain detect at 1920×1080
- **THEN** reported `frame_copy_ms` MUST decrease by at least 50% versus pre-optimization baseline or approach zero
- **AND** live stain detect functionality MUST pass regression

#### Scenario: Worker clones only when mutating frame

- **WHEN** `worker_stain` needs to draw annotations on the frame
- **THEN** it MUST `clone()` once inside the worker thread
- **AND** MUST NOT require additional clones in `pushFrame` or `waitFrame`

### Requirement: Frame ring buffer SHALL be toggleable for rollback

The build MUST expose a CMake or compile-time option `LWS_FRAME_RING_BUFFER` (default ON). When OFF, the scheduler MUST fall back to the prior `clone()`-based frame handoff path.

#### Scenario: Rollback restores clone path

- **WHEN** `LWS_FRAME_RING_BUFFER=OFF` is set and `make ai` completes
- **THEN** live stain detect MUST function using the legacy clone path
- **AND** MUST NOT require code changes beyond the build flag
