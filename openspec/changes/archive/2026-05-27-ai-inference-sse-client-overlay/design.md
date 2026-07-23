## Context

The tablet runs LensGuard inference (RKNN) on sampled frames but cannot reliably **re-encode** video with burned-in overlays for LAN HTTP or in-app preview. Current architecture:

- **`GET /v1/camera/ai`**: PR1 pass-through or composited H.264/TS (`CameraAiHttpPublisher` + `CameraAiHttpCompositor`).
- **`GET /v1/videos/:video_id/ai`**: composited H.264/TS from `ProcessVideoAiSession`.
- **AI Vision**: bitmap compositing via `ProcessVideoAiFrameRenderer` and composited preview players.

Mobile/LAN consumers are **not shipped**; breaking the wire format is acceptable.

## Goals / Non-Goals

**Goals:**

- Replace both `/ai` routes with **SSE** (`text/event-stream`) pushing **timestamped** `LensGuardInferenceResult`-shaped JSON events.
- Keep inference on-device (RKNN + `inferFromI420` / live sampling); **only** move **display/relay** of boxes to clients.
- **AI Vision**: video on existing player; overlay via **`TextureView`** (or `DetectionOverlayView` above player) synchronized by playback clock / `timestampMs`.
- Pairing documented: **`/camera/live` + `/camera/ai`**, **`/videos/:id/stream` + `/videos/:id/ai`**.
- Shared fan-out: one infer pipeline per source, many SSE subscribers.

**Non-Goals:**

- Backward compatibility with H.264/TS AI URLs, `?format=`, `X-Camera-Ai-Mode`.
- Client reference apps (only device contract + in-app AI Vision).
- Re-architecting cloud `POST …/ai-report` in this change (may follow with JSON timeline instead of composited MP4).
- Subtitle file export (WebVTT); SSE only.

## Decisions

### 1. SSE as the only `/ai` response body

**Choice:** `Content-Type: text/event-stream; charset=utf-8`, `Cache-Control: no-cache`, `Connection: keep-alive` (or `close` per NanoHTTPD behavior).

**Rationale:** Standard browser/EventSource parsing; text JSON avoids binary mux overhead on device.

**Alternatives rejected:** WebSocket (extra route + auth), chunked NDJSON without SSE framing (worse tooling).

### 2. Event envelope and timestamps

**Choice:** One primary event type:

```
event: inference
data: {"timestampMs":<long>,"streamTimeMs":<long|null>,...LensGuardInferenceResult fields...}
```

- **`timestampMs`**: wall-clock or monotonic ms when the sample was taken (required on every event).
- **`streamTimeMs`**: for process video, position in source media timeline (ms); for live camera, optional elapsed ms since first sample or `null` if clients align by wall clock only.
- Payload fields mirror unified result: `success`, `code`, `level`, `status`, `message`, `imageWidth`, `imageHeight`, `boxes[]` (`x1,y1,x2,y2,classId,label,score`), `source`.
- **`event: heartbeat`** every ~15s with `data: {}` while connection open.
- **`event: error`** then close on fatal errors (LensGuard unavailable, video not found).

**Rationale:** Clients schedule overlay like subtitles: match `streamTimeMs` to `ExoPlayer.getCurrentPosition()` or live player clock.

### 3. Video transport stays on existing routes

**Choice:** No video bytes on `/ai`. Clients MUST use:

| Inference SSE | Video bytes |
|---------------|-------------|
| `GET /v1/camera/ai` | `GET /v1/camera/live` |
| `GET /v1/videos/:id/ai` | `GET /v1/videos/:id/stream` |

### 4. Server implementation shape

**Choice:** New `AiInferenceSsePublisher` core:

- Accepts `Consumer<LensGuardInferenceResult>` (or timeline frame) from existing samplers.
- Serializes to SSE, fans out to `OutputStream` per HTTP subscriber.
- `CameraAiSsePublisher` subscribes to live infer path (`AI_VISION_LIVE` / production PR1 sampling when active).
- `ProcessVideoAiSsePublisher` subscribes to `ProcessVideoAiSession` timeline append callbacks.

**Remove:** `CameraAiHttpCompositor`, H.264 fan-out in `ProcessVideoAiSession.acquireHttpSubscriber`, `CameraHttpStreamFormat` usage on `/ai` routes.

### 5. AI Vision overlay model

**Choice:**

- **Live tab:** Keep RTSP → `TextureView` player. Add overlay `TextureView` (or restore `DetectionOverlayView`) updated on main thread from `LensGuardHoldForwardStore<LensGuardInferenceResult>`; map box coordinates using `imageWidth`/`imageHeight` vs view size.
- **Recorded tab:** ExoPlayer on source file; overlay view uses `ProcessVideoAiTimeline.findFrameAt(playbackPositionMs)`; no composited encode for preview.
- Stop calling `ProcessVideoAiFrameRenderer` / bitmap burn-in for on-screen preview.

**Rationale:** GPU-friendly draw paths; matches user request.

### 6. Process video session without compositor encoder

**Choice:** `ProcessVideoAiSession` retains decode clock + async `inferFromI420` + timeline for SSE and in-app overlay. **Drop** composited H.264 mux, `.mp4.tmp` inference artifact, and `ProcessVideoAiCompositedPreview` for v1 of this change unless a follow-up defines JSON-only upload.

**Rationale:** Compositing was the performance bottleneck; upload pipeline adjustment is explicit non-goal but tasks will stub/disable composited MP4 upload gates.

### 7. Production mode and HTTP

**Choice:** `ProductionInferenceStreamClient` continues PR1 infer for alerts/engine; **never** starts compositor for HTTP. SSE subscribers on `/v1/camera/ai` receive production samples when laser/infer active.

## Risks / Trade-offs

- **[Clock skew]** Live clients may mis-align overlay if only `timestampMs` is used → document `streamTimeMs` for recorded video; live may use hold-forward “latest” without strict sync.
- **[SSE backpressure]** Slow clients buffer events → drop intermediate events per subscriber (keep latest inference) or disconnect after high-water mark.
- **[Upload regression]** Removing inference MP4 breaks `AiVisionInferenceVideoUploadRunner` until metadata-only upload is specified → disable or gate upload button in same change.
- **[Multiple subscribers]** Fan-out must not multiply RKNN calls → single infer, many SSE writes (already unified in-flight policy).

## Migration Plan

1. Land SSE publishers + route handlers; delete compositor classes and tests expecting `video/H264` on `/ai`.
2. Refactor AI Vision to overlay views; remove composited preview player.
3. Update `docs/network-api-reference.md` with SSE examples (`curl -N`, EventSource).
4. No dual-stack period (user: no compatibility).

## Open Questions

- Should process-video SSE emit **hold-forward repeats** on a timer (so clients need not interpolate) or only on new samples? **Proposal:** emit on each completed sample only; clients hold-forward locally (matches unified spec).
- Final upload artifact without composited MP4: JSON timeline file vs source-only report — resolve in follow-up change if needed.
