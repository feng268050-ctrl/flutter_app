## ADDED Requirements

### Requirement: AI Vision recorded-video path uses AI_VISION_PROCESS_VIDEO interval

When `ProcessVideoAiSession` pushes decoded frames from a **selected process video** into LensGuard preview inference (including subscribers on **`GET /v1/videos/:video_id/ai`**), the system SHALL apply the **`AiFrameSamplingInterval.AI_VISION_PROCESS_VIDEO`** (**200 ms**) gate—not the **`PRODUCTION_WELD`** (2000 ms) interval, not **`AI_VISION_LIVE`** (500 ms) for camera TextureView preview, and not an unconstrained per-frame batch loop.

#### Scenario: Recorded video infers at 200 ms

- **WHEN** a process video session accepts a decoded frame for inference
- **THEN** frames rejected by the 200 ms gate MUST NOT invoke `inferJpgToJson` or equivalent preview inference work
- **AND** frames accepted by the gate MUST be processed at most once per 200 ms on the session clock

#### Scenario: Not batch-all-frames-before-play

- **WHEN** the user starts watching a selected recording
- **THEN** the system MUST NOT run a whole-file loop that completes all frame inferences before any overlay is shown
