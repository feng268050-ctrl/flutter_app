## ADDED Requirements

### Requirement: AI Vision live inference runs on a background worker

When AI Vision live RTSP preview is active and preview detection is enabled, the system SHALL sample the `TextureView` at `AiFrameSamplingInterval.AI_VISION_LIVE` (500 ms) and SHALL submit unified inference (`inferFromI420` after I420 conversion, or an equivalent manager entry point) on a background executor. RTSP decode, `TextureView` rendering, and live compositor ticks MUST NOT block waiting for inference to complete.

#### Scenario: Texture sample does not stall playback

- **WHEN** a 500 ms sample fires while the live player is displaying frames
- **THEN** the main-thread sample callback MUST return without waiting for `onCheckResult`
- **AND** the live video surface MUST continue updating from RTSP

### Requirement: AI Vision live composites boxes into the video frame (no stacked overlay view)

Live preview MUST use the **same on-frame compositing model as recorded-video Detect**: detection graphics are drawn **into the video frame bitmap** (shared renderer with `ProcessVideoAiFrameRenderer` or extracted helper) before display and before HTTP encode. The system MUST NOT rely on a stacked `DetectionOverlayView` (or equivalent transparent view above `TextureView`) for detection boxes when unified hold-forward inference is active on the live tab.

Detection **status text** (`level`, `status`, and human-readable `message` / `displayMessage`) MUST also be burned into the composited frame bitmap (e.g. banner or label region drawn by the shared compositor), not shown in separate `TextView` widgets (`tvAiResult`, `tvAiState`, etc.) for live preview when unified compositing is active. Classification (`tvAiCls`) MAY remain a separate widget unless a later change extends compositing to cls text.

#### Scenario: No DetectionOverlayView boxes on live tab

- **WHEN** AI Vision live preview detection is enabled and unified hold-forward is active
- **THEN** `DetectionOverlayView` MUST NOT be the source of truth for box rendering on the live preview surface
- **AND** boxes MUST appear only as part of the composited frame image shown to the operator

#### Scenario: Same renderer as process video

- **WHEN** hold-forward selects a completed `LensGuardInferenceResult` for the current live frame
- **THEN** the app MUST call the shared frame compositor (e.g. `ProcessVideoAiFrameRenderer.drawFrame`) on the captured camera bitmap
- **AND** MUST display or encode that composited bitmap, matching recorded-video Detect semantics

### Requirement: AI Vision live uses hold-forward overlay from unified results

The system SHALL maintain the **latest completed** `LensGuardInferenceResult` from live sampling (`source` typically `preview_det`). All subsequent composited live frames MUST bake in `level`/`status`-associated box geometry from that result until a newer sample completes, then update coordinates for following frames only.

#### Scenario: Slow infer keeps previous boxes visible

- **WHEN** sample `N` is inferring and sample `N-1` already completed with boxes
- **THEN** composited frames MUST still draw sample `N-1` boxes into the bitmap
- **AND** MUST NOT clear boxes solely because sample `N` is in flight

#### Scenario: New result replaces overlay for following frames

- **WHEN** sample `N` completes with new `boxes`
- **THEN** composited frames after completion MUST bake in sample `N` boxes
- **AND** status UI MUST reflect sample `N` `level` and `status`

#### Scenario: Before first live result

- **WHEN** live preview starts and no sample has completed yet
- **THEN** displayed frames MAY be camera imagery only (no boxes drawn)
- **AND** live playback MUST still run

### Requirement: Live path drops overlapping samples without blocking display

While unified infer is in flight, newly accepted `AI_VISION_LIVE` samples MUST NOT start a second infer. Live display MUST keep hold-forward overlay from the last completed sample.

#### Scenario: Busy skips 500 ms sample

- **WHEN** a 500 ms tick occurs while `inferFromI420` is still processing the prior sample
- **THEN** the new sample MUST be dropped for infer purposes
- **AND** live video and overlay MUST continue using the last completed result

### Requirement: Live on-device preview and HTTP use the same composited frame

On-device live preview and `GET /v1/camera/ai` composited mode MUST consume the **same** hold-forward composited bitmap pipeline (camera frame + burned-in boxes). `CameraAiHttpCompositor` MUST NOT maintain a separate box-drawing path that diverges from on-screen live compositing.

#### Scenario: HTTP matches on-device pixels

- **WHEN** `GET /v1/camera/ai` is in `composited` mode and live preview detection is enabled
- **THEN** HTTP H.264/TS bytes MUST be encoded from the same composited bitmaps (or a shared compositor output queue) as shown on the live preview surface
- **AND** box geometry MUST NOT be drawn only in HTTP while on-device still uses a stacked overlay view

### Requirement: EventBus check results are not the primary live overlay source

New code for AI Vision live detection overlay MUST consume hold-forward `LensGuardInferenceResult` rather than parsing `LensCheckResultEvent.message` directly. `onCheckResult` MAY remain for legacy production stain alerts outside the live preview tab.

#### Scenario: Preview det overlay migration

- **WHEN** preview detection is enabled on the AI Vision live tab
- **THEN** `AiVisionFragment` MUST update hold-forward `LensGuardInferenceResult` from unified infer completion and re-composite frames for display
- **AND** MUST NOT require synchronous `onLensCheckResult` handling or `DetectionOverlayView.setBoxes` for box coordinates
