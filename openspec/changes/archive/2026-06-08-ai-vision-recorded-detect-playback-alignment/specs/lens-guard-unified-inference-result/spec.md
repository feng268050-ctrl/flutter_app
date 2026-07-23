## RENAMED Requirements

- FROM: `### Requirement: Hold-forward overlay policy applies to all unified infer consumers`
- TO: `### Requirement: Hold-forward overlay policy applies to all detect consumers`

## MODIFIED Requirements

### Requirement: Hold-forward overlay policy applies to all detect consumers

Callers that render detection on a moving video stream (AI Vision live RTSP, process-video ExoPlayer playback, production PR1 monitoring, HTTP SSE `/v1/camera/ai` and `/v1/videos/:id/ai`) SHALL use the same hold-forward rule: use the latest **completed** result until a newer sample completes, without blocking the video path on detect/infer work.

Rendering MUST be **client-side** for display and LAN: map stain-detect / timeline results to overlay geometry (`toOverlayBoxes()` or equivalent) or serialize to SSE JSON. The device MUST NOT burn boxes or status text into frame bitmaps for AI Vision preview, process-video preview, or HTTP `/ai` routes. Production Quick/Engineer modes MUST NOT run a compositor encoder for HTTP; when `/v1/camera/ai` SSE subscribers exist, production SHALL push completed samples to the SSE publisher only.

For **recorded-video** Detect and Replay, box normalization and fit-center mapping SHALL use **`AiDetectOverlayGeometry`** so detect-frame pixel coordinates (which MAY use a lower resolution than the displayed source video) map correctly onto the ExoPlayer letterboxed region in `DetectionOverlayView`.

Recorded video uses timeline `findFrameAt(ExoPlayer position)`; live uses a monotonic completed-sample snapshot—semantics are equivalent for forward playback.

#### Scenario: Recorded video overlay uses shared mapper

- **WHEN** `ProcessVideoAiTimeline.Frame.toOverlayBoxes()` is called for display
- **THEN** pixel boxes MUST be normalized with `AiDetectOverlayGeometry.toNormalizedRect` using the frame's `imageWidth` and `imageHeight`
- **AND** `DetectionOverlayView` MUST map normalized boxes through the fit-center video content rect for the player view

#### Scenario: Live and recorded share overlay schema

- **WHEN** live preview and recorded-video samples complete on their respective detect paths
- **THEN** SSE and timeline consumers MUST expose consistent box and status fields for overlay rendering
- **AND** overlay renderers MUST use `toOverlayBoxes()` or `AiDetectOverlayGeometry` rather than ad-hoc scaling

#### Scenario: No bitmap compositor on device for HTTP

- **WHEN** a LAN client subscribes to `GET /v1/camera/ai` or `GET /v1/videos/<id>/ai`
- **THEN** the device MUST emit SSE lifecycle/`running` events
- **AND** MUST NOT encode composited H.264 for that subscription

### Requirement: Shared overlay conversion

Stain-detect result types (`AiStainDetectResult`, `ProcessVideoAiTimeline`, and RKNN `LensGuardInferenceResult` where still used) SHALL provide conversion to `DetectionOverlayView.Box` lists using **`AiDetectOverlayGeometry`** normalization rules (pixel to 0–1 when image dimensions are known), consistent with `AiVisionOverlayParser`.

#### Scenario: Overlay draw

- **WHEN** `imageWidth` and `imageHeight` are positive
- **THEN** `toOverlayBoxes()` MUST produce normalized coordinates suitable for `DetectionOverlayView` with an optional fit-center content rect
