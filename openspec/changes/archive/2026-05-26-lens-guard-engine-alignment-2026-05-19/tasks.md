## 1. Capability profile foundation

- [x] 1.1 Add `LensGuardCapabilityProfile` (fields: `classificationEnabled`, `detectionEnabled`, `offlineInferJsonAvailable`, `focusMonitoringExpected`) in `com.lasercyber.lws.ai`
- [x] 1.2 Implement lightweight parser for `files/lens_guard/config.yaml` keys `models.cls.enabled` / `models.det.enabled` with engine-aligned defaults on failure
- [x] 1.3 Build profile in `LensGuardManager` after successful `nativeCreate` + `guardedStart`; rebuild on destroy/create
- [x] 1.4 Add offline JNI probe (catch `UnsatisfiedLinkError` or single guarded call) and set `offlineInferJsonAvailable`
- [x] 1.5 Expose `getCapabilities()` (or equivalent) for UI and `AiVisionFragment`

## 2. Offline infer JSON pipeline

- [x] 2.1 Replace `SKIP_OFFLINE_INFERENCE_FOR_UPLOAD` compile-time bypass with runtime check against `offlineInferJsonAvailable`
- [x] 2.2 Ensure upload/export paths validate inference MP4 exists and non-empty when offline infer is required
- [x] 2.3 Verify `inferJpgToJson` error JSON matches `AiVisionFrameInference.fromNativeJson` expectations (`code`, `CLEAN`/`MILD`/`HEAVY`, pixel `boxes`)
- [x] 2.4 Add/adjust log lines for missing `nativeInferImageToJson` pointing to ai-library / `nm` verification

## 3. Det-only UI and state decoupling

- [x] 3.1 Add string resource for classification-disabled state (zh/en)
- [x] 3.2 Update `AiVisionFragment.onLensClsSnapshot` to branch on `classificationEnabled` vs invalid snapshot
- [x] 3.3 Update `AiVisionFragment.onLensGuardStateChanged` (and any laser-coupled state UI) to respect `focusMonitoringExpected`
- [x] 3.4 Audit weld/monitor code for hard dependency on `LensGuardStateEvent` state `== 1`; decouple or gate with profile
- [x] 3.5 Confirm `onCheckResult` / `preview_det` overlay parsing unchanged; no cls-from-message parsing

## 4. JNI sync and packaging

- [x] 4.1 Diff `NativeBridge.java` JNI declarations against lensinspector reference; fix any drift
- [x] 4.2 Confirm Workers `ai-library` manifest / `make build` targets zip whose `libai.so` exports `nativeInferImageToJson`
- [x] 4.3 Document release gate in `AI_VISION_LIBAI_JNI_ALIGNMENT.md` or alignment doc cross-link (if needed)

## 5. Verification

- [ ] 5.1 Desk: `nm -D libai.so | grep nativeInferImageToJson` on deployed artifact
- [ ] 5.2 Device: live 1280×720 push + stain `onCheckResult` (laser OFF)
- [ ] 5.3 Device: AI Vision preview_det overlay
- [ ] 5.4 Device: offline video → timeline → inference MP4 → upload (no «推理视频尚未准备好» when so capable)
- [ ] 5.5 Device: det-only — cls UI shows disabled; laser ON without MONITORING; `getLastClsResult` invalid expected
- [ ] 5.6 Optional regression: `models.cls.enabled: true` + session restart → MONITORING + cls snapshot restore
