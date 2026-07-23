## ADDED Requirements

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

#### Scenario: Lens det no target reason token

- **WHEN** lens_det finds insufficient regions after erosion
- **THEN** `reason` MUST be `insufficient_regions_after_erode`

#### Scenario: Zero point missing reference reason token

- **WHEN** zero_point cannot compare offsets because `reference_zero_xy` is missing
- **THEN** `code` MUST be `-6`
- **AND** `reason` MUST be `missing_reference_zero`

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

The App SHALL provide `OpencvDetectCodes` (or equivalent) mirroring the shared table. Parsers for zero_point and lens_det JNI JSON MUST map native `code` and `reason` through this enum for logging and branching.

#### Scenario: App maps frame rejection consistently

- **WHEN** either module returns `code=-5` with a known `reason`
- **THEN** the App MUST classify the result as frame rejected via `OpencvDetectCodes`
- **AND** MUST log `code` and `reason` in the same format for both modules

### Requirement: Native API docs SHALL document one shared code table

`ZERO_POINT_NATIVE_API.md` and `OPENCV_STAIN_DETECT_NATIVE_API.md` MUST list the same `code` table and point to module-specific `reason` tokens in an appendix or sub-table.

#### Scenario: Documentation parity

- **WHEN** a developer reads either native API doc for `code` meanings
- **THEN** the numeric definitions MUST match `opencv-detect-error-codes` exactly
