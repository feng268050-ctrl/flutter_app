## Why

On-device Java cannot sustain real-time video compositing (burning detection boxes and status into H.264) on current tablet hardware. Today **`GET /v1/camera/ai`** and **`GET /v1/videos/:video_id/ai`** relay composited encoded streams, and AI Vision mirrors that with bitmap compositing—duplicating work the device cannot afford. LAN/mobile clients are not in production yet, so we can replace these endpoints with a lightweight **SSE text stream** of timestamped inference results and let consumers draw overlays (subtitle/danmaku style) on their own video players.

## What Changes

- **BREAKING**: **`GET /v1/camera/ai`** no longer returns `video/H264` or `video/mp2t`. It returns **`text/event-stream`** (SSE) with JSON inference events keyed by **`timestampMs`** (and optional stream clock fields).
- **BREAKING**: **`GET /v1/videos/:video_id/ai`** same SSE contract; no composited MP4 live fan-out.
- **Remove** server-side compositor encoders for HTTP AI paths (`CameraAiHttpCompositor`, `ProcessVideoAiSession` HTTP H.264 fan-out, production PR1 compositing **only for HTTP subscribers**).
- **AI Vision live**: play camera RTSP on existing player; draw overlays on a **`TextureView`** (or equivalent) from `LensGuardInferenceResult` hold-forward—**no** bitmap burn-in compositor for preview.
- **AI Vision recorded**: play source MP4 (or stream) on player; overlay from session timeline via client-side `TextureView` / `DetectionOverlayView` mapping by playback position—**no** `ProcessVideoAiCompositedPreview` composited encode path.
- **Document** pairing: video from **`GET /v1/camera/live`** + inference from **`GET /v1/camera/ai`**; process video from **`GET /v1/videos/:id/stream`** + inference from **`GET /v1/videos/:id/ai`**.
- **No backward compatibility** with prior H.264/TS AI stream URLs or `X-Camera-Ai-Mode` / `format` query parameters.

## Capabilities

### New Capabilities

- `device-local-http-ai-inference-sse`: Shared SSE wire format, event types, timestamps, error/heartbeat semantics, and subscriber fan-out for both camera and process-video routes.

### Modified Capabilities

- `device-local-http-camera-ai`: Replace composited/pass-through video relay with SSE inference stream tied to live camera infer sampling.
- `device-local-http-video-ai`: Replace composited live video with SSE inference stream tied to `ProcessVideoAiSession` timeline sampling.
- `device-local-http-api`: Route registration and response types for the two `/ai` endpoints.
- `ai-vision-live-inference-overlay`: Client-side overlay on player surface instead of composited pixels.
- `ai-vision-recorded-video-realtime`: Client-side timeline overlay; drop composited preview/HTTP encode requirements.
- `lens-guard-unified-inference-result`: Hold-forward applies to overlay UI/SSE publishers, not device-side frame compositing for display/HTTP.
- `production-ai-inference-stream-lifecycle`: Remove HTTP-subscriber-driven compositor encoder; production infer continues for engine/alerts only.

## Impact

- **Java**: `DeviceLocalHttpServer`, `CameraAiHttpPublisher`, `CameraAiHttpCompositor`, `ProcessVideoAiSession`, `ProcessVideoAiCompositedPreview`, `ProductionInferenceStreamClient` HTTP compositor hooks, `AiVisionFragment` preview paths, `InferenceOverlayFrames` / `ProcessVideoAiFrameRenderer` HTTP usage.
- **Specs/docs**: `docs/network-api-reference.md` (when updated during apply).
- **Tests**: `DeviceLocalHttpCameraAiRouteTest`, process-video AI HTTP tests, overlay/compositor unit tests.
- **Out of scope for this change**: Cloud Worker APIs; `GET /v1/camera/live` and `GET /v1/videos/:id/stream` remain video byte streams.
