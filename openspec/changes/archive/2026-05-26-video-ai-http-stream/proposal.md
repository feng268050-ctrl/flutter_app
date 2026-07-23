## Why

LAN clients can list process videos and play **raw** recordings via **`GET /v1/videos/:video_id/stream`**, and can watch **live** AI-overlay camera output via **`GET /v1/camera/ai`**. **AI Vision** today treats a selected process video differently: it runs **batch** offline inference (progress UI, no overlay playback until finished), then plays a file from disk. Operators expect the **same real-time AI overlay experience** as the camera tab—while still persisting an inference MP4 for upload—and LAN tools need to **subscribe to that same composited encoded stream** over HTTP, not poll for a finished file.

## What Changes

- **AI Vision selected video → real-time pipeline:** On select, start **immediate playback** of the source MP4 with **live-style** inference and overlay (`AiFrameSamplingInterval.AI_VISION_PROCESS_VIDEO` (200 ms) for inference sampling, `LensGuardManager` preview det/cls, `DetectionOverlayView` / compositor path aligned with live tab). **Remove** the current behavior that blocks playback until the full video is analyzed offline.
- **Parallel disk capture:** While processing, mux the **composited** output to **`…/ai-vision-inference-<owner>-<cacheKey>.mp4.tmp`**; on successful end-of-stream, **atomically rename** to **`.mp4`**. On cancel/error, delete `.tmp` and keep or invalidate cache per design.
- **`GET /v1/videos/:video_id/ai`:** **Chunked live stream** (default Annex-B H.264, optional `?format=ts`), reusing the same publisher/compositor fan-out model as **`GET /v1/camera/ai`** (`CameraHttpStreamPublisherCore`, composited access units, `X-*` format/mode headers). HTTP subscribers attach to the **active real-time session** for that `video_id`; **no 503 poll-for-file** in the primary path.
- **Shared session:** One **`ProcessVideoAiSession`** per `(video_id, cacheKey)` shared by AI Vision UI and HTTP (reference-counted subscribers, single decode + single compositor encode).
- Extract session orchestration out of `AiVisionFragment` (coordinator + publisher).
- Document routes in `docs/network-api-reference.md`.
- **v1 HTTP:** `GET …/ai` is **live composited stream only**; when no session is active, a new request starts a **new** real-time run from the beginning (no static Range on completed `.mp4`).

## Capabilities

### New Capabilities

- `ai-vision-recorded-video-realtime`: AI Vision UI behavior for selected process videos—real-time decode, inference, overlay, playback, tmp→mp4 capture, cache key, cancel/force-reinfer, coexistence with camera live tab.
- `device-local-http-video-ai`: `GET /v1/videos/:video_id/ai` as chunked composited HTTP stream tied to `ProcessVideoAiSession`, headers and formats aligned with `device-local-http-camera-ai`.

### Modified Capabilities

- `device-local-http-api`: Register `GET /v1/videos/:video_id/ai` as a **live AI stream** route (not static MP4 download).
- `ai-frame-sampling-inference`: Document **`AI_VISION_PROCESS_VIDEO`** (200 ms) for recorded-video / HTTP paths (camera live preview stays **`AI_VISION_LIVE`** 500 ms).

## Impact

- **Code:** `AiVisionFragment` (replace batch `analyzeSelectedVideoOffline` UX); new `ProcessVideoAiSession`, `ProcessVideoAiHttpPublisher` (mirror `CameraAiHttpPublisher`); `DeviceLocalHttpServer`; reuse `CameraAiHttpCompositor` / `CameraHttpStreamPublisherCore` / `CompositorFrameProvider` patterns; disk mux with `.mp4.tmp` finalize (existing path under `files/ai-vision-inference-videos/`).
- **Dependencies:** `LensGuardManager`, preview modes, `camera-ai-http-stream` building blocks (compositor + HTTP core); deprecate primary reliance on batch `nativeInferVideoAndSave` for selected-video UX (may remain internal fallback only if design allows).
- **Performance:** One decode + one compositor encoder per active `video_id` session; RKNN guard unchanged; HTTP must not block NanoHTTPD on inference.
- **Breaking (behavior):** AI Vision no longer waits for full offline analysis before showing overlay playback; integrators must not assume `GET …/ai` returns a complete static file on first request.
- **Docs:** `docs/network-api-reference.md`, `docs/camera-http-ai-vision-integration.md` (cross-link recorded-video HTTP).
