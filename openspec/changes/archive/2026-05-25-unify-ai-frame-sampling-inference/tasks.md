## 1. Sampling abstraction

- 1.1 Add `AiFrameSamplingInterval` enum with `PRODUCTION_WELD` (2000 ms) and `AI_VISION_LIVE` (500 ms)
- 1.2 Implement `AiFrameSamplingGate` with `tryAccept(long)`, `reset()`, and monotonic clock
- 1.3 Add unit tests for gate: first frame, within interval, at boundary, burst after interval, reset

## 2. Production path (Quick / Engineer)

- 2.1 Wire production gate into `LensGuardManager.onI420Frame` before `byte[]` copy and executor submit
- 2.2 Reset production gate when inference stream stops (`ProductionInferenceStreamClient.stop` / coordinator laser OFF)
- 2.3 Add debug logging for accepted frames with profile `PRODUCTION_WELD` (throttled)

## 3. AI Vision live path

- 3.1 Replace `AiVisionFragment.AI_FRAME_SAMPLE_INTERVAL_MS` with `AiFrameSamplingInterval.AI_VISION_LIVE`
- 3.2 Add AI Vision live gate on `onBitmapFrame` entry; reset in `stopAiFrameSampling` / stream teardown
- 3.3 Confirm offline `inferJpgToJson` path unchanged (no gate on file-based sampling)

## 4. Verification

- 4.1 Run unit tests for `AiFrameSamplingGate`
- 4.2 Manual: Quick/Engineer laser ON — log shows LensGuard push at ~2 s intervals under load
- 4.3 Manual: AI Vision live — inference continues at ~500 ms; video playback smooth
- 4.4 Confirm `publishLastClsSnapshotIfDue` / contamination UX still acceptable at 2 s production interval