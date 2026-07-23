## 1. Unified result model and mapper

- [x] 1.1 Add `LensGuardInferenceResult` and `Box` types: required `level` (int) + `status` (String) on every instance; plus `success`, `code`, `message`, dimensions, `boxes`, `source`, `timestampMs`
- [x] 1.1b Mapper merge rules: JSON `level`/`status` in `message` override callback; JPG from JSON root; App errors use `level=-1`, `status=ERROR|BUSY`
- [x] 1.2 Extract `LensGuardInferenceResultMapper` from `AiVisionOverlayParser` + `ProcessVideoAiTimeline` (JSON parse, corrupt-box sanitize, `toOverlayBoxes()`)
- [x] 1.2b Extend shared frame compositor to draw status banner/text from `level`, `status`, `message` on bitmap (not `tvAiResult`)
- [x] 1.3 Add unit tests for mapper: `code:0` with boxes, plain `onCheckResult` text, error codes, corrupt batch filtering

## 2. LensGuardManager unified APIs

- [x] 2.1 Implement global in-flight lock + generation counter for unified infer; define busy/dropped result code constant
- [x] 2.2 Implement `inferFromJpg(String)` on RKNN thread via `guardedInferImageToJson` → mapper
- [x] 2.3 Implement `inferFromI420(byte[], w, h)`: push, one-shot `onCheckResult` correlation, timeout, mapper
- [x] 2.4 Wire `NativeListener.onCheckResult` to complete pending I420 waiters (ignore stale generation)
- [x] 2.5 Deprecate `inferJpgToJson` and public `onI420Frame` with JavaDoc; delegate deprecated methods to new APIs where feasible

## 3. Process video session integration (async hold-forward)

- [x] 3.1 Replace blocking `ensureInferredForEncodePosition` with async sample scheduler: extract JPEG → submit `inferFromJpg` on session executor; onComplete map to timeline `Frame` (`level`, `status`, boxes)
- [x] 3.2 `encodeTickOnWorker` MUST never await infer: use `timeline.findFrameAt(encodePosMs)` for hold-forward overlay; source-only when no completed sample yet
- [x] 3.3 When infer in-flight, skip scheduling new sample; encode continues with previous hold-forward result
- [x] 3.4 Verify composited preview + HTTP fan-out stay real-time (no stall when native infer > 200 ms)
- [x] 3.5 Remove direct `ProcessVideoAiTimeline.fromNativeJson` at session boundary

## 4. AI Vision live composited frames (hold-forward, no stacked overlay)

- [x] 4.1 Add `lastLiveInferenceResult` hold-forward store updated on async `inferFromI420` completion
- [x] 4.2 Refactor `sampleAiFrameFromTexture`: 500 ms gate → `liveInferExecutor` + `inferFromI420`; do not use `DetectionOverlayView.setBoxes` for live det
- [x] 4.3 Live display tick: capture camera bitmap → `ProcessVideoAiFrameRenderer.drawFrame` with hold-forward → show composited bitmap on preview surface (hide/disable stacked `DetectionOverlayView` for boxes)
- [x] 4.4 HTTP `/v1/camera/ai`: encode the **same** composited bitmaps (refactor `CameraAiHttpCompositor` away from separate canvas `drawOverlay` when composited-bitmap path active)
- [x] 4.5 In-flight: drop new 500 ms sample while busy; keep drawing last hold-forward result into frames
- [x] 4.6 Hide or stop updating stain status `TextView` on live tab during compositing; status only on frame pixels

## 5. PR1 production inference integration

- [x] 5.1 Add `productionInferExecutor` (single-thread) in production inference path
- [x] 5.2 Change `ProductionInferenceStreamClient` I420 callback: sampling gate → submit `inferFromI420` on worker (skip if busy)
- [x] 5.3 Gate compositor encode on `/v1/camera/ai` subscriber count > 0; draw boxes + status on bitmap only when gating true
- [x] 5.4 Without HTTP subscribers: keep `inferFromI420` for warnings/logs/alerts only; no composited PR1 video
- [x] 5.5 Verify laser OFF stops new submissions and clears/resets gates per existing lifecycle spec

## 6. Tests and docs

- [x] 6.1 Unit tests: in-flight drop (second call returns busy), I420 timeout, generation ignores stale callback
- [x] 6.2 Unit tests: live hold-forward keeps prior boxes when infer in flight; updates after completion
- [x] 6.3 Update `DetOnlyOpenSpecDeviceTest` / smoke tests to use `inferFromJpg` where appropriate
- [x] 6.4 Add short note to `docs/LENS_GUARD_APP_INTEGRATION.md` for unified APIs, hold-forward live + recorded, deprecations

## 7. Optional follow-up (out of scope if time-boxed)

- [x] 7.1 Feature flag `useUnifiedInference` for rollback (default true)
