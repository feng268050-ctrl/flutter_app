## ADDED Requirements

### Requirement: Native SHALL provide a shared red-frame validator for OpenCV detect pipelines

The native layer SHALL implement `opencv_detect::validateRedFrame` (or equivalent) that accepts a BGR `cv::Mat` and returns a verdict before any module-specific detection algorithm runs.

The validator SHALL:

1. Convert to grayscale and build a binary mask with `gray > 20`
2. Find external contours, select the largest by area, and fill a ROI mask
3. Erode the ROI mask once with a 21×21 rectangular kernel
4. Zero the sub-rectangle `rows [0,120)` and `cols [0,650)` on the ROI mask (timestamp overlay exclusion)
5. Compute on masked pixels: `gray_mean`, `overexposed_ratio` (fraction with `gray > 245`), HSV `sat_mean`, `val_mean`, `red_ratio` (`H < 10` or `H > 170`), and `purple_ratio` (`125 < H < 165`)

#### Scenario: Valid red welding frame passes gate

- **WHEN** masked pixels satisfy `overexposed_ratio ≤ 0.5` and `gray_mean ≤ 230`
- **AND** `red_ratio > 0.4` and `sat_mean > 120` and `val_mean > 80`
- **THEN** the validator SHALL return verdict **valid red**
- **AND** the caller SHALL proceed to module-specific detection

#### Scenario: Overexposed white frame rejected

- **WHEN** `overexposed_ratio > 0.5` or `gray_mean > 230`
- **THEN** the validator SHALL return verdict **overexposed**
- **AND** the caller SHALL NOT run module-specific detection

#### Scenario: Purple or other non-red frame rejected

- **WHEN** overexposure checks pass
- **AND** red thresholds are NOT met (including frames where `purple_ratio > 0.4`)
- **THEN** the validator SHALL return verdict **invalid non-red**
- **AND** the caller SHALL NOT run module-specific detection

#### Scenario: No valid circular region

- **WHEN** no external contour is found after `gray > 20` thresholding
- **THEN** the validator SHALL return verdict **no valid region**
- **AND** the caller SHALL NOT run module-specific detection

### Requirement: Three OpenCV detect modules SHALL invoke the red-frame validator first

**zero_point** (`detectZeroPointFrame`), **edgedrawing** (`detectEdgeDrawingFrame`), and **opencv_stain_detect** (`analyzeFrame`) SHALL call the shared red-frame validator on the full BGR frame before their respective detection steps.

#### Scenario: Zero point skips brightest-in-box on reject

- **WHEN** `validateRedFrame` returns overexposed or invalid non-red for a zero_point frame
- **THEN** `detectBrightestPointInBox` MUST NOT run
- **AND** JSON MUST be `ok=false`, `code=-5`, with the matching `reason` token

#### Scenario: EdgeDrawing skips radial scan on reject

- **WHEN** `validateRedFrame` rejects an edgedrawing frame
- **THEN** `detectScanVChannelRadialAdaptiveInBox` MUST NOT run

#### Scenario: Lens det skips fixed ROI pipeline on reject

- **WHEN** `validateRedFrame` rejects a stain-detect frame
- **THEN** `runFixedRoiTargetPipeline` MUST NOT run

### Requirement: Red-frame rejection SHALL use FRAME_REJECTED with stable reason tokens

When the red-frame validator rejects a frame, the module JSON summary MUST return `ok=false`, `code=-5`, and one of:

| `reason` | Meaning |
|----------|---------|
| `overexposed` | ROI overexposed by ratio or mean gray |
| `invalid_non_red` | Not overexposed but fails red thresholds (includes purple) |
| `no_valid_region` | No qualifying contour / mask |
| `empty_roi` | Mask eroded or cropped to zero pixels |

#### Scenario: Overexposed JSON shape

- **WHEN** a white overexposed sample is processed by any of the three modules
- **THEN** JSON MUST be `{"ok":false,"code":-5,"reason":"overexposed",...}`

#### Scenario: Purple JSON uses invalid_non_red

- **WHEN** a purple sample is processed
- **THEN** `reason` MUST be `invalid_non_red`
- **AND** `reason` MUST NOT be a human-readable sentence

#### Scenario: Valid red continues to success path

- **WHEN** a red sample passes the validator and downstream detection succeeds
- **THEN** JSON MUST be `ok=true`, `code=0` with module-specific success fields unchanged
