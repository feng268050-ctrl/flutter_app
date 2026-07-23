# ai-vision-lens-dirty-alerts Specification

## Purpose
TBD - created by archiving change lens-dirty-alert-dialogs. Update Purpose after archive.
## Requirements
### Requirement: AI Vision shows lens dirty alert dialogs from native check results

The system SHALL present user-visible alert dialogs on the AI Vision screen when `LensCheckResultEvent` is received on the main thread, using **`level`** as the primary driver and **`message`** as the preferred body text when non-empty, as specified in repository **`docs/LENS_GUARD_APP_INTEGRATION.md`** §6. The system MUST NOT recompute contamination levels in Java.

#### Scenario: Heavy contamination shows blocking-style alert

- **WHEN** AI Vision is at least `STARTED` and `LensCheckResultEvent` carries `level >= 2`
- **THEN** the system SHALL show an alert dialog whose content prioritizes non-empty `message`, otherwise the documented default heavy text, and the visual treatment SHALL be distinct from mild (e.g., stronger emphasis / error styling as defined in implementation)
- **AND** the system SHALL apply de-duplication so repeated `level >= 2` events within a configured minimum interval do not stack multiple dialogs unless `level` increases

#### Scenario: Mild contamination shows advisory alert

- **WHEN** AI Vision is at least `STARTED` and `LensCheckResultEvent` carries `level == 1`
- **THEN** the system SHALL show an advisory alert dialog (or update an existing visible advisory dialog without stacking duplicates per de-duplication rules) prioritizing non-empty `message`, otherwise the documented default mild text

#### Scenario: Clean result dismisses dirty alerts

- **WHEN** `LensCheckResultEvent` carries `level == 0`
- **THEN** the system SHALL not open a new “clean” alert dialog for normal operation
- **AND** the system SHALL dismiss or clear any visible dirty alert dialog tied to this flow so the UI returns to normal state

#### Scenario: No dialog when fragment cannot interact

- **WHEN** AI Vision is not resumed, not added, or host context is unavailable
- **THEN** the system SHALL not show a window-leaking dialog for that event

#### Scenario: Alert sound policy for heavy level

- **WHEN** `level >= 2` and alert sound is triggered per product rules
- **THEN** the system SHALL follow a single documented policy to avoid double-playing the same alarm (either native `onAlert` only or App-only), consistent with `docs/LENS_GUARD_APP_INTEGRATION.md` §6.3

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
- **THEN** production dirty-alert flow SHALL apply per `production-lens-det-dirty-alerts` (heavy only, immediate L001 presentation)
- **AND** `level == 1` MUST NOT open mild dialogs in production weld scope

### Requirement: Process video detect completion SHALL emit lens alert from temporal summary

When AI Vision process video Detect completes and temporal reduction has run, the system SHALL emit exactly one `LensCheckResultEvent` on the main thread reflecting the summary outcome:

- Persistent boxes present → `level >= 2` (heavy), status per existing OpenCV stain mapping
- No persistent boxes → `level == 0` (clean)

The system MUST NOT emit per-frame `LensCheckResultEvent` alerts during active process video Detect sampling.

Production weld L001 alerts MUST continue to ignore events whose message JSON indicates `StainDetectSource.OFFLINE`.

#### Scenario: Summary clean dismisses dirty expectation

- **WHEN** Detect showed transient boxes during playback but summary reduction is clean
- **THEN** the system MUST emit `level == 0` or MUST NOT emit a heavy alert for that session
- **AND** MUST NOT stack multiple summary alerts for the same session

#### Scenario: Summary dirty shows AI Vision alert

- **WHEN** AI Vision is at least `STARTED` and summary reduction kept persistent boxes
- **THEN** the system SHALL show the heavy contamination alert dialog per existing AI Vision lens dirty alert rules
- **AND** production weld L001 flow MUST NOT trigger solely from this offline summary event

