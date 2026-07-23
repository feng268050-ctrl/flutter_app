## Why

`GET /v1/camera/ai` and `GET /v1/videos/:video_id/ai` today only emit `heartbeat` and `inference` events. LAN clients cannot tell whether the device is idle, actively inferring, or between sessions without inferring from gaps in sample traffic. An explicit lifecycle (`idle` → `start` → `running` → `stop`) lets consumers sync overlay UI with the paired video player, and an immediate `idle` on connect gives instant connection health without waiting for the first heartbeat.

## What Changes

- **BREAKING** (both `/ai` SSE routes): Replace event types:
  - `heartbeat` → **`idle`** (connection keepalive + state snapshot)
  - `inference` → **`running`** (same detection JSON payload, renamed event)
  - Add **`start`** when an inference session begins
  - Add **`stop`** when that session ends
- **`idle` on connect**: Every new SSE subscriber on either route MUST receive `idle` immediately after HTTP 200, before any other event.
- **Unified contract**: Both routes use the same event names and JSON field shapes for `idle`, `start`, `running`, and `stop`. The **only** intentional differences are:
  1. **Data source** — live camera (production PR1 / AI Vision live) vs `ProcessVideoAiSession` for a recorded `video_id`
  2. **`timestampMs` clock** — camera: ms since **this SSE connection**; process video: ms on **source media timeline** (from 0, aligned with `/stream` playback)
- **`start` / `stop` payloads**: Structured JSON with `sessionId`, `timestampMs`, `source`, and session metadata (see design).
- Update `docs/network-api-reference.md` and unit tests for both routes.

## Capabilities

### New Capabilities

_(none — lifecycle semantics extend existing AI SSE capabilities)_

### Modified Capabilities

- `device-local-http-ai-inference-sse`: Shared lifecycle events (`idle`/`start`/`running`/`stop`), immediate `idle` on connect, unified payloads, per-route `timestampMs` semantics.
- `device-local-http-camera-ai`: Live-camera data source and session hooks (production laser, AI Vision live).
- `device-local-http-video-ai`: Process-video data source and `ProcessVideoAiSession` session hooks.
- `device-local-http-api`: Document updated SSE event table for both `/ai` routes.
- `production-ai-inference-stream-lifecycle`: Emit `start`/`stop` to camera AI SSE when production PR1 infer stream starts/stops.
- `ai-vision-recorded-video-realtime`: LAN SSE references `running` instead of `inference`.

## Impact

- **Java**: `AiInferenceSseHub`, `AiInferenceSseJson`, `CameraAiHttpPublisher`, `ProcessVideoAiSession`, `ProductionInferenceStreamClient`, `AiVisionFragment`, `DeviceLocalHttpServer`.
- **Tests**: `AiInferenceSseJsonTest`, `CameraAiLiveSseTimelineTest`, `AiInferenceSseHubFlushTest`, `DeviceLocalHttpCameraAiRouteTest`, process-video AI HTTP tests.
- **Docs**: `docs/network-api-reference.md` § camera AI SSE and § process video AI SSE.
- **Clients**: Any LAN consumer of either `/ai` route must handle new event names and lifecycle (breaking).
