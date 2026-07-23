## MODIFIED Requirements

### Requirement: nativeOpencvStainDetect SHALL not depend on blue-line valid region geometry

The OpenCV stain / `lens_det` JNI entry points (`nativeOpencvStainDetectFromJpg`, `FromRgb`, `FromNv12`, `FromI420` deprecated) SHALL perform detection using the fixed ROI enhance-invert-erode pipeline defined in `lens-det-fixed-roi-pipeline`. Callers MUST NOT assume that detection success requires visible blue guide lines or a vertically scaled valid band derived from `ref_height`.

For **`FromNv12`**, native code MUST convert NV12 to BGR via the shared `nv12ToBgr` path before entering the fixed ROI pipeline. **`FromI420`** SHALL shim through I420→NV12 conversion then the same path.

Configuration under `config.yaml` → `lens_det` MUST expose ROI and preprocess parameters; legacy `bright_*` and `valid_region_ref_*` keys MUST be ignored or documented as deprecated without affecting the fixed ROI path.

#### Scenario: Detect without blue lines in frame

- **WHEN** an input image contains no blue alignment lines but contamination appears inside the fixed ROI
- **THEN** native stain detect MUST still run the full ROI pipeline
- **AND** MUST return success with `target.json` when a qualifying blob is found

#### Scenario: JNI summary contract unchanged on failure

- **WHEN** no qualifying target is found after fixed ROI processing
- **THEN** JNI MUST return summary JSON with `ok:false` and empty `files`
- **AND** MUST NOT return coordinates in the summary string (coordinates remain file-based on success)

#### Scenario: FromNv12 uses shared nv12ToBgr

- **WHEN** `nativeOpencvStainDetectFromNv12` is invoked with valid dimensions and buffer
- **THEN** native MUST convert NV12 to BGR using the same implementation as `StreamDetectPipeline`
- **AND** MUST then run the fixed ROI stain pipeline unchanged
