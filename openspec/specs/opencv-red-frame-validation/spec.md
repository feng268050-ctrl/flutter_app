# opencv-red-frame-validation Specification

## Purpose
TBD - created by archiving change opencv-red-frame-validation. Update Purpose after archive.
## Requirements
### Requirement: Native SHALL provide a shared red-frame validator for OpenCV detect pipelines

The native layer SHALL implement `opencv_detect::validateRedFrame` (or equivalent) that accepts a BGR `cv::Mat` and returns a verdict before any module-specific detection algorithm runs.

The validator SHALL:

1. Convert to grayscale and build a binary mask with `gray > 20`
2. Find external contours, select the largest by area, and fill a ROI mask
3. Erode the ROI mask once with a 21×21 rectangular kernel
4. Compute diagnostic metrics on masked pixels (`gray_mean`, `overexposed_ratio`, HSV `sat_mean`, `val_mean`, `red_ratio`, `purple_ratio`) for logging and stage dumps only

The validator SHALL **NOT** zero timestamp/OSD sub-rectangles on the ROI mask. The validator SHALL **NOT** reject frames based on overexposure ratios, mean gray, or red/purple HSV thresholds.

A frame SHALL pass the gate when a non-empty eroded ROI mask exists after steps 1–3.

#### Scenario: Bright pool mask passes gate

- **WHEN** thresholding yields a largest contour and erosion leaves a non-empty mask
- **THEN** the validator SHALL return verdict **valid** (proceed)
- **AND** the caller SHALL proceed to module-specific detection

#### Scenario: No valid circular region

- **WHEN** no external contour is found after `gray > 20` thresholding
- **THEN** the validator SHALL return verdict **no valid region**
- **AND** the caller SHALL NOT run module-specific detection

#### Scenario: Erosion removes all mask pixels

- **WHEN** a contour exists but erosion yields zero masked pixels
- **THEN** the validator SHALL return verdict **empty roi**
- **AND** the caller SHALL NOT run module-specific detection

### Requirement: Red-frame rejection SHALL use FRAME_REJECTED with stable reason tokens

When the red-frame validator rejects a frame on the **production zero_point path**, the module JSON summary MUST return `ok=false`, `code=-5`, and one of:

| `reason` | Meaning |
|----------|---------|
| `no_valid_region` | No qualifying contour / mask |
| `empty_roi` | Mask eroded or cropped to zero pixels |

Legacy tokens `overexposed` and `invalid_non_red` MAY still be emitted by **edgedrawing** or **lens_det** modules that retain full color/overexposure rejection until separately migrated.

#### Scenario: Empty mask JSON shape

- **WHEN** erosion yields zero ROI pixels in zero_point
- **THEN** JSON MUST be `{"ok":false,"code":-5,"reason":"empty_roi",...}`

#### Scenario: No contour JSON shape

- **WHEN** no external contour is found in zero_point
- **THEN** JSON MUST be `{"ok":false,"code":-5,"reason":"no_valid_region",...}`

#### Scenario: Valid mask continues to success path

- **WHEN** a frame passes the simplified validator and downstream detection succeeds
- **THEN** JSON MUST be `ok=true`, `code=0` with module-specific success fields unchanged

