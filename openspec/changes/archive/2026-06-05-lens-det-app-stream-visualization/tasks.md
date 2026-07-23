## 1. Native contract verification (no API change required for v1)

- [x] 1.1 Confirm `LENS_DET_NATIVE_API.md` summary + `target.json` contract matches device `libai.so`
- [x] 1.2 Run `make verify-opencv-detect` after `make ai`

## 2. JSON parsing and result types (Layer 3)

- [x] 2.1 Add `LensDetDetectJson` — parse summary JSON (`ok`, `code`, `reason`, `files`)
- [x] 2.2 Add `LensDetDetectResult` + mapper — read `target.json`, populate `targetX`/`targetY`
- [x] 2.3 Unit tests with fixture summary + target.json (success and failure cases)

## 3. AiManager one-shot APIs (Layer 2–4, mirror RKNN infer)

- [x] 3.1 Add `AiManager.inferLensDetFromI420` — `nativeOpencvStainDetectFromI420`, dedicated `lens-det-infer` coordinator
- [x] 3.2 Add `AiManager.inferLensDetFromJpg` — offline path
- [x] 3.3 Handle `!isRunning()`, invalid dimensions, and native errors → `LensDetDetectResult`
- [x] 3.4 Defer/skip when `isStainInferBusy()` with structured log

## 4. Sampling gates (对照 RKNN intervals)

- [x] 4.1 Add dedicated `AiFrameSamplingGate` instances for lens_det: production / live / process-video
- [x] 4.2 Wire gate reset on PR1 stop and AI Vision live stop (same lifecycle as RKNN gates)
- [x] 4.3 Unit tests: lens_det gate independent of RKNN gate timestamps

## 5. Real-time production path (Quick/Engineer PR1)

- [x] 5.1 Add `LensDetDetectCoordinator` — attach/detach, laser ON/OFF, 2000ms production sampling
- [x] 5.2 On tick: PR1 I420 snapshot → `inferLensDetFromI420` with session `outputDir`
- [x] 5.3 `LaserApplication.attach` / detach coordinator; TAG `LensDetDetect` logs
- [x] 5.4 Feature flag `ENABLE_LENS_DET_APP` (default off)

## 6. AI Vision live (500ms, 对照 inferFromI420)

- [x] 6.1 Add `LensDetHoldForwardStore` (or extend existing hold-forward) for live tab
- [x] 6.2 `AiVisionFragment`: optional lens_det mode — sample → `inferLensDetFromI420` → update hold-forward
- [x] 6.3 Compositor: draw target marker from `LensDetDetectResult` (distinct style from RKNN level colors)

## 7. Offline and process video

- [x] 7.1 Offline JPG entry: call `inferLensDetFromJpg`, display/log coordinates
- [x] 7.2 `ProcessVideoAiSession`: 500ms grid → `inferLensDetFromI420`, hold-forward overlay on playback clock

## 8. Visualization polish

- [x] 8.1 Map pixel `(x,y)` to compositor normalized coords using frame width/height
- [x] 8.2 Failed sample: retain previous marker; no fabricated points

## 9. Verification and docs

- [x] 9.1 Update `LENS_DET_NATIVE_API.md` App integration status to wired
- [x] 9.2 Update `docs/OPENCV_DETECT_APP_INTEGRATION.md` lens_det row (Coordinator + viz)
- [x] 9.3 Extend `verify-opencv-detect-integration.sh` DEX if new public classes added
- [ ] 9.4 Device smoke: engineer mode laser ON → log `LensDetDetect`; AI Vision live → visible marker
- [ ] 9.5 Deploy with `make sync`; logcat recipe in integration doc

## 10. Optional follow-ups (out of v1 scope)

- [ ] 10.1 Native: inline `target` in summary JSON to avoid file IO
- [ ] 10.2 HTTP SSE payload for lens_det results
- [ ] 10.3 Production Quick/Engineer on-screen overlay (not only log)
