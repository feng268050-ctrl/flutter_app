## Context

Live `GET /v1/camera/ai` + weld StreamDetect are archived. Mobile clients treat process-video AI as supported only when `GET /v1/videos/:id/ai` returns `200` + `text/event-stream`. Linux still returns `503 process_video_ai_unavailable`. AI Vision tab is stub-only.

## Goals / Non-Goals

**Goals**

- Process-video Detect over LAN with media-relative `timestampMs` and `/ai/replay`.
- On-device AI Vision: live PR0 + overlay; select process video; Detect/Replay via shared session.
- Dual StreamDetect holders: weld wins over `ai_vision_live`.

**Non-Goals**

- Composited inference MP4 / H.264 fan-out.
- Cloud AI report screens.
- Complete zero-point interactive calibration.

## Decisions

1. **Session model** — Port lws-ui `ProcessVideoAiSession` / Registry (UI + HTTP holders). Sample grid = 500 ms (`AI_VISION_PROCESS_VIDEO`); 1× playback clock at ~15 fps ticks.
2. **Frame extract** — Bundled `/opt/hmi/bin/ffmpeg` JPEG at sample time (same binary as video covers).
3. **Infer** — Daemon `offline_infer_opencv_stain_jpg` → `OpencvStainDetectMapper` → SSE `running` + timeline frame.
4. **SSE hub** — Per-session hub with media-timeline clock (idle/start at 0; running/stop use media ms).
5. **Persistence** — Timeline JSON under `/var/lib/hmi/ai-vision-inference-videos/{owner}/…timeline.json`.
6. **Live AI Vision** — `AiVisionLiveStreamDetectCoordinator` on PR1 RTSP with `sessionSource: ai_vision_live`; skip start when weld holder running; publisher already maps `preview_stopped`.

## Risks / Trade-offs

- Offline JPG path is slower than NV12 JNI on Android; 1× clock may lag — acceptable for parity MVP.
- Missing daemon/ffmpeg → structured SSE `error` or 503 only when engine not ready (avoid false "unsupported" when ready).

## Migration

None. Additive routes and UI.
