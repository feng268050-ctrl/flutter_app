## MODIFIED Requirements

### Requirement: Optional AI inference must not dominate the video pipeline

When lens-guard inference is enabled, frame processing from the decoding path MUST NOT unboundedly stall decoding; overloaded conditions SHALL degrade AI delivery (bounded queue or configurable decimation) before dropping video decoding entirely unless product policy states otherwise. Production weld inference SHALL use a fixed 2000 ms sample interval; AI Vision live inference SHALL use a fixed 500 ms sample interval via the shared frame-sampling gate abstraction.

#### Scenario: High CPU contention during AI and video

- **WHEN** both video decode callbacks and inference frame delivery are active
- **THEN** video playback SHALL remain the primary uninterrupted path
- **AND** production-mode sub-stream decode SHALL NOT push every decoded frame to LensGuard

#### Scenario: AI Vision live preview sampling

- **WHEN** AI Vision live preview runs lens-guard inference
- **THEN** inference input SHALL be sampled at approximately 500 ms intervals
- **AND** SHALL use the same frame-sampling gate contract as production mode with the `AI_VISION_LIVE` profile
