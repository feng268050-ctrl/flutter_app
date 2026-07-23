# opencv-detect-error-codes Specification

## Purpose
TBD - created by archiving change opencv-detect-unified-error-codes. Update Purpose after archive.
## Requirements
### Requirement: OpenCV detect modules SHALL share a single numeric code table

The native implementations of **zero_point** and **lens_det** (OpenCV stain detect) SHALL return JSON summaries whose `code` field uses only the following values:

| `code` | Name | Meaning |
|--------|------|---------|
| `0` | OK | Detection succeeded |
| `-1` | INVALID_HANDLE | Detector or session handle is invalid |
| `-2` | INVALID_INPUT | Frame, path, dimensions, pixel format, or other call arguments are invalid |
| `-3` | DETECT_FAILED | Pipeline ran but no qualifying target or zero point was found |
| `-4` | IO_ERROR | Image read, output directory creation, or result file write failed |
| `-5` | FRAME_REJECTED | Frame rejected by a precondition gate; see `reason` |
| `-6` | CONFIG_ERROR | ROI, reference point, or deploy configuration is missing or invalid |

Modules MUST NOT overload the same `code` with different meanings (for example `-5` MUST NOT mean spot-size rejection in one module and saturation skip in another without both using `FRAME_REJECTED` and distinct `reason` tokens).

#### Scenario: Zero point spot size uses FRAME_REJECTED

- **WHEN** zero_point rejects a frame because the black blob exceeds 30×30 px
- **THEN** the JSON MUST return `ok=false`, `code=-5`, and `reason=spot_size_above_max`

#### Scenario: Lens det saturation uses FRAME_REJECTED

- **WHEN** lens_det skips analysis because saturated white pixels exceed the configured limit
- **THEN** the JSON MUST return `ok=false`, `code=-5`, and `reason=saturated_white_area_exceeds_limit`

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

### Requirement: INVALID_HANDLE is reserved for bad handles only

Code `-1` MUST be returned only when the detector or OpenCV stain detect session handle is invalid. Empty paths, invalid frame dimensions, wrong image type, and empty images MUST use `-2 INVALID_INPUT` with an appropriate `reason` token.

#### Scenario: Lens det invalid I420 dimensions

- **WHEN** `nativeOpencvStainDetectFromI420` is called with non-positive width or height
- **THEN** `code` MUST be `-2`
- **AND** `code` MUST NOT be `-1`

#### Scenario: Zero point invalid handle

- **WHEN** `nativeOpencvZeroPointDetectFromI420` is called with `zpHandle == 0`
- **THEN** `code` MUST be `-1`
- **AND** `reason` MUST be `invalid_detector_handle`

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

### Requirement: Zero point line failure uses DETECT_FAILED with line_not_found

When `DetectTargetMode` is Line and no qualifying horizontal bright band is found, zero_point SHALL return `ok=false`, `code=-3` (`DETECT_FAILED`), and `reason=line_not_found`.

#### Scenario: Line not found reason token

- **WHEN** line mode runs but band selection fails
- **THEN** `code` MUST be `-3`
- **AND** `reason` MUST be `line_not_found`

