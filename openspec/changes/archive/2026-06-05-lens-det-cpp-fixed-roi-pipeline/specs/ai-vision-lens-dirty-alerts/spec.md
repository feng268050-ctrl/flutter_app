## ADDED Requirements

### Requirement: Lens det OpenCV path SHALL align with fixed ROI native semantics

When AI Vision or related flows consume `LensDetDetectResult` from `nativeOpencvStainDetectFrom*` (distinct from RKNN `LensCheckResultEvent` stain grades), the App MUST treat detection outcomes as authoritative from native fixed ROI processing. The App MUST NOT reconstruct valid-region geometry from blue lines or override native target coordinates with Java-side OpenCV.

Documentation for operator-facing lens / contamination UX MUST state that OpenCV `lens_det` uses fixed ROI `(650,100,500×500)` on 1080p-class frames, not blue-line band detection.

#### Scenario: Overlay uses native global target only

- **WHEN** `LensDetDetectResult.success` is true with `targetX` / `targetY` from `target.json`
- **THEN** AI Vision overlay MUST draw at those coordinates
- **AND** MUST NOT apply an additional Java valid-region clip based on blue line detection

#### Scenario: Native lens det failure does not trigger RKNN dirty dialog

- **WHEN** only `LensDetDetectResult` fails (`ok:false`) and no `LensCheckResultEvent` with `level >= 1` is emitted
- **THEN** the lens dirty alert dialog flow defined for RKNN `level` MUST NOT open solely due to lens_det failure
