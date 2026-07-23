## ADDED Requirements

### Requirement: Zero-point and EdgeDrawing native paths SHALL apply red-frame gate before detection

Before running brightest-in-box (L1 zero_point) or ScanVChannelRadialAdaptive (L1 Pro edgedrawing), native code SHALL invoke the shared red-frame validator on the full BGR frame. Frames rejected as `overexposed` or `invalid_non_red` MUST NOT enter the detection algorithm.

#### Scenario: Purple frame skipped on laser-on sample

- **WHEN** a PR1 I420 frame is submitted to zero_point or edgedrawing JNI
- **AND** the frame is classified as invalid non-red by the red-frame gate
- **THEN** native MUST return `ok=false`, `code=-5`, `reason=invalid_non_red`
- **AND** the App round SHALL treat the sample as a failed attempt (not a valid offset)

#### Scenario: Overexposed frame skipped on laser-on sample

- **WHEN** a PR1 frame fails the red-frame overexposure check
- **THEN** native MUST return `ok=false`, `code=-5`, `reason=overexposed`
- **AND** downstream spot-size or circle-fit logic MUST NOT run

## MODIFIED Requirements

### Requirement: Parse offset_x and compute UI correction with inverted sign

Native JSON SHALL expose at minimum `ok`, `code`, `reason` (when `ok` is false), `offset_x`, and `offset_y`. The `code` field MUST follow the shared OpenCV detect table in `opencv-detect-error-codes` (for example `-5` with `reason=spot_size_above_max` for spot-size rejection, or `-5` with `reason=overexposed` / `reason=invalid_non_red` for red-frame gate rejection).

For samples with **`ok == true`**, the App SHALL read **`offset_x`** (pixels, detected minus reference). UI zero correction uses **1 unit = 3px** with **+ = move zero right** and **− = move zero left**. The App SHALL compute per-sample UI delta as:

**`uiDelta = round(-offset_x / 3.0)`**

(JSON negative → UI increases; JSON positive → UI decreases.)

#### Scenario: Negative offset_x increases UI value

- **WHEN** native returns `ok=true` and `offset_x=-6`
- **THEN** per-sample `uiDelta` SHALL be `+2`

#### Scenario: Red-frame reject does not produce offset

- **WHEN** native returns `ok=false`, `code=-5`, `reason=invalid_non_red`
- **THEN** the App MUST NOT treat the sample as a valid offset for cluster aggregation
