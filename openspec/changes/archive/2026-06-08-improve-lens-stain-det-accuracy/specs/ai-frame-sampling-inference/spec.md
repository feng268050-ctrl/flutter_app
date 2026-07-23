## MODIFIED Requirements

### Requirement: In-flight unified infer drop is orthogonal to interval gating

Frame sampling gates SHALL continue to enforce `LIVE_WELD`, `AI_VISION_LIVE`, and `AI_VISION_PROCESS_VIDEO` intervals. For **RKNN stain detect** paths, when an accepted frame cannot start because a prior `rknnStainDetectFromI420` or `rknnStainDetectFromJpg` is in flight, the system SHALL drop that frame without resetting the sampling gate timestamp unless the implementation explicitly documents otherwise.

For **OpenCV process-video detect**, when an accepted sample cannot start because a prior `opencvStainDetectFromI420` is in flight, the session SHALL drop that sample similarly; **ExoPlayer playback MUST NOT stall**.

For **AI Vision overlay** (recorded video and live RTSP), the system MUST NOT hold-forward boxes from earlier samples when a later sample completes without boxes or when busy infer skips a sample grid point. Overlay MUST follow `ai-vision-recorded-video-realtime` and `ai-vision-live-inference-overlay`.

#### Scenario: Process video playback does not wait for detect

- **WHEN** OpenCV process-video detect is in flight for sample `T`
- **THEN** ExoPlayer MUST continue advancing
- **AND** AI Vision overlay MUST show boxes only per the sample at playback position (no hold-forward)

#### Scenario: Interval accepted but RKNN busy

- **WHEN** `tryAccept` returns true for a live-weld frame and RKNN stain detect is in flight
- **THEN** the frame MUST NOT start a new RKNN stain detect
- **AND** the next eligible frame MUST be determined by the sampling gate on subsequent decode callbacks

#### Scenario: Gate reset on stream stop unchanged

- **WHEN** the live PR1 inference stream stops
- **THEN** the live-weld sampling gate MUST still reset per existing requirement
- **AND** any in-flight RKNN or OpenCV stain detect lock MUST be cleared or allowed to complete with timeout

#### Scenario: AI Vision live display does not wait for detect

- **WHEN** the `AI_VISION_LIVE` gate accepts a TextureView sample but OpenCV stain detect is in flight
- **THEN** RTSP playback and `TextureView` rendering MUST continue without blocking
- **AND** overlay MUST remain on the last **completed** live stain-detect sample until the in-flight sample finishes (MUST NOT hold-forward boxes from older samples when the latest completed sample has none)
