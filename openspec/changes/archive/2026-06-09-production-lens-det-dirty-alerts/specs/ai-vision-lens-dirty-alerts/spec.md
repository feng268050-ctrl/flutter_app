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

#### Scenario: Production weld uses heavy-only laser-stop alerts

- **WHEN** production lens_det or RKNN reports `level >= 2` in Quick/Engineer continuous or spot welding
- **THEN** production dirty-alert flow SHALL apply per `production-lens-det-dirty-alerts` (heavy only, after laser stops)
- **AND** `level == 1` MUST NOT open mild dialogs in production weld scope
