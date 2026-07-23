## MODIFIED Requirements

### Requirement: Selected process video uses composited preview (same pipeline as HTTP)

When the user starts **Detect** on a process video in AI Vision, the system SHALL start **`ProcessVideoAiSession`** with an internal **1× playback clock**. The in-app preview MUST play the **source recording** on the video player (ExoPlayer or equivalent) and MUST render detection overlays on a **client overlay surface** (`TextureView` / `DetectionOverlayView`) using **`ProcessVideoAiTimeline.findFrameAt(playbackPositionMs)`** with hold-forward semantics. The system MUST NOT display composited H.264 from an on-device encoder for preview. LAN clients MUST receive inference via **`GET /v1/videos/:video_id/ai`** SSE, not composited video bytes.

Inference SHALL use **`AiFrameSamplingInterval.AI_VISION_PROCESS_VIDEO`** (**200 ms**). Camera live preview remains **`AI_VISION_LIVE`** (500 ms).

The system MUST NOT require completion of whole-file batch offline analysis before showing preview with overlays.

#### Scenario: User starts detect

- **WHEN** the user taps **Detect** on a valid process video
- **THEN** source video playback MUST begin promptly
- **AND** overlays MUST update as timeline samples complete
- **AND** LAN SSE on `/v1/videos/<id>/ai` MUST emit matching `inference` events with `streamTimeMs`

#### Scenario: No server composited preview player

- **WHEN** a `ProcessVideoAiSession` is active
- **THEN** `ProcessVideoAiCompositedPreview` MUST NOT be the primary preview path
- **AND** the system MUST NOT mux composited H.264 solely for on-screen display

## REMOVED Requirements

### Requirement: Parallel inference MP4 capture with tmp finalize

**Reason**: On-device composited MP4 removed with SSE architecture; upload artifact deferred.

**Migration**: Follow-up change for metadata-only or client-generated upload.

### Requirement: Upload uses finalized MP4 only

**Reason**: Composited inference MP4 no longer produced in this path.

**Migration**: Disable or revise upload gate until new artifact defined.

### Requirement: Hold-forward overlay until the next sample result

**Reason**: Superseded by client-overlay requirement block below (same semantics, different render target).

**Migration**: Overlay view uses timeline `findFrameAt`; no bitmap compositor.

### Requirement: Overlay uses unified level status and box coordinates

**Reason**: Replaced by client-overlay variant.

**Migration**: See ADDED requirement.

## ADDED Requirements

### Requirement: Recorded detect uses client overlay from timeline

While `ProcessVideoAiSession` is active, compositing for display and HTTP MUST be **client-side only**: map `LensGuardInferenceResult` from `findFrameAt(playbackPositionMs)` to overlay boxes and status. The encode/playback clock MUST NOT block on infer completion.

#### Scenario: Overlay tracks playback position

- **WHEN** playback is at position `P` ms and the latest completed sample at or before `P` has boxes
- **THEN** the overlay MUST show that sample's boxes scaled to the video view
- **AND** the video decoder MUST continue without waiting for infer

#### Scenario: HTTP SSE matches timeline

- **WHEN** a sample at `streamTimeMs=T` completes
- **THEN** SSE MUST emit `inference` with `streamTimeMs=T`
- **AND** in-app overlay at position `T` MUST use the same unified result fields
