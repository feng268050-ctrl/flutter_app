## Why

AI Vision **Detect** on process videos temporarily showed a static cover instead of playing the recording, diverging from the HTTP client model (`GET /v1/videos/:id/stream` + `/ai` SSE) and from the archived SSE architecture. Production specs still described composited preview, RKNN `inferFromI420`, and inference-MP4 replay paths that the App no longer implements. Overlay geometry types also used **Inference** naming tied to RKNN, while process-video detect now uses OpenCV stain detect on an independent sampling path.

## What Changes

- **Detect UX**: ExoPlayer plays the **source recording** during an active session; `ProcessVideoAiSession` samples frames on a background worker only for detect/timeline/SSE (same separation as HTTP).
- **Overlay**: Client-side `DetectionOverlayView` synced to **player position**; box mapping via **`AiDetectOverlayGeometry`** (detect-frame dimensions → normalized → fit-center video bounds in the player view).
- **Replay / EOS**: Post-detect **Replay** plays the source MP4 with timeline overlay (not a legacy composited inference MP4).
- **Spec cleanup**: Remove compositor / `inferFromI420` / `LensGuardInferenceResult` requirements for the recorded-video detect path; document OpenCV process-video stain detect and timeline persistence instead.
- **Rename**: `InferenceOverlayGeometry` → `AiDetectOverlayGeometry`; `InferenceOverlayFrames` → `AiDetectOverlayFrames` (`toTimelineFrame`).

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `ai-vision-recorded-video-realtime`: Playback vs sampling separation, overlay mapping, EOS/Replay, OpenCV detect worker (not RKNN infer).
- `ai-frame-sampling-inference`: Align `AI_VISION_PROCESS_VIDEO` interval with code (200 ms); process-video path uses OpenCV gate, not unified RKNN infer.
- `lens-guard-unified-inference-result`: Client overlay mapping references `AiDetectOverlayGeometry` for recorded-video display (detect-frame vs display resolution).

## Impact

- `AiVisionFragment`, `ProcessVideoAiSession`, `DetectionOverlayView`
- `AiDetectOverlayGeometry`, `AiDetectOverlayFrames`
- `openspec/specs/ai-vision-recorded-video-realtime/spec.md` and related capability specs
