## ADDED Requirements

### Requirement: AI Vision recorded overlay does not hold-forward boxes

AI Vision process-video Detect and Replay overlay MUST NOT retain detection boxes from an earlier sample when the latest completed sample at or before playback position `P` has no boxes. Box display MUST reflect only:

1. The temporal summary frame after session finalization (per **Detect completion overlay uses temporal summary frame**), or
2. The timeline sample at or before `P` returned by `findFrameAt(P)` when that sample itself has detection boxes, or
3. No boxes when neither applies.

The system MUST NOT use `findLastFrameWithDetectionAt`, `findLastStainDetectWithTargetAt`, or equivalent hold-forward lookup for AI Vision overlay rendering.

#### Scenario: Later sample without box clears overlay during Detect

- **WHEN** sample at `T1` ms completed with boxes and sample at `T2` ms (`T2 > T1`, `T2 <= P`) completed without boxes during **active** Detect
- **THEN** overlay at position `P` MUST show no contamination boxes
- **AND** status text MUST still reflect sample `T2` (or the latest sample at or before `P`)

#### Scenario: Replay without summary does not hold-forward

- **WHEN** Replay runs on a timeline without a temporal summary frame
- **THEN** overlay MUST NOT show boxes from an earlier sample when the sample at `P` has no boxes

### Requirement: Detect completion overlay uses temporal summary frame

After `ProcessVideoAiSession` finalizes with temporal reduction, AI Vision recorded-video overlay for **Detect complete**, **Replay**, and idle cover with detection result MUST use the temporal summary frame boxes and status—not per-frame detections or hold-forward from earlier samples.

During an **active** Detect session (before finalization), overlay MUST show boxes only from the current timeline sample at `P` when that sample has detection boxes; otherwise MUST show no boxes.

#### Scenario: Replay after detect with fleeting false positives

- **WHEN** Detect completes and reduction removed all non-persistent boxes
- **THEN** Replay overlay MUST show no contamination boxes at any playback position

#### Scenario: Replay after detect with persistent contamination

- **WHEN** Detect completes and reduction kept persistent boxes
- **THEN** Replay overlay MUST show the summary boxes when playback reaches the summary timestamp or end-of-stream

## MODIFIED Requirements

### Requirement: Recorded detect uses client overlay from timeline

While `ProcessVideoAiSession` is active, display and LAN SSE MUST be **client-side only**: map timeline stain-detect results to overlay boxes and HUD text. ExoPlayer MUST NOT wait for detect completion.

Box coordinates for AI Vision overlay MUST use **`findFrameAt(playbackPositionMs)`** only: show boxes when that frame has detection; otherwise show no boxes. Status text SHALL reflect the latest completed sample at or before `P`.

After session finalization, when a temporal summary frame exists, overlay for completion and Replay MUST use the summary frame as specified in **Detect completion overlay uses temporal summary frame**.

#### Scenario: Overlay tracks playback position

- **WHEN** playback is at position `P` ms during **active** Detect and the latest completed sample at or before `P` has boxes
- **THEN** the overlay MUST show that sample's boxes on `DetectionOverlayView`
- **AND** ExoPlayer MUST continue without waiting for detect

#### Scenario: Sample at P has no box

- **WHEN** during **active** Detect the latest completed sample at or before `P` has no detection boxes
- **THEN** overlay at `P` MUST show no contamination boxes

#### Scenario: HTTP SSE matches timeline

- **WHEN** a sample at media position `T` ms completes
- **THEN** SSE MUST emit `running` with `timestampMs` `T`
- **AND** in-app overlay at position `T` during active Detect MUST use the same result fields

#### Scenario: Summary frame after session complete

- **WHEN** Detect session finalizes and temporal reduction appended a summary frame
- **THEN** SSE MUST have emitted a summary `running` before `stop`
- **AND** AI Vision completion overlay MUST match that summary frame
