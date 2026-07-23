## MODIFIED Requirements

### Requirement: Camera AI stream HTTP endpoint

The system SHALL expose **`GET /v1/camera/ai`** on the same embedded local HTTP server and port as other `/v1/*` device routes. This endpoint SHALL return **`text/event-stream`** (SSE) of timestamped inference JSON events without `ApiResult` wrapping. It SHALL NOT stream H.264 or MPEG-TS video bytes.

Semantics (event types, timestamps, fan-out, pairing with `GET /v1/camera/live`) are defined in capabilities **`device-local-http-ai-inference-sse`** and **`device-local-http-camera-ai`**.

#### Scenario: AI route on device LAN

- **WHEN** a client requests `http://<device-lan-ip>:8080/v1/camera/ai`
- **THEN** the request MUST be handled by the local HTTP server component that serves `/v1/videos` and MUST NOT require the cloud Worker base URL
- **AND** `Content-Type` MUST be `text/event-stream; charset=utf-8`

#### Scenario: Video is on live route not ai route

- **WHEN** a client needs camera video bytes
- **THEN** the client MUST use `GET /v1/camera/live`, not `/v1/camera/ai`

### Requirement: Process video AI live stream HTTP endpoint (API surface)

The system SHALL expose **`GET /v1/videos/:video_id/ai`** on the same embedded local HTTP server and port as other `/v1/*` device routes. This endpoint SHALL provide an **SSE inference event stream** tied to **`ProcessVideoAiSession`**, not a chunked composited video body.

Semantics (shared session, `streamTimeMs`, `force=1`, errors) are defined in capabilities **`device-local-http-ai-inference-sse`** and **`device-local-http-video-ai`**.

#### Scenario: AI live stream route on device LAN

- **WHEN** a client requests `http://<device-lan-ip>:8080/v1/videos/<video_id>/ai`
- **THEN** the request MUST be handled by the local HTTP server component that serves `/v1/videos` and MUST NOT require the cloud Worker base URL
- **AND** the successful body MUST be SSE, not MP4/H.264

#### Scenario: Distinct from raw stream and camera AI

- **WHEN** a client compares `/v1/videos/<id>/stream`, `/v1/videos/<id>/ai`, and `/v1/camera/ai`
- **THEN** `/stream` MUST serve the raw `videoPath` file bytes
- **AND** `/v1/camera/ai` MUST serve live-camera inference SSE
- **AND** `/v1/videos/<id>/ai` MUST serve process-video inference SSE for that recording
