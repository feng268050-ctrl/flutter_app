## Context

The App AI layer split into:

| Path | API | Session gate | SSE `running.source` |
|------|-----|--------------|----------------------|
| Live weld PR1 | `AiManager.opencvStainDetectFromI420` | `tryAcceptOpencvLiveWeldInferSample` / `LIVE_WELD` 2000 ms | `live_stain_detect` |
| AI Vision live | `opencvStainDetectFromI420` | `tryAcceptOpencvAiVisionLiveInferSample` / `AI_VISION_LIVE` 500 ms | `live_stain_detect` (via mapper) |
| Process video | `opencvStainDetectFromI420` | `tryAcceptOpencvProcessVideoInferSample` / `AI_VISION_PROCESS_VIDEO` 200 ms | `offline_stain_detect` |

RKNN (`rknnStainDetectFromI420`, `rknnStainDetectFromJpg`) remains for legacy/engine paths but is not the process-video or primary weld runtime.

Gradle feature toggles (`ENABLE_LENS_DET_APP`, etc.) were removed — test and production share the same OpenCV session bootstrap.

## Decisions

1. **Keep capability id `lens-det-app-inference`** — rename in a future change if desired; delta updates content to OpenCV stain detect naming.
2. **Keep capability id `lens-guard-unified-inference-result`** — requirements now describe `AiStainDetectResult` as the unified wire type.
3. **SSE `start.source` vs `running.source`** — session start uses route-specific tags (`ai_vision_live`, `live_stain_detect`, `offline_stain_detect`); each `running` row carries stain-detect product source.
4. **No composited `/v1/camera/ai`** — LAN clients overlay client-side from SSE; matches process-video architecture.

## Risks

- External LAN clients may still expect `production_weld` or `preview_det` source strings — document migration in SSE spec scenarios.
