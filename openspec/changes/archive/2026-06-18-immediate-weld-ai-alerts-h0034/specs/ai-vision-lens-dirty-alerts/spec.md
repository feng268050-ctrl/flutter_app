## MODIFIED Requirements

### Requirement: Lens det OpenCV path SHALL align with fixed ROI native semantics

When AI Vision or related flows consume `LensDetDetectResult` from `nativeOpencvStainDetectFrom*` (distinct from RKNN `LensCheckResultEvent` stain grades), the App MUST treat detection outcomes as authoritative from native fixed ROI processing. The App MUST NOT reconstruct valid-region geometry from blue lines or override native target coordinates with Java-side OpenCV.

Documentation for operator-facing lens / contamination UX MUST state that OpenCV `lens_det` uses fixed ROI `(650,100,500×500)` on 1080p-class frames, not blue-line band detection.

#### Scenario: Overlay uses native global target only

- **WHEN** `LensDetDetectResult.success` is true with `targetX` / `targetY` from `target.json`
- **THEN** AI Vision overlay MUST draw at those coordinates
- **AND** MUST NOT apply an additional Java valid-region clip based on blue line detection

#### Scenario: AI Vision preview lens det does not open production dirty dialogs

- **WHEN** lens_det results originate from AI Vision live or process video paths
- **THEN** production dirty-alert dialogs MUST NOT open for those results alone
- **AND** AI Vision MAY continue overlay visualization only

#### Scenario: Production weld uses heavy-only immediate L001 alerts

- **WHEN** production lens_det or RKNN reports `level >= 2` in Quick/Engineer continuous or spot welding
- **THEN** production dirty-alert flow SHALL apply per `production-lens-det-dirty-alerts` (heavy only, **immediate** L001 presentation)
- **AND** `level == 1` MUST NOT open mild dialogs in production weld scope

### Requirement: Process video detect completion SHALL emit lens alert from temporal summary

When AI Vision process video Detect completes and temporal reduction has run, the system SHALL emit exactly one `LensCheckResultEvent` on the main thread reflecting the summary outcome:

- Persistent boxes present → `level >= 2` (heavy), status per existing OpenCV stain mapping
- No persistent boxes → `level == 0` (clean)

The system MUST NOT emit per-frame `LensCheckResultEvent` alerts during active process video Detect sampling.

Production weld L001 alerts MUST continue to ignore events whose message JSON indicates offline / non-live-weld sources per `StainDetectAlertMapper`.

#### Scenario: Summary clean dismisses dirty expectation

- **WHEN** Detect showed transient boxes during playback but summary reduction is clean
- **THEN** the system MUST emit `level == 0` or MUST NOT emit a heavy alert for that session
- **AND** MUST NOT stack multiple summary alerts for the same session

#### Scenario: Summary dirty shows AI Vision alert

- **WHEN** AI Vision is at least `STARTED` and summary reduction kept persistent boxes
- **THEN** the system SHALL show the heavy contamination alert dialog per existing AI Vision lens dirty alert rules
- **AND** production weld L001 flow MUST NOT trigger solely from this offline summary event
