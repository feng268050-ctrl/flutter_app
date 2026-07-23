## 1. Java algorithm selector

- [x] 1.1 Add `ZeroPointDetectAlgorithmSelector` in `com.lasercyber.lws.ai` with `Algorithm` enum (`ZERO_POINT`, `SCAN_V_CHANNEL_RADIAL_ADAPTIVE`) and `resolve(String rawModel)` via `ProcessLibraryAssetSelector.normalizeDeviceModel`
- [x] 1.2 Map only **L1** → `ZERO_POINT`, **L1 Pro** → `SCAN_V_CHANNEL_RADIAL_ADAPTIVE` (Pro before L1, case-insensitive); misconfigured ROM logs warning and defaults to `ZERO_POINT`
- [x] 1.3 Add dispatch helper or document per-coordinator JNI call site so exactly one `NativeBridge` detect function runs per sample
- [x] 1.4 Add `ZeroPointDetectAlgorithmSelectorTest` for `L1`, `L1 Pro`, `LaserCyber L1`, `LaserCyber L1 Pro`, `l1 pro` — no other product models

## 2. Coordinator gating (Java orchestration unchanged)

- [x] 2.1 Gate `ZeroPointDetectCoordinator`: active only when algorithm is `ZERO_POINT`; inactive coordinator must not call native detect
- [x] 2.2 Gate `EdgeDrawingDetectCoordinator`: active only when algorithm is `SCAN_V_CHANNEL_RADIAL_ADAPTIVE`
- [x] 2.3 Replace `BuildConfig.USE_EDGEDRAWING_ZERO_DETECT` with selected algorithm for pending-store clear and Modbus correction ownership
- [x] 2.4 Log normalized model + selected algorithm once on attach

## 3. ScanVChannelRadialAdaptive: one frame one JSON

- [x] 3.1 Remove native EMA temporal smoothing from `detectScanVChannelRadialAdaptiveInBox` on App JNI path (no cross-call state; each frame independent)
- [x] 3.2 Keep or trim `resetScanVChannelRadialAdaptiveTemporalSmoothing` if no longer needed in production
- [x] 3.3 Verify consecutive offline/App JNI calls do not blend prior frame results

## 4. Shared zero_point_mock.json

- [x] 4.1 In `EdgeDrawingDetectCoordinator.runNativeSample`, mirror zero-point mock flow: `ZeroPointMockJsonLoader.tryLoadSample()` before native; skip JNI on mock hit
- [x] 4.2 Map mock sample to `EdgeDrawingDetectJson.Sample` (use `EdgeDrawingDetectJson.parse` on same JSON string, or convert from `ZeroPointDetectJson.Sample`; optional `base_x`/`base_y` in mock file)
- [x] 4.3 In `onPr1I420Frame`, use `ZeroPointMockJsonLoader.mockFileExists()` for skip-when-no-frame logic (same as `ZeroPointDetectCoordinator`)
- [x] 4.4 Extend or add unit test: EdgeDrawing coordinator uses mock when file present on non-release channel

## 5. Build and cleanup

- [x] 5.1 Confirm native detect code has no Machine Model branching
- [x] 5.2 Remove or document `USE_EDGEDRAWING_ZERO_DETECT` in `app/build.gradle.kts` if unused

## 6. Verification

- [x] 6.1 Unit test: inactive coordinator never sets `activeEventId` when algorithm mismatches
- [ ] 6.2 Emulator `model=L1`: only `nativeOpencvZeroPointDetectFromI420` on laser ON; mock file skips native
- [ ] 6.3 Emulator `model=L1 Pro`: only `nativeOpencvEdgeDrawingDetectFromI420`; mock file skips native; JSON per-frame independent
