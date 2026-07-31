## Why

Phone "Detect selected video" always fails with "device does not support AI visualization" because `GET /v1/videos/:id/ai` returns plain 503. On-device Monitor → AI Vision remains a chrome stub. Live camera AI SSE is already shipped; this change adds process-video AI SSE (phone) and AI Vision UI (device).

## What Changes

- Add `ProcessVideoAiSession` (+ registry, ffmpeg frame sampler, timeline persistence) with media-relative SSE `timestampMs`.
- Wire `GET /v1/videos/:id/ai` → `text/event-stream` when daemon ready; `GET …/ai/replay` → `ApiResult` frames.
- Extend `AiDaemonSupervisor` with `offline_infer_opencv_stain_jpg`.
- Replace `AiVisionTab` stub: PR0 live preview, overlay HUD, choose video / Detect / Replay, info panel.
- Add `AiVisionLiveStreamDetectCoordinator` (`sessionSource: ai_vision_live`) with weld-holder arbitration.
- Home AI Vision quick action navigates to Monitor AI Vision tab.
- Update main specs for device-local HTTP process-video AI and product Monitor AI Vision.

## Capabilities

### New Capabilities

- `process-video-ai-sse`: Process-video offline infer session, LAN SSE + replay contract (media timeline).
- `product-ai-vision-ui`: On-device AI Vision tab (live PR0, overlay, select/Detect/Replay, Home entry).

### Modified Capabilities

- `device-local-http-api`: Replace constant 503 on `/v1/videos/:id/ai` with SSE-when-ready; document `/ai/replay`.
- `camera-ai-stream-detect-bridge`: Dual-holder arbitration for `ai_vision_live` vs weld `live_stain_detect`.
- `ai-daemon-unix-socket-ipc`: Document offline JPG infer cmd used by process-video path.

## Impact

- App: `features/ai/**`, `features/monitor/**`, `device_local_http_server.dart`, Home navigation.
- Requires board `/opt/hmi/bin/lws_ai_daemon` and bundled `ffmpeg`.
- Out of scope: composited H.264 encode, cloud AI report UI, full zero-point calibration UX.
