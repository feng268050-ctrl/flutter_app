## ADDED Requirements

### Requirement: Process video AI live stream HTTP endpoint (API surface)

The system SHALL expose **`GET /v1/videos/:video_id/ai`** on the same embedded local HTTP server and port as other `/v1/*` device routes. This endpoint SHALL provide a **chunked live composited stream** tied to **`ProcessVideoAiSession`**, not a static MP4 file response on first request.

Semantics (shared session with AI Vision, H.264/TS formats, tmp→mp4 capture, `force=1`, error codes) are defined in capability **`device-local-http-video-ai`**.

#### Scenario: AI live stream route on device LAN

- **WHEN** a client requests `http://<device-lan-ip>:8080/v1/videos/<video_id>/ai`
- **THEN** the request MUST be handled by the local HTTP server component that serves `/v1/videos` and MUST NOT require the cloud Worker base URL

#### Scenario: Distinct from raw stream and camera AI

- **WHEN** a client compares `/v1/videos/<id>/stream`, `/v1/videos/<id>/ai`, and `/v1/camera/ai`
- **THEN** `/stream` MUST serve the raw `videoPath` file, `/v1/camera/ai` MUST serve live camera PR1, and `/v1/videos/<id>/ai` MUST serve live composited output from the selected recording session
