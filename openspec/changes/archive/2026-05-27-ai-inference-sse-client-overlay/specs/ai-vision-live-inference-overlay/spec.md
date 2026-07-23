## MODIFIED Requirements

### Requirement: AI Vision live composites boxes into the video frame (no stacked overlay view)

Live preview MUST render detection graphics on a **client overlay surface** above the live video player (`TextureView` or `DetectionOverlayView`), driven by hold-forward **`LensGuardInferenceResult`**. The system MUST NOT burn boxes or status text into the camera frame bitmap for on-device display. The system MUST NOT encode composited H.264 for `GET /v1/camera/ai`.

Status text (`level`, `status`, `message` / `displayMessage`) MAY appear on the overlay surface or adjacent UI widgets; it MUST NOT require server-side or on-device frame compositing.

#### Scenario: Overlay view draws boxes on live tab

- **WHEN** AI Vision live preview detection is enabled and unified hold-forward is active
- **THEN** the player MUST show unobstructed RTSP video on the base surface
- **AND** boxes MUST be drawn on the overlay layer using `LensGuardInferenceResult.toOverlayBoxes()` (or equivalent)

#### Scenario: No bitmap compositor for live preview

- **WHEN** a new live infer sample completes
- **THEN** the app MUST update overlay geometry from the unified result
- **AND** MUST NOT call `ProcessVideoAiFrameRenderer` or equivalent bitmap burn-in for live preview

### Requirement: AI Vision live uses hold-forward overlay from unified results

The system SHALL maintain the **latest completed** `LensGuardInferenceResult` from live sampling. The overlay layer MUST display box geometry from that result until a newer sample completes.

#### Scenario: Slow infer keeps previous boxes visible

- **WHEN** sample `N` is inferring and sample `N-1` already completed with boxes
- **THEN** the overlay MUST still show sample `N-1` boxes
- **AND** live video MUST continue from RTSP without waiting for infer

#### Scenario: New result replaces overlay for following frames

- **WHEN** sample `N` completes with new `boxes`
- **THEN** the overlay MUST update to sample `N` boxes
- **AND** status UI MUST reflect sample `N` `level` and `status`

#### Scenario: Before first live result

- **WHEN** live preview starts and no sample has completed yet
- **THEN** the overlay MAY be empty
- **AND** live playback MUST still run

## REMOVED Requirements

### Requirement: Live on-device preview and HTTP use the same composited frame

**Reason**: HTTP uses SSE JSON; on-device uses overlay layer.

**Migration**: LAN clients draw from SSE; app uses TextureView overlay.

## MODIFIED Requirements

### Requirement: EventBus check results are not the primary live overlay source

New code for AI Vision live detection overlay MUST consume hold-forward `LensGuardInferenceResult` rather than parsing `LensCheckResultEvent.message` directly. `onCheckResult` MAY remain for legacy production stain alerts outside the live preview tab.

#### Scenario: Preview det overlay migration

- **WHEN** preview detection is enabled on the AI Vision live tab
- **THEN** `AiVisionFragment` MUST update hold-forward `LensGuardInferenceResult` from unified infer completion and refresh the overlay layer
- **AND** MUST NOT require synchronous `onLensCheckResult` handling for box coordinates
