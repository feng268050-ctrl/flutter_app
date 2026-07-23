# Live Detect Path Audit (Task 6.3)

Audit date: 2026-07-06. Confirms no **production** live RTSP path feeds detect via Java I420 / `getBitmap` when native flags match rollout policy.

## Policy

| Path | Live detect source | Gate |
|------|-------------------|------|
| Weld Quick/Engineer | C++ `StreamDetectPipeline` → bus | `isNativeWeldStreamDetectEnabled()` |
| AI Vision live | C++ parallel session **or** legacy bitmap | `isNativeAiVisionStreamDetectEnabled()` / `isAiVisionLiveBitmapDetectEnabled()` |
| AI Vision 4.4 fallback | **None** (playback only) | both detect flags `false` |
| Process video (offline) | ExoPlayer frame → `opencvStainDetectFromI420` | unchanged (500 ms grid) |

## Grep audit — live RTSP

| Location | Symbol | Status |
|----------|--------|--------|
| `AiVisionFragment.runLiveInferSampleOnce` | `getBitmap` + `opencvStainDetectFromI420` | **Gated** — returns early unless `isAiVisionLiveBitmapDetectEnabled()` && !native AI Vision |
| `AiVisionFragment.sampleAiFrameFromTexture` | schedules bitmap path | **Gated** — no-op when `isNativeAiVisionStreamDetectEnabled()` |
| `LaserDetectSamplingCoordinator` | `LatestI420FrameHolder.offer` | **Gated** — skipped when `isNativeWeldStreamDetectEnabled()` |
| `LivePr1InferenceStreamHub` | `LivePr1InferenceStreamClient` | **Gated** — hub returns false when native weld on |
| `ZeroPointDetectCoordinator` | `LatestI420FrameHolder` / JNI | **Gated** — native weld uses bus subscriber path |
| `OpencvStainDetectCoordinator` | live PR1 I420 | **Removed** for live; bus subscriber only |
| `ProcessVideoAiSession` | `opencvStainDetectFromI420` | **OK** — offline / file retriever, not live RTSP |

## Residual legacy (intentional)

- `LivePr1InferenceStreamClient` + `LatestI420FrameHolder` remain for **flag-off rollback** (Phase 1–2 migration plan).
- `AiVisionFragment` bitmap path remains behind `isAiVisionLiveBitmapDetectEnabled()` (default `false`).

## Code review checklist

- [x] No unguarded live `nativeOpencv*FromI420` call sites outside offline / manual test
- [x] AI Vision overlay uses `StreamDetectOverlayBridge` when native AI Vision on
- [x] Weld coordinators subscribe to `StreamDetectResultBus` when native weld on
- [ ] Remove rollback classes after production flag default flip (task 5.6b)

**Verdict:** PASS for 6.3 code review (rollback code retained by design).
