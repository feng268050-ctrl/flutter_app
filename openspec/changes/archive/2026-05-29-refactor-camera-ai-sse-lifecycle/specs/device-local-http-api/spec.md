## MODIFIED Requirements

### Requirement: Camera AI stream HTTP endpoint

The system SHALL expose **`GET /v1/camera/ai`** on the same embedded local HTTP server and port as other `/v1/*` device routes. This endpoint SHALL return **`text/event-stream`** (SSE) of shared lifecycle and inference JSON events without `ApiResult` wrapping. SSE events SHALL be **`idle`**, **`start`**, **`running`**, **`stop`**, and **`error`**. It SHALL NOT stream H.264 or MPEG-TS video bytes.

Semantics are defined in **`device-local-http-ai-inference-sse`** (shared wire format and payloads) and **`device-local-http-camera-ai`** (live-camera data source and connection-relative `timestampMs`). Camera main-stream video SHALL be consumed from the MediaMTX RTSP relay at **`rtsp://<device-lan-ip>:8554/camera/pr0`** (see **`mediamtx-runtime-lifecycle`**).

#### Scenario: AI route on device LAN

- **WHEN** a client requests `http://<device-lan-ip>:8080/v1/camera/ai`
- **THEN** the request MUST be handled by the local HTTP server component that serves `/v1/videos` and MUST NOT require the cloud Worker base URL
- **AND** `Content-Type` MUST be `text/event-stream; charset=utf-8`
- **AND** the first SSE event on the connection MUST be `idle`

#### Scenario: Video is on RTSP relay not ai route

- **WHEN** a client needs camera main-stream (PR0) video bytes
- **THEN** the client MUST use `rtsp://<device-lan-ip>:8554/camera/pr0`, not `/v1/camera/ai`

### Requirement: Process video AI live stream HTTP endpoint (API surface)

The system SHALL expose **`GET /v1/videos/:video_id/ai`** on the same embedded local HTTP server and port as other `/v1/*` device routes. This endpoint SHALL provide an **SSE inference event stream** tied to **`ProcessVideoAiSession`**, not a chunked composited video body. SSE events SHALL be **`idle`**, **`start`**, **`running`**, **`stop`**, and **`error`** — the same names and JSON shapes as `/v1/camera/ai`.

Semantics are defined in **`device-local-http-ai-inference-sse`** and **`device-local-http-video-ai`** (process-video data source and media-timeline `timestampMs`).

#### Scenario: AI live stream route on device LAN

- **WHEN** a client requests `http://<device-lan-ip>:8080/v1/videos/<video_id>/ai`
- **THEN** the request MUST be handled by the local HTTP server component that serves `/v1/videos` and MUST NOT require the cloud Worker base URL
- **AND** the successful body MUST be SSE, not MP4/H.264
- **AND** the first SSE event on the connection MUST be `idle`

#### Scenario: Distinct from raw stream and camera AI

- **WHEN** a client compares `/v1/videos/<id>/stream`, `/v1/videos/<id>/ai`, and `/v1/camera/ai`
- **THEN** `/stream` MUST serve the raw `videoPath` file bytes
- **AND** both `/v1/camera/ai` and `/v1/videos/<id>/ai` MUST use the same SSE event names and JSON field shapes
- **AND** `/v1/camera/ai` MUST use live-camera inference with connection-relative `timestampMs`
- **AND** `/v1/videos/<id>/ai` MUST serve process-video inference SSE with media-timeline `timestampMs`
