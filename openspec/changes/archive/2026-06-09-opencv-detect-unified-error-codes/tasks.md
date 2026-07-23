## 1. Native shared contract

- [x] 1.1 Add `native/lensinspector/src/opencv_detect/opencv_detect_codes.h` with `OK`, `INVALID_HANDLE`, `INVALID_INPUT`, `DETECT_FAILED`, `IO_ERROR`, `FRAME_REJECTED`, `CONFIG_ERROR` and documented reason token constants
- [x] 1.2 Add shared JSON helper (optional `opencv_detect_json.h`) emitting `ok`, `code`, `reason` for failures
- [x] 1.3 Wire `zero_point_jni.cpp` / `zero_point_detector.cpp` to shared codes and snake_case reasons
- [x] 1.4 Wire `opencv_stain_detect_jni.cpp` / `opencv_stain_detect_analyzer.cpp` to shared codes; split current `-1` into `-1` vs `-2`; move mkdir to `-4`
- [x] 1.5 Add or extend native smoke/golden tests for code+reason matrix (zero_point_infer + opencv_stain_detect_infer)

## 2. Documentation

- [x] 2.1 Merge `ZERO_POINT_NATIVE_API.md` and `OPENCV_STAIN_DETECT_NATIVE_API.md` code tables; add per-module `reason` appendix
- [x] 2.2 Add migration table (old code → new code + reason) in design or docs
- [x] 2.3 Update `docs/OPENCV_DETECT_APP_INTEGRATION.md` logcat examples with unified `code`/`reason` format

## 3. App Java

- [x] 3.1 Add `OpencvDetectCodes.java` mirroring native enum
- [x] 3.2 Update `ZeroPointDetectJson` parse + logging; deprecate `CODE_SPOT_SIZE_REJECTED` in favor of `FRAME_REJECTED` + reason
- [x] 3.3 Update stain detect result mapper(s) to use `OpencvDetectCodes`
- [x] 3.4 Unify Coordinator log lines: `detect_result module=... code=... reason=...`
- [x] 3.5 Add `OpencvDetectCodesTest` covering mapping and both modules' sample JSON payloads

## 4. CI and device verification

- [x] 4.1 Extend `scripts/ci/verify-opencv-detect-integration.sh` if needed (DEX symbols + doc cross-links)
- [x] 4.2 Run unit tests and native CLI parity on golden images
- [ ] 4.3 Device smoke: trigger zero_point `-5` (spot size) and lens_det `-5` (saturation) and confirm distinct `reason` tokens in logcat
