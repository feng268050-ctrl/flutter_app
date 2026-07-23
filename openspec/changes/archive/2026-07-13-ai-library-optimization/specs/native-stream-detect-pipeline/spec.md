## ADDED Requirements

### Requirement: CentralScheduler stain path SHALL integrate frame ring buffer

The native stain scheduling path (`CentralScheduler` / `central_scheduler.cpp`) MUST use `FrameRingBuffer` for BGR frame handoff between decode and stain worker threads, eliminating redundant `cv::Mat::clone()` on the hot path.

#### Scenario: Ring buffer enabled by default

- **WHEN** `libai.so` is built with default options
- **THEN** stain frame handoff MUST use the ring buffer implementation
- **AND** `LENS_INFER_TIMING` MUST report reduced `frame_copy_ms` versus clone baseline

### Requirement: Stain worker SHALL use joinable lifecycle not detach

Stain detect worker threads MUST be managed by a `StainWorkerPool` (or equivalent) that supports `shutdown()` with queue drain and `join()`. `std::thread(...).detach()` MUST NOT be used for stain workers.

#### Scenario: Clean shutdown on scheduler destroy

- **WHEN** `CentralScheduler` is destroyed or native session stops
- **THEN** stain worker threads MUST be joined after pending work completes or is cancelled
- **AND** MUST NOT leave detached threads accessing freed scheduler state

## MODIFIED Requirements

### Requirement: Pipeline publishes lightweight events to Java

After each completed detect sample or pipeline state change, the native layer MUST publish events through a **single JNI uplink callback** with types including:

- `combined_frame` — per sampled frame, all module results in one JSON with `frame_pts_ms` and `modules` map (preferred for live detect samples)
- `detect_result` — per-module parsed detection JSON, `timestampMs`, `frame_id`, module id (deprecated as separate native invocations; MAY remain as bus-dispatched events parsed from `combined_frame`)
- `pipeline_state` — `running`, `idle`, `error`, reconnect reason
- `session_start` / `session_stop` — `sessionId`, `source`, `samplingIntervalMs`
- `error` — `code`, `message`

For each gated detect sample frame with multiple active modules, native MUST invoke the JNI uplink callback **once** with `combined_frame`, not once per module.

The pipeline MUST NOT publish raw YUV or bitmap payloads to Java.

#### Scenario: Detect result published after sample

- **WHEN** a gated detect sample completes in native code
- **THEN** Java MUST receive detection events on the registered uplink callback
- **AND** the payload MUST include `timestampMs` / `frame_pts_ms` and detection JSON fields per existing native API contracts

#### Scenario: Stream error does not crash Java playback

- **WHEN** the C++ RTSP session fails or decode errors occur
- **THEN** the pipeline MUST publish `pipeline_state` or `error` events
- **AND** Java `EasyPlayerClient` playback on a separate RTSP session MUST continue unaffected

#### Scenario: One JNI invocation per multi-module sample

- **WHEN** lens_det and zero_point both complete on the same gated sample frame
- **THEN** native MUST publish one `combined_frame` event
- **AND** MUST NOT invoke the JNI callback separately for each module on that frame
