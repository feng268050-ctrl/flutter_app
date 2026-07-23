## 1. Native pipeline refactor

- [x] 1.1 Add `fixed_roi_pipeline.h/.cpp` with `FixedRoiParams` (roi x/y/w/h, enhance, invert, morphology, erode caps) and `runFixedRoiTargetPipeline(bgr, params)`
- [x] 1.2 Implement ROI clamp + crop; port `brightness_enhance` (CLAHE on V + `convertScaleAbs`) matching Python defaults
- [x] 1.3 Implement grayscale → bitwise_not → `THRESH_BINARY_INV(invert_thresh)` → `MORPH_OPEN` elliptical kernel
- [x] 1.4 Implement dynamic erode loop (max 6, stop when components ≥ 2, `min_blob_area=40`) and blob extraction in ROI coordinates
- [x] 1.5 Remove blue-line detect/exclude, HSV bright mask, and ref-height valid band from production path
- [x] 1.6 Wire `lens_det_analyzer.cpp` to new pipeline; map selected target to full-image coords before `target.json`

## 2. Configuration and types

- [x] 2.1 Update `lens_det_analyzer.h` `Options` — drop `bright_*` / `valid_region_ref_*`; add ROI + enhance/invert fields with defaults from design
- [x] 2.2 Update `native/lensinspector/config.yaml` `lens_det:` section; document deprecated keys in comment
- [x] 2.3 Ensure config loader maps new fields into `Options` (ignore or warn on legacy keys)

## 3. Tools, tests, and docs

- [x] 3.1 Update `native/lensinspector/tools/lens_det_infer` to use fixed ROI pipeline; optional `--dump-stages` for parity with Python
- [x] 3.2 Add regression: golden frame(s) from `xiaoheidian_frames_200ms` (3.0s / 5.0s / 8.6s) — native vs `lens_det_dump_stages.py --mode square-roi`
- [x] 3.3 Update `native/lensinspector/docs/LENS_DET_NATIVE_API.md` and `docs/OPENCV_DETECT_APP_INTEGRATION.md` (fixed ROI, no blue line)
- [x] 3.4 Run `native/lensinspector/scripts/verify_libai_jni.sh` — JNI symbols unchanged

## 4. Device verification

- [x] 4.1 Rebuild native (`make sync` or equivalent); deploy to RK3566 device
- [ ] 4.2 AI Vision live / process video: confirm lens_det overlay on 3.0s-class target; no regression on JNI failure paths
- [x] 4.3 Run `bash scripts/ci/verify-opencv-detect-integration.sh` after native deploy

## Out of scope (follow-up)

- Port Python `contamination_mode` target heuristics to C++ if 3.0s frame still fails after pipeline align
- App-side fixed ROI yellow box overlay on AI Vision preview
