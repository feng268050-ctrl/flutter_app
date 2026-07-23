## MODIFIED Requirements

### Requirement: AI Vision live inference runs on a background worker

When AI Vision live RTSP preview is active and preview detection is enabled, the system SHALL sample the `TextureView` at `AiFrameSamplingInterval.AI_VISION_LIVE` (500 ms) and SHALL submit **`AiManager.opencvStainDetectFromI420`** (after I420 conversion) on a background executor when the OpenCV session is active. RTSP decode, `TextureView` rendering, and overlay updates MUST NOT block waiting for detect to complete.

#### Scenario: Texture sample does not stall playback

- **WHEN** a 500 ms sample fires while the live player is displaying frames
- **THEN** the main-thread sample callback MUST return without waiting for OpenCV detect completion
- **AND** the live video surface MUST continue updating from RTSP

### Requirement: AI Vision live uses client-side DetectionOverlayView

Live preview MUST render detection boxes on **`DetectionOverlayView`** above the video surface using hold-forward semantics from the latest completed OpenCV stain detect result mapped to **`AiStainDetectResult`**. The system MUST NOT burn boxes into the camera bitmap for live preview (same client-overlay model as process-video Detect and HTTP SSE).

Detection status MAY appear in HUD widgets or overlay-adjacent UI; the system MUST NOT require on-frame compositing for live preview.

#### Scenario: Overlay uses hold-forward

- **WHEN** sample `N` is detecting and sample `N-1` completed with boxes
- **THEN** `DetectionOverlayView` MUST show sample `N-1` boxes until sample `N` completes

#### Scenario: No composited bitmap path for live tab

- **WHEN** AI Vision live preview detection is enabled
- **THEN** the system MUST NOT use `ProcessVideoAiFrameRenderer` or H.264 compositor encode solely for on-screen live preview

### Requirement: AI Vision live uses hold-forward overlay from stain detect results

The system SHALL maintain the latest completed stain detect result from live sampling. Overlay renderers MUST map `OpencvStainDetectResult` / `AiStainDetectResult` boxes through **`AiDetectOverlayGeometry`** when dimensions differ from display size.

#### Scenario: New result replaces overlay

- **WHEN** sample `N` completes with new boxes
- **THEN** overlay MUST update to sample `N` boxes on subsequent frames

### Requirement: Live path drops overlapping samples without blocking display

While OpenCV stain detect is in flight, newly accepted `AI_VISION_LIVE` samples MUST NOT start a second detect. Live display MUST keep hold-forward overlay from the last completed sample.

#### Scenario: Busy skips 500 ms sample

- **WHEN** the 500 ms gate accepts a sample but `isOpencvStainDetectBusy()` is true
- **THEN** the new detect MUST NOT start
- **AND** overlay MUST remain on the last completed sample

## REMOVED Requirements

### Requirement: AI Vision live composites boxes into the video frame (no stacked overlay view)

**Reason**: Architecture aligned with SSE client-overlay model; compositor removed from live tab.

**Migration**: Use `DetectionOverlayView` + `AiDetectOverlayGeometry` (see `ai-vision-recorded-video-realtime`).
