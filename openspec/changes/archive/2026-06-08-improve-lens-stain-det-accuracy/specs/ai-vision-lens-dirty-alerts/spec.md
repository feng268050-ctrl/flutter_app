## ADDED Requirements

### Requirement: Process video detect completion SHALL emit lens alert from temporal summary

When AI Vision process video Detect completes and temporal reduction has run, the system SHALL emit exactly one `LensCheckResultEvent` on the main thread reflecting the summary outcome:

- Persistent boxes present → `level >= 2` (heavy), status per existing OpenCV stain mapping
- No persistent boxes → `level == 0` (clean)

The system MUST NOT emit per-frame `LensCheckResultEvent` alerts during active process video Detect sampling.

Production weld deferred alerts MUST continue to ignore events whose message JSON indicates `StainDetectSource.OFFLINE`.

#### Scenario: Summary clean dismisses dirty expectation

- **WHEN** Detect showed transient boxes during playback but summary reduction is clean
- **THEN** the system MUST emit `level == 0` or MUST NOT emit a heavy alert for that session
- **AND** MUST NOT stack multiple summary alerts for the same session

#### Scenario: Summary dirty shows AI Vision alert

- **WHEN** AI Vision is at least `STARTED` and summary reduction kept persistent boxes
- **THEN** the system SHALL show the heavy contamination alert dialog per existing AI Vision lens dirty alert rules
- **AND** production weld L001 deferred flow MUST NOT trigger solely from this offline summary event
