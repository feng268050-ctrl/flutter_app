## Why

Recent commits (`e4a9436`, `6306153`, `04a54c0`, `849fa1a`) landed a large AI refactor without OpenSpec deltas: `LensGuardManager` → `AiManager`, `LensGuardInferenceResult` / `inferFromI420` removed, OpenCV stain detect (`opencvStainDetectFromI420`) became the primary runtime path for weld PR1, AI Vision live, and process video, JNI/types renamed from `lens_det` to `opencv_stain_detect`, Gradle `ENABLE_LENS_DET_*` toggles removed, sampling constant `PRODUCTION_WELD` → `LIVE_WELD`, weld alert types renamed to live/offline product model (`StainDetectSource`), and SSE/replay payloads unified on `AiStainDetectResult` + `runningData` (no separate `stainDetect` field).

Production specs still describe RKNN unified infer, composited production preview, `LensDetDetectCoordinator`, and obsolete SSE `source` / interval values.

## What Changes

- Document **OpenCV stain detect** as the default App runtime for live weld, AI Vision live, and process video; RKNN remains optional via `rknnStainDetectFrom*`.
- Rename sampling interval **`PRODUCTION_WELD` → `LIVE_WELD`** in specs.
- Rename production stream types **`ProductionInferenceStream*` → `LivePr1InferenceStream*`**, coordinator uses `isOpencvStainDetectSessionActive()`.
- SSE contract: **`start.source`** may be `live_stain_detect`, `offline_stain_detect`, or `ai_vision_live`; **`running.source`** uses `live_stain_detect` / `offline_stain_detect`; process-video **`samplingIntervalMs` = 200**.
- Replay frames use the **same JSON shape as SSE `running`** (via `AiStainDetectResultMapper.fromTimelineFrame`).
- Replace **`LensGuardInferenceResult`** spec references with **`AiStainDetectResult`** / **`OpencvStainDetectResult`**.
- AI Vision live overlay: **client `DetectionOverlayView`**, not on-frame compositor (align with recorded-video path).
- Remove production **composited H.264** requirements for `/v1/camera/ai` (SSE JSON only).

## Capabilities

### Modified Capabilities

- `ai-frame-sampling-inference`
- `production-ai-inference-stream-lifecycle`
- `lens-det-app-inference` (OpenCV stain detect APIs; name retained for traceability)
- `lens-guard-unified-inference-result` (wire type → `AiStainDetectResult`)
- `lens-guard-capability-profile` (`AiEngineCapabilityProfile`, `AiManager`)
- `device-local-http-ai-inference-sse`
- `device-local-http-video-ai`
- `ai-vision-live-inference-overlay`

## Impact

- **Specs only** — implementation already merged.
- Stale active changes `lens-det-emulator-session` and `production-lens-det-dirty-alerts` SHOULD be updated to reference `OpencvStainDetectCoordinator` and `isOpencvStainDetectSessionActive()` (follow-up in same PR).
