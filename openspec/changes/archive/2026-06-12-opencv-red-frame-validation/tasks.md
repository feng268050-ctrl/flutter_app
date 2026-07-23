## 1. Native shared validator

- [x] 1.1 Add `opencv_detect/red_frame_validator.h` with `RedFrameMetrics`, `RedFrameVerdict`, `RedFrameValidation`, and `validateRedFrame(const cv::Mat&)`
- [x] 1.2 Implement ROI mask pipeline in `red_frame_validator.cpp` (contour, 21×21 erode, timestamp rect zeroing, HSV/gray metrics)
- [x] 1.3 Add reason mapping: `overexposed`, `invalid_non_red`, `no_valid_region`, `empty_roi` → `opencv_detect_codes.h` constants
- [x] 1.4 Wire `red_frame_validator.cpp` into native build (CMakeLists / Gradle jni deps)

## 2. Integrate into three detect pipelines

- [x] 2.1 Call `validateRedFrame` at start of `zero_point::detectZeroPointFrame`; return `FRAME_REJECTED` JSON on reject
- [x] 2.2 Call `validateRedFrame` at start of `edgedrawing::detectEdgeDrawingFrame`; return `FRAME_REJECTED` JSON on reject
- [x] 2.3 Call `validateRedFrame` at start of `opencv_stain_detect::analyzeFrame`; skip `runFixedRoiTargetPipeline` on reject
- [x] 2.4 Remove or supersede lens_det `max_saturated_white_area_px` full-image gate per design (document deprecation)

## 3. App alignment

- [x] 3.1 Add `overexposed`, `invalid_non_red`, `no_valid_region`, `empty_roi` to `OpencvDetectCodes` (and reason parsing helpers if needed)
- [x] 3.2 Verify `ZeroPointDetectJson`, `EdgeDrawingDetectJson`, and `OpencvStainDetectResultMapper` classify new `-5` reasons as `FRAME_REJECTED`
- [x] 3.3 Confirm burst sampling triggers on new reasons without coordinator changes (or patch if reason filter exists)

## 4. Tests and docs

- [x] 4.1 Add `red_frame_validator_test.cpp` with red / purple / overexposed sample images (or synthetic mats)
- [x] 4.2 Extend `opencv_detect_codes_smoke_test.cpp` for new reason JSON snippets
- [x] 4.3 Update `OPENCV_DETECT_ERROR_CODES.md` and `ZERO_POINT_NATIVE_API.md` / `OPENCV_STAIN_DETECT_NATIVE_API.md` reason appendix
- [x] 4.4 Run `make sync` and smoke-test three frame types on emulator (red passes, purple/overexposed return `-5`)
