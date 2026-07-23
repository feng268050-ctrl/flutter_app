# lens-det-fixed-roi-pipeline Specification

## Purpose
TBD - created by archiving change lens-det-cpp-fixed-roi-pipeline. Update Purpose after archive.
## Requirements
### Requirement: Native lens det SHALL use a single fixed square ROI

The native `lens_det` OpenCV pipeline SHALL define exactly one detection region per frame: rectangle `(x, y, width, height)` with defaults `x=650`, `y=100`, `width=500`, `height=500` in full-image pixel coordinates. The pipeline MUST NOT detect or scale a blue-line valid band, MUST NOT build a blue-line exclusion mask, and MUST NOT fall back to reference-height vertical band scaling.

When the image is smaller than the configured ROI, the implementation SHALL clamp `x` and `y` to `[0, image_size - roi_size]` and SHALL crop using the intersecting rectangle.

#### Scenario: 1080p input uses configured ROI

- **WHEN** a BGR frame is `1920×1080` and default ROI config is used
- **THEN** the pipeline MUST crop pixels `[100:600, 650:1150)` (row-major BGR indexing `y:y+h, x:x+w`)
- **AND** MUST NOT scan the full frame for blue line pixels

#### Scenario: Smaller image clamps ROI origin

- **WHEN** image width is `800` and configured `roi_x=650`, `roi_width=500`
- **THEN** effective `roi_x` MUST be `300` (or equivalent clamp so the 500px width fits)
- **AND** processing MUST continue without error

### Requirement: ROI preprocess SHALL follow enhance invert binary open erode order

Inside the cropped ROI, the native pipeline SHALL execute in order:

1. Brightness enhance: HSV V-channel CLAHE then `convertScaleAbs` with configured `enhance_clahe_clip`, `enhance_alpha`, `enhance_beta`
2. Grayscale conversion
3. Bitwise invert on gray
4. Fixed-threshold binarization: `THRESH_BINARY_INV` with `invert_thresh` (default 80)
5. Morphological open with elliptical kernel `open_kernel` (default 3) for denoise
6. Elliptical erode loop with kernel `erode_kernel` (default 5)

The pipeline MUST NOT apply HSV/V/R/G/B bright-threshold masking on the full frame or inside the ROI for target extraction.

#### Scenario: Stages match reference script ordering

- **WHEN** default parameters are used on a golden test frame
- **THEN** intermediate masks MUST be reproducible with `opencv_stain_detect_infer --dump-stages` within OpenCV floating tolerance for CLAHE/scale
- **AND** the denoise step MUST occur before the first erode iteration

### Requirement: Dynamic erosion SHALL stop at split or max six iterations

After morphological open, the native pipeline SHALL erode at most `erode_max_iterations` times (default **6**). After each erode iteration, it SHALL count foreground connected components with area ≥ `min_blob_area` (default 40). The loop MUST stop when the count is ≥ `min_split_regions` (default 2) OR when `erode_max_iterations` is reached.

The final blob list and target selection MUST be derived from the mask state after the last applied erode iteration.

#### Scenario: Split on iteration six

- **WHEN** the opened mask remains one component through five erode iterations and reaches two components on the sixth
- **THEN** `erosion_count` MUST be 6
- **AND** blob extraction MUST use the mask after iteration six

#### Scenario: Max iterations without split

- **WHEN** fewer than `min_split_regions` components exist after `erode_max_iterations` erodes
- **THEN** the pipeline MUST use the mask after the final erode
- **AND** MUST NOT apply additional erode iterations beyond the configured maximum

### Requirement: Target coordinates SHALL map from ROI space to full image

Connected-component geometry computed inside the ROI MUST be translated to full-image coordinates by adding `(roi_x, roi_y)` before writing `target.json`. JNI summary JSON contract (`ok`, `code`, `files`) MUST remain unchanged.

#### Scenario: Successful target JSON uses global centroid

- **WHEN** a blob centroid inside ROI is `(120.5, 200.0)` and ROI origin is `(650, 100)`
- **THEN** `target.json` fields `x` and `y` MUST be `770.5` and `300.0` respectively

#### Scenario: No target still returns native failure summary

- **WHEN** no blob meets `min_target_area_px` and size thresholds after erosion
- **THEN** summary JSON MUST be `ok:false` with documented negative `code`
- **AND** MUST NOT write a target file with global coordinates

