## REMOVED Requirements

### Requirement: Camera AI HTTP endpoint

**Reason**: Endpoint repurposed from encoded video relay to SSE inference events; video uses `GET /v1/camera/live`.

**Migration**: Subscribe to `GET /v1/camera/ai` as `text/event-stream`; play video from `GET /v1/camera/live`; draw overlays client-side from `inference` events.

### Requirement: Pass-through when AI inference is not active

**Reason**: No H.264 pass-through on `/v1/camera/ai`.

**Migration**: Use `/v1/camera/live` for raw camera video when inference SSE is not needed.

### Requirement: Hot switch to composited stream when AI becomes active

**Reason**: Server-side compositing removed.

**Migration**: Client overlays when `inference` events arrive.

### Requirement: Single shared ingest per mode epoch

**Reason**: Replaced by SSE publisher fan-out without RTSP demux on `/ai`.

**Migration**: See `device-local-http-ai-inference-sse`.

### Requirement: Coexistence with existing PR1 consumers

**Reason**: HTTP `/ai` no longer opens PR1 for byte relay.

**Migration**: PR1 consumers unchanged; `/ai` only forwards infer results.

### Requirement: AI stream error responses

**Reason**: Error model is SSE `event: error` (shared spec).

**Migration**: Parse SSE error events.

### Requirement: AI stream cache headers

**Reason**: SSE responses use shared inference stream headers per `device-local-http-ai-inference-sse`.

**Migration**: Follow SSE capability cache and content-type rules.

### Requirement: Overlay parity with AI Vision preview

**Reason**: On-device and LAN clients draw overlays from `inference` JSON; no server compositing.

**Migration**: See `ai-vision-live-inference-overlay`.

### Requirement: Shared LAN HTTP stream infrastructure with live route

**Reason**: `/ai` no longer shares `CameraHttpStreamPublisherCore` with video mux.

**Migration**: Inference SSE uses `AiInferenceSsePublisher`; live video unchanged on `/live`.

### Requirement: Production composited output is subscriber-gated

**Reason**: No production compositor for HTTP.

**Migration**: Production infer may still feed SSE when subscribers connect.

### Requirement: HTTP camera AI encodes pre-composited live frames

**Reason**: AI Vision uses client overlay; HTTP sends JSON only.

**Migration**: See `ai-vision-live-inference-overlay`.

## ADDED Requirements

### Requirement: Camera AI SSE inference endpoint

The system SHALL expose **`GET /v1/camera/ai`** on the embedded local HTTP server (`0.0.0.0:8080`). The endpoint SHALL return **`text/event-stream`** per capability **`device-local-http-ai-inference-sse`**. The endpoint SHALL push **`inference`** events for completed live-camera samples (production PR1 infer and/or AI Vision live preview sampling when active). The endpoint SHALL NOT return video elementary stream bytes.

#### Scenario: LAN client receives inference events

- **WHEN** a client sends `GET /v1/camera/ai` while camera network is configured and live inference sampling is active
- **THEN** the response MUST be SSE with at least one `event: inference` after the first completed sample
- **AND** `Content-Type` MUST be `text/event-stream; charset=utf-8`

#### Scenario: Video paired on separate route

- **WHEN** a client needs live camera imagery with overlays
- **THEN** the client MUST use `GET /v1/camera/live` for video and `GET /v1/camera/ai` for overlay data

### Requirement: Camera AI SSE ties to unified infer without server compositing

When pushing `inference` events, the publisher SHALL use **`LensGuardInferenceResult`** (or equivalent unified mapping) from the active live sampling path. The device SHALL NOT burn boxes or status text into frame bitmaps for this HTTP route.

#### Scenario: Event carries box coordinates

- **WHEN** a live sample completes with detection boxes
- **THEN** the next `inference` SSE event MUST include `boxes` and `imageWidth`/`imageHeight` in JSON `data`
- **AND** the device MUST NOT re-encode H.264 with overlays for HTTP subscribers
