## 1. SSE core and HTTP routes

- [x] 1.1 Add `AiInferenceSsePublisher` (serialize `LensGuardInferenceResult` → SSE `inference` / `heartbeat` / `error`)
- [x] 1.2 Wire `DeviceLocalHttpServer.serveCameraAi` and `serveVideoAi` to SSE (`text/event-stream`); remove H.264/TS chunked responses and `format` query handling on `/ai`
- [x] 1.3 Implement `CameraAiSsePublisher` fan-out from live infer paths (AI Vision live + production when active)
- [x] 1.4 Implement `ProcessVideoAiSsePublisher` fan-out from `ProcessVideoAiSession` timeline append callbacks with `streamTimeMs`
- [x] 1.5 Update/remove tests (`DeviceLocalHttpCameraAiRouteTest`, video AI route tests) for SSE content-type and sample event JSON

## 2. Remove server-side compositing

- [x] 2.1 Delete or gut `CameraAiHttpCompositor`, `CameraAiHttpPublisher` video mux paths, and `CameraHttpStreamFormat` usage on `/ai`
- [x] 2.2 Remove `ProcessVideoAiSession.acquireHttpSubscriber` H.264 fan-out, compositor encoder loop, and `.mp4.tmp` mux for preview/HTTP
- [x] 2.3 Remove `ProcessVideoAiCompositedPreview` from AI Vision recorded detect flow
- [x] 2.4 Remove production HTTP compositor hooks in `ProductionInferenceStreamClient` / `CameraAiHttpActiveSignal` tied to encoded relay
- [x] 2.5 Gate or disable `AiVisionInferenceVideoUploadRunner` composited-MP4 readiness until upload follow-up is defined

## 3. AI Vision client overlay

- [x] 3.1 Live tab: overlay `TextureView` / `DetectionOverlayView` above player; update from `LensGuardHoldForwardStore`; remove `ProcessVideoAiFrameRenderer` live burn-in
- [x] 3.2 Recorded tab: ExoPlayer on source file + timeline `findFrameAt` overlay; remove composited preview player path
- [x] 3.3 Ensure sampling intervals unchanged (`AI_VISION_LIVE` 500 ms, `AI_VISION_PROCESS_VIDEO` 200 ms) and in-flight drop policy preserved
- [x] 3.4 Manual: live RTSP + overlay; recorded Detect + overlay track playback position

## 4. Documentation and specs archive prep

- [x] 4.1 Update `docs/network-api-reference.md` with SSE pairing (`/live`+`/camera/ai`, `/stream`+`/videos/.../ai`), example `curl -N`, event JSON shape
- [x] 4.2 Run `openspec validate ai-inference-sse-client-overlay --strict` and fix any spec issues
