## 1. Native — line detect and shared preprocess

- [x] 1.1 Land `brightest_line_in_box.cpp/.h`, `roi_preprocess.cpp/.h`, `DetectTargetMode` in `zero_point_types.h`, and dispatcher in `zero_point_detector.cpp` (per `docs/ZERO_POINT_CONTINUOUS_SPOT_WELD_DESIGN.md` §4)
- [x] 1.2 Add `line_not_found` to `opencv_detect_codes.h` and document in `OPENCV_DETECT_ERROR_CODES.md`
- [x] 1.3 Wire `zero_point_infer --mode line|point` and `--no-red-gate`; verify on `lianxu.jpg` (line) and spot fixture (point)
- [x] 1.4 Update `ZERO_POINT_NATIVE_API.md` with `DetectTargetMode`, JNI/session setMode, and line failure semantics

## 2. Native — simplified red-frame gate

- [x] 2.1 Remove OSD sub-rectangle zeroing (A4) from `red_frame_validator.cpp`
- [x] 2.2 Remove overexposure and non-red HSV rejection (A7) from production `validateRedFrame` verdict; keep metrics for stages/log only
- [x] 2.3 Add/adjust native unit or infer tests for mask-only pass on dark continuous-weld fixture

## 3. JNI and deploy

- [x] 3.1 Expose detect target mode on zero-point native session (create-time or `setDetectTargetMode` before detect); update `NativeBridge` if signature changes
- [x] 3.2 Update `verify_libai_jni.sh` REQUIRED symbols when JNI changes
- [x] 3.3 Build and deploy: `make ai` then `make sync` (or `make sync-native` only if JNI unchanged)

## 4. Java — unified ZERO_POINT and weld-mode routing

- [x] 4.1 `ZeroPointDetectAlgorithmSelector`: always return `ZERO_POINT`; remove RadialCircleFit fallback counting for production laser-on path
- [x] 4.2 `ZeroPointDetectNativeSession`: stop create/call EdgeDrawing handle; set Point/Line mode from `WeldModeHost.getActiveWeldModelType()` before each detect (or once per round)
- [x] 4.3 `ZeroPointDetectCoordinator` / `ZeroPointManualAutoCoordinator`: pass weld mode; log `mode=line|point` on sample
- [x] 4.4 Confirm `EdgeDrawingDetectCoordinator` is not attached for laser-on zero-point on L1 Pro

## 5. Tests

- [x] 5.1 Update `ZeroPointDetectAlgorithmSelectorTest` — L1 Pro expects ZERO_POINT, no EdgeDrawing
- [x] 5.2 Add weld-mode routing test (CONTINUOUS → Line, POINT → Point)
- [x] 5.3 Add `ZeroPointCorrectionMapperTest` / JSON parse coverage for `line_not_found`
- [x] 5.4 Run `./gradlew :app:testDebugUnitTest` for affected AI packages

## 6. OpenSpec archive prep

- [x] 6.1 After implementation, archive change `zero-point-continuous-spot-weld` so main specs replace L1 Pro → EdgeDrawing with unified zero_point + Point/Line
- [x] 6.2 Verify `openspec/specs/zero-point-detect-on-laser-on/spec.md` no longer lists `nativeOpencvEdgeDrawingDetectFromI420` for laser-on samples

## 7. Device acceptance

- [ ] 7.1 L1 + L1 Pro: continuous weld laser-on round — logcat shows `nativeOpencvZeroPointDetectFromI420`, `mode=line`, valid or `line_not_found` samples
- [ ] 7.2 L1 + L1 Pro: point weld laser-on round — `mode=point`, no `spot_size_above_max` on typical spot frames
- [ ] 7.3 Laser OFF finalize: cluster reducer + 0090H / H034 unchanged
