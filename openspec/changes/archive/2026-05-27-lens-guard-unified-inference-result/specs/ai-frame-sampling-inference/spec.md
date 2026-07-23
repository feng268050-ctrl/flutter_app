## ADDED Requirements

### Requirement: In-flight unified infer drop is orthogonal to interval gating

Frame sampling gates (`AiFrameSamplingGate`) SHALL continue to enforce `PRODUCTION_WELD`, `AI_VISION_LIVE`, and `AI_VISION_PROCESS_VIDEO` intervals. When an accepted frame cannot start unified infer because a prior `inferFromI420` or `inferFromJpg` is in flight, the system SHALL drop that frame without resetting the sampling gate timestamp unless the implementation explicitly documents otherwise.

#### Scenario: Interval accepted but infer busy

- **WHEN** `tryAccept` returns true for a production frame and unified infer is in flight
- **THEN** the frame MUST NOT start a new unified infer
- **AND** the next eligible frame MUST be determined by the sampling gate on subsequent decode callbacks

#### Scenario: Gate reset on stream stop unchanged

- **WHEN** the production inference stream stops
- **THEN** the production sampling gate MUST still reset per existing requirement
- **AND** any in-flight unified infer lock MUST be cleared or allowed to complete with timeout

#### Scenario: Process video encode does not wait for infer

- **WHEN** the `AI_VISION_PROCESS_VIDEO` gate accepts a sample but unified infer is in flight
- **THEN** the process-video encode clock MUST continue compositing and streaming
- **AND** compositing MUST use hold-forward overlay from the latest completed sample strictly before the skipped sample time

#### Scenario: AI Vision live display does not wait for infer

- **WHEN** the `AI_VISION_LIVE` gate accepts a TextureView sample but unified infer is in flight
- **THEN** RTSP playback and `TextureView` rendering MUST continue without blocking
- **AND** overlay MUST use hold-forward boxes from the last completed live unified result
