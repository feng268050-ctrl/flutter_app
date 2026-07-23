## 1. Native — lens_det independent session

- [x] 1.1 Add `lens_det::Session` (or equivalent) holding `lens_det::Options` from `load_config` + `lensDetOptionsFromAppConfig`
- [x] 1.2 Implement `nativeCreateOpencvLensDetSession` / `nativeDestroyOpencvLensDetSession` in `lens_det_jni.cpp`
- [x] 1.3 Change `nativeOpencvStainDetectFromJpg/Rgb/I420` first `long` param to `ldHandle`; remove RKNN `lens_app_config_from_handle` dependency
- [x] 1.4 Update `native/lensinspector/docs/LENS_DET_NATIVE_API.md` with session API and **BREAKING** handle semantics
- [x] 1.5 Add new JNI symbols to `verify_libai_jni.sh` `REQUIRED` array; run `make ai` + verify script on `arm64-v8a/libai.so`

## 2. Java Layer 2 — NativeBridge

- [x] 2.1 Declare `nativeCreateOpencvLensDetSession` / `nativeDestroyOpencvLensDetSession` in `NativeBridge.java`
- [x] 2.2 Update `nativeOpencvStainDetectFrom*` Java signatures/docs: first param is `ldHandle`

## 3. AiManager — session lifecycle and availability

- [x] 3.1 Add `lensDetHandle` field, `isLensDetAvailable()`, `ensureLensDetSession(Context)`, destroy in `stop()`
- [x] 3.2 Emulator `start()` branch: after `ensureLoaded`, call `AssetDeployer.deploy` + `ensureLensDetSession` (do not skip deploy)
- [x] 3.3 Device `start()` branch: after RKNN create succeeds, call `ensureLensDetSession` with same deploy paths
- [x] 3.4 `inferLensDetFromI420/Jpg`: gate on `isLensDetAvailable()`; pass `lensDetHandle` to native (not RKNN `handle`)
- [x] 3.5 `tryAcceptLensDetProduction/Live/ProcessVideoInferSample`: gate on `isLensDetAvailable()` instead of `handle != 0`

## 4. Process video offline (AI Vision)

- [x] 4.1 `ProcessVideoAiSession.isProcessVideoOfflineInferenceAvailable`: lens_det-only path uses `isLensDetAvailable()`
- [x] 4.2 `ProcessVideoAiSession.tryCreate`: when only `ENABLE_LENS_DET_APP`, require `isLensDetAvailable()` not `isRunning()`
- [x] 4.3 Confirm existing `runInferSample` lens_det path unchanged except infer now succeeds on emulator

## 5. Live and production coordinators

- [x] 5.1 `AiVisionFragment.runLiveInferSampleOnce`: allow lens_det when `isLensDetAvailable()` (RKNN block still uses `isRunning()`)
- [x] 5.2 `LensDetDetectCoordinator`: production sampling uses `isLensDetAvailable()` via `AiManager` gates (no direct `isRunning()` assumption)

## 6. Documentation and CI

- [x] 6.1 Update `docs/OPENCV_DETECT_APP_INTEGRATION.md` — lens_det handle table, emulator验收章节（arm64 AVD、本地上传工艺视频）
- [x] 6.2 Update `docs/LENS_GUARD_APP_INTEGRATION.md` §2.1 if it states lens_det requires RKNN `isRunning()`
- [ ] 6.3 Run `bash scripts/ci/verify-opencv-detect-integration.sh` on built APK after `make sync`

## 7. Verification (emulator + device)

- [ ] 7.1 Build: `./gradlew :app:assembleDebug -PENABLE_LENS_DET_APP=true`; `make sync` to **arm64-v8a** AVD
- [ ] 7.2 Emulator: `adb logcat` shows lens_det session created; `isLensDetAvailable` path; no RKNN `nativeCreate`
- [ ] 7.3 Emulator: upload local process video → AI Vision Detect → `process_video_lens_det sample_ok/sample_fail` in logcat
- [ ] 7.4 Emulator: timeline / overlay shows lens_det marker when `hasTarget()` (or hold-forward from completed samples)
- [ ] 7.5 Device regression: RK3566 with `ENABLE_LENS_DET_APP=true` — production + process video lens_det still work; RKNN unaffected when enabled
