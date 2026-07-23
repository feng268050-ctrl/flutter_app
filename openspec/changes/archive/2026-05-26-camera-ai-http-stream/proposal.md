## Why

LAN clients can already view the camera **main stream** via **`GET /v1/camera/live`** (PR0 pass-through), but remote dashboards and tools cannot see what operators see in **AI Vision**: the sub-stream feed with **AI inference overlays** (detection boxes, status texture) after native recompositing. They need a single HTTP URL on the device LAN that mirrors that experience without opening another full RTSP decode path or duplicating the AI Vision UI pipeline. When AI is not running, the endpoint must still be useful by serving **raw PR1** with minimal overhead, and **switch to the composited stream as soon as AI becomes active** without requiring clients to reconnect to a different URL.

## What Changes

- Add **`GET /v1/camera/ai`** on `DeviceLocalHttpServer` (`0.0.0.0:8080`), modeled after **`GET /v1/camera/live`** (chunked HTTP, default Annex-B H.264, optional `?format=ts`, `X-Camera-Ai-Format`, `Cache-Control: no-cache`, 503 on failure).
- **Source profile:** sub-stream **`/PR1`** (`CameraConfig.LIVE_INFERENCE_RTSP_URL`) as the baseline bitstream when AI overlay is unavailable.
- **AI-active mode:** when `LensGuardManager` / AI Vision preview inference is running and producing composited frames, fan out **encoded** output (texture + overlay) to HTTP subscribers; **no second PR1 RTSP session** when sharing with an existing inference or preview ingest is feasible.
- **Hot switch:** subscribers on `/v1/camera/ai` SHALL receive PR1 pass-through until the first composited access unit is ready, then continue on the **same connection** with a documented stream boundary (e.g. new IDR / format header) — clients must not need a different path.
- Introduce **`CameraAiHttpPublisher`** with reference counting, bounded queues, subscriber cap, and pass-through-first design; **extract shared HTTP stream infrastructure** with `CameraLiveHttpPublisher` (subscriber fan-out, TS mux, RTSP pass-through bootstrap) without merging the two HTTP routes.
- **Reuse AI Vision overlay semantics** via shared **`CameraAiOverlayState`** (box parsing / labels) and optional **`CompositorFrameProvider`** registration from `AiVisionFragment`, so HTTP composited video matches on-device preview without duplicating Fragment-only logic.
- **Phased PR1 encoded-frame sharing** with AI Vision preview and `ProductionInferenceStreamClient` to avoid duplicate RTSP when LAN `/ai` and in-app paths run together.
- Document the route in `docs/network-api-reference.md`.
- **Non-goals:** PR0 main stream on this route; cloud/TLS/auth; WebSocket; forcing AI Vision Fragment to be visible; re-encoding PR0 to 720p; replacing production weld inference lifecycle rules.

## Capabilities

### New Capabilities

- `device-local-http-camera-ai`: Embedded route `GET /v1/camera/ai`, dual-mode publisher (PR1 pass-through vs AI-composited encoded relay), hot switch semantics, formats (H.264 default, optional TS), error responses, coexistence with `ProductionInferenceStreamClient` / AI Vision preview, and performance constraints (single ingest per mode epoch, no redundant decode for pass-through).

### Modified Capabilities

- `device-local-http-api`: Extend LAN HTTP surface requirements to include `GET /v1/camera/ai` alongside `GET /v1/camera/live`.

## Impact

- **Code**: `DeviceLocalHttpServer` (new route); refactors/extractions: `CameraHttpStreamPublisherCore`, `CameraAiOverlayState`, `CompositorFrameProvider`, optional `LiveH264Encoder`; `CameraAiHttpPublisher` + `CameraAiHttpCompositor`; AI Vision / production client hooks for `EncodedVideoSink` fan-out (milestone); `CameraLiveHttpPublisher` adopts shared core (behavior unchanged).
- **Dependencies**: Reuse EasyDarwin `EasyPlayerClient`, existing `EncodedVideoSink`; may require a narrow bridge from AI preview compositor (today TextureView + `DetectionOverlayView`) to encoded access units — scoped in design.
- **Performance**: Pass-through path adds at most **one** PR1 RTSP session dedicated to HTTP AI when no other PR1 consumer exists; AI-active path must not start a parallel PR1 decode if `ProductionInferenceStreamClient` or AI Vision player already holds the sub-stream; compositor encode runs only while HTTP subscribers exist and AI is active.
- **Network**: `http://<device-wifi-ip>:8080/v1/camera/ai`; camera remains on eth0; same LAN trust model as `/v1/camera/live`.
- **Docs**: `docs/network-api-reference.md`, cross-link to `docs/dual-stream-workflow.md` and AI Vision integration notes.
