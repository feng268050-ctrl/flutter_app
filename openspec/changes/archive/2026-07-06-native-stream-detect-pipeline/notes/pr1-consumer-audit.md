# PR1 Consumer Audit (Phase 0)

Audit date: 2026-07-05. Source: `docs/Native Stream Detection Pipeline.md`.

## Current PR1 consumers

| Consumer | File | Role | Migration target |
|----------|------|------|------------------|
| Weld live infer coordinator | `LivePr1InferenceStreamCoordinator` | Laser ON → PR1 RTSP decode → I420 callback | C++ `StreamDetectPipeline` (Phase 1+) |
| Weld infer client | `LivePr1InferenceStreamClient` | EasyPlayer virtual Surface decode | Retire detect use; hub shares one instance until native |
| Manual zero-point auto | `ZeroPointManualAutoCoordinator` | Temporary second `LivePr1InferenceStreamClient` | `LivePr1InferenceStreamHub` lease (Phase 0) |
| PR1 frame fan-in | `LaserDetectSamplingCoordinator.onPr1Frame` | I420 → `LatestI420FrameHolder` + stain/zero gates | C++ internal scheduler (Phase 2) |
| Latest frame cache | `LatestI420FrameHolder` | Snapshots for zero_point / overlay | Retire live path (Phase 2) |
| Zero-point on laser | `ZeroPointDetectCoordinator` | Reads `LatestI420FrameHolder` | Subscribe `StreamDetectResultBus` (Phase 2) |
| Zero-point overlay | `ZeroPointOverlayPublisher` | Reads latest I420 for overlay dims | Bus results (Phase 2) |
| EdgeDrawing overlay | `EdgeDrawingOverlayPublisher` | Reads latest I420 | Bus results (Phase 2) |
| AI Vision live | `AiVisionFragment.runLiveInferSampleOnce` | `TextureView.getBitmap` → I420 → OpenCV | Disable Phase 0; C++ dual-link Phase 3 |
| RKNN LensGuard (legacy) | `LensGuardManager.onI420Frame` | Production weld RKNN push | Out of scope if OpenCV-only weld path |

## Non-PR1 paths (unchanged)

- **PR0 recording:** `EasyPlayerClientManger` — unaffected.
- **AI Vision playback:** `EasyPlayerClient` + `TextureView` — keep Java hard decode.
- **Process video detect:** ExoPlayer + `opencvStainDetectFromI420` @ 200ms — unchanged.

## Convergence plan

1. **Phase 0:** Single `LivePr1InferenceStreamHub`; disable AI Vision bitmap detect; baseline profiler.
2. **Phase 1:** Feature-flagged C++ pipeline replaces hub/Java decode for weld.
3. **Phase 2:** Coordinators + SSE subscribe bus; remove live I420 JNI.
4. **Phase 3:** AI Vision parallel Java play + C++ detect.
5. **Phase 4:** Reconnect, stale overlay, docs.

## Grep acceptance (live RTSP → Java I420 detect)

After Phase 2 complete, these MUST NOT appear on live weld/AI Vision RTSP hot path:

- `opencvStainDetectFromI420` with `StainDetectSource.LIVE` from Java decode callbacks
- `nativeOpencvZeroPointDetectFromI420` fed from `LatestI420FrameHolder` on laser-on
- `TextureView.getBitmap` in `AiVisionFragment` detect loop
