## ADDED Requirements

### Requirement: Red-frame gate reason tokens SHALL be registered in the shared contract

The shared OpenCV detect `reason` appendix SHALL include red-frame validator tokens usable by **zero_point**, **edgedrawing**, and **lens_det**:

| `reason` | `code` | Meaning |
|----------|--------|---------|
| `overexposed` | -5 | Red-frame gate: ROI overexposed |
| `invalid_non_red` | -5 | Red-frame gate: fails red color thresholds |
| `no_valid_region` | -5 | Red-frame gate: no contour mask |
| `empty_roi` | -5 | Red-frame gate: zero pixels after mask/erode |

#### Scenario: Overexposed uses FRAME_REJECTED

- **WHEN** any OpenCV detect module rejects via the red-frame gate for overexposure
- **THEN** `code` MUST be `-5`
- **AND** `reason` MUST be `overexposed`

#### Scenario: Purple classified as invalid_non_red

- **WHEN** the validator rejects a purple frame
- **THEN** `code` MUST be `-5`
- **AND** `reason` MUST be `invalid_non_red`

### Requirement: OpenCV detect modules list SHALL include edgedrawing

The numeric `code` table requirement SHALL explicitly name **edgedrawing** alongside **zero_point** and **lens_det** as consumers of the shared code and reason contract.

#### Scenario: EdgeDrawing overexposed rejection

- **WHEN** edgedrawing rejects a frame via the red-frame gate
- **THEN** JSON MUST use the same `-5` / `reason` tokens as zero_point and lens_det

## MODIFIED Requirements

### Requirement: Failure responses SHALL include a stable snake_case reason token

When `ok` is `false`, the JSON MUST include a `reason` string using **snake_case** tokens defined by the shared contract. Human-readable sentences MUST NOT be the sole machine-parseable identifier.

Red-frame gate failures MUST use `overexposed`, `invalid_non_red`, `no_valid_region`, or `empty_roi` as defined in the red-frame reason table.

#### Scenario: Lens det no target reason token

- **WHEN** lens_det finds insufficient regions after erosion
- **THEN** `reason` MUST be `insufficient_regions_after_erode`

#### Scenario: Zero point missing reference reason token

- **WHEN** zero_point cannot compare offsets because `reference_zero_xy` is missing
- **THEN** `code` MUST be `-6`
- **AND** `reason` MUST be `missing_reference_zero`

#### Scenario: Red-frame overexposed reason token

- **WHEN** any module rejects before detection because `overexposed_ratio > 0.5` or `gray_mean > 230`
- **THEN** `reason` MUST be `overexposed`

### Requirement: App SHALL expose OpencvDetectCodes aligned with native

The App SHALL provide `OpencvDetectCodes` (or equivalent) mirroring the shared table. Parsers for zero_point, edgedrawing, and lens_det JNI JSON MUST map native `code` and `reason` through this enum for logging and branching.

#### Scenario: App maps frame rejection consistently

- **WHEN** any module returns `code=-5` with a known `reason` (including `overexposed` and `invalid_non_red`)
- **THEN** the App MUST classify the result as frame rejected via `OpencvDetectCodes`
- **AND** MUST log `code` and `reason` in the same format for all three modules

### Requirement: Native API docs SHALL document one shared code table

`ZERO_POINT_NATIVE_API.md`, edgedrawing API documentation (if present), and `OPENCV_STAIN_DETECT_NATIVE_API.md` MUST list the same `code` table and point to module-specific `reason` tokens including the red-frame gate appendix.

#### Scenario: Documentation parity

- **WHEN** a developer reads any OpenCV detect native API doc for `code` meanings
- **THEN** the numeric definitions MUST match `opencv-detect-error-codes` exactly
- **AND** red-frame `reason` tokens MUST appear in the reason appendix
