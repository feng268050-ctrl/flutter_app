## 1. Native JSON contract

- [x] 1.1 Extend `frameResultToJson` in `zero_point_json.cpp` to emit `ok`, `code`, `offset_x`, `offset_y` (preserve existing offset fields)
- [x] 1.2 Update `native/lensinspector/docs/ZERO_POINT_NATIVE_API.md` with new JSON shape and sign convention for App
- [x] 1.3 Rebuild `libai.so` (`make ai` or CI) and verify JNI smoke still passes

## 2. Sampling constant

- [x] 2.1 Add `ZERO_POINT_ON_LASER(500L)` to `AiFrameSamplingInterval`
- [x] 2.2 Add unit test asserting interval value and independence from `PRODUCTION_WELD` / `AI_VISION_LIVE` gates

## 3. Latest I420 frame holder

- [x] 3.1 Add thread-safe latest I420 snapshot holder updated from `ProductionInferenceStreamClient` decode callback (direct buffer copy + width/height)
- [x] 3.2 Expose read API for zero-point coordinator (`copyLatestI420()` or equivalent)

## 4. ZeroPointDetectCoordinator

- [x] 4.1 Create `ZeroPointDetectCoordinator` singleton: listen `DeviceStatus` laser OFF→ON, schedule samples at +500/+1000/+1500/+2000 ms, cancel on laser OFF or re-trigger
- [x] 4.2 Lifecycle: create/destroy `nativeCreateOpencvZeroPointDetector` with ROI JSON path (bootstrap under `files/lens_guard/` or documented asset deploy)
- [x] 4.3 On each tick: pull I420 snapshot, call `nativeOpencvZeroPointDetectFromI420` on dedicated single-thread executor
- [x] 4.4 Parse JSON; collect valid samples (`ok == true`); compute `meanOffsetX`, `uiDelta = round(-meanOffsetX/3)`, `newUi = clamp(current + uiDelta, -30, 30)`

## 5. Persist and Modbus write

- [x] 5.1 Read/write current `zeroPointCorrection` from Room / `AdvancedSettingViewModel`
- [x] 5.2 After successful aggregation, update UI model if Advanced Settings visible (optional refresh) and write 0090H via existing Modbus builder (value × 10)
- [x] 5.3 Skip write when zero valid samples; log outcome (videoId/laser event id, meanOffsetX, uiDelta, newUi)

## 6. Integration and wiring

- [x] 6.1 Register coordinator from `LaserApplication` (or existing laser/camera bootstrap) after Modbus status cache is live
- [x] 6.2 Ensure PR1 sub-stream starts on laser ON before first +500ms tick (coordinate with `ProductionInferenceStreamCoordinator`)
- [x] 6.3 Avoid blocking stain infer: defer or skip zero-point tick if shared native lock busy (document chosen behavior in code comment)

## 7. Verification

- [x] 7.1 Unit tests: `uiDelta` sign inversion and clamp (`-9px → +3`, `+12px → -4`, clamp at ±30)
- [x] 7.2 Unit tests: task schedule generates 4 deadlines; cancel on laser OFF
- [ ] 7.3 Manual: laser ON on device → log shows 4 native calls → `zeroPointCorrection` / Modbus 0090H updates when ROI/reference valid
