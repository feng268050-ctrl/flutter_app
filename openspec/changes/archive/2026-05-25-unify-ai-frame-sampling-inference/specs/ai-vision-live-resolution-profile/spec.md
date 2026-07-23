## MODIFIED Requirements

### Requirement: Main-stream recorder is not a production inference source

The virtual-surface `EasyPlayerClientManger` used for process video recording SHALL NOT be the only component supplying I420 frames to `LensGuardManager` during Quick Mode or Engineer Mode welding.

#### Scenario: Inference without record session

- **WHEN** laser is ON and `LensGuardManager.isRunning()` is true but `EasyPlayerClientManger` is not recording
- **THEN** the sub-stream inference client SHALL deliver decoded I420 to `LensGuardManager.onI420Frame`
- **AND** only frames accepted by the production frame-sampling gate (2000 ms) SHALL proceed to `guardedPushFrame`
- **AND** this behavior SHALL differ from AI Vision live preview, which uses the `AI_VISION_LIVE` profile (500 ms) on the TextureView sampling path
