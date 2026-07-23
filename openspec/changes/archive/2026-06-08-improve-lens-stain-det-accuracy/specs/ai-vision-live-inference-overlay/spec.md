## MODIFIED Requirements

### Requirement: AI Vision live uses client-side DetectionOverlayView

Live preview MUST render detection boxes on **`DetectionOverlayView`** above the video surface using **per-sample** semantics: only the latest **completed** OpenCV stain-detect sample with boxes is shown. When the latest completed sample has no boxes, the overlay MUST show no stain-detect boxes. The system MUST NOT hold-forward boxes from an earlier sample. The system MUST NOT burn boxes into the camera bitmap for live preview.

#### Scenario: Overlay shows only current completed sample

- **WHEN** sample `N` completes with boxes
- **THEN** `DetectionOverlayView` MUST show sample `N` boxes

#### Scenario: Completed sample without boxes clears stain overlay

- **WHEN** sample `N` completes without boxes
- **THEN** stain-detect boxes on `DetectionOverlayView` MUST be cleared
- **AND** live RTSP playback MUST continue

#### Scenario: No composited bitmap path for live tab

- **WHEN** AI Vision live preview detection is enabled
- **THEN** the system MUST NOT use `ProcessVideoAiFrameRenderer` or H.264 compositor encode solely for on-screen live preview

### Requirement: AI Vision live uses hold-forward overlay from stain detect results

The system SHALL map the latest **completed** stain-detect result to overlay on each refresh. Overlay renderers MUST map boxes through **`AiDetectOverlayGeometry`** when detect-frame dimensions differ from display size. The system MUST NOT retain or merge boxes from prior completed samples when the latest completed sample has no boxes.

#### Scenario: New result replaces overlay

- **WHEN** sample `N` completes with new boxes
- **THEN** overlay MUST update to sample `N` boxes on subsequent frames

#### Scenario: Before first live result

- **WHEN** live preview starts and no sample has completed yet
- **THEN** displayed frames MAY show no boxes
- **AND** live playback MUST still run

### Requirement: Live path drops overlapping samples without blocking display

While OpenCV stain detect is in flight, newly accepted `AI_VISION_LIVE` samples MUST NOT start a second detect. When a sample is skipped due to busy, live display MUST keep the last **completed** sample's overlay unchanged until the in-flight sample completes or a new sample completes.

#### Scenario: Busy skips 500 ms sample

- **WHEN** the 500 ms gate accepts a sample but `isOpencvStainDetectBusy()` is true
- **THEN** the new detect MUST NOT start
- **AND** overlay MUST remain on the last **completed** sample (not hold-forward from an older sample beyond that)
