## MODIFIED Requirements

### Requirement: Camera AI stream HTTP endpoint

The system SHALL expose **`GET /v1/camera/ai`** on the same embedded local HTTP server and port as other `/v1/*` device routes. This endpoint SHALL return **`text/event-stream`** (SSE) of timestamped inference JSON events without `ApiResult` wrapping. It SHALL NOT stream H.264 or MPEG-TS video bytes.

Semantics (event types, timestamps, fan-out, pairing with camera main-stream video) are defined in capabilities **`device-local-http-ai-inference-sse`** and **`device-local-http-camera-ai`**. Camera main-stream video SHALL be consumed from the MediaMTX RTSP relay at **`rtsp://<device-lan-ip>:8554/camera/pr0`** (see **`mediamtx-runtime-lifecycle`**), not from an HTTP live route.

#### Scenario: AI route on device LAN

- **WHEN** a client requests `http://<device-lan-ip>:8080/v1/camera/ai`
- **THEN** the request MUST be handled by the local HTTP server component that serves `/v1/videos` and MUST NOT require the cloud Worker base URL
- **AND** `Content-Type` MUST be `text/event-stream; charset=utf-8`

#### Scenario: Video is on RTSP relay not ai route

- **WHEN** a client needs camera main-stream (PR0) video bytes
- **THEN** the client MUST use `rtsp://<device-lan-ip>:8554/camera/pr0`, not `/v1/camera/ai`
