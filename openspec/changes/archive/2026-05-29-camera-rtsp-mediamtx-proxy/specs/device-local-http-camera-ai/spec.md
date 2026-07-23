## MODIFIED Requirements

### Requirement: Camera AI SSE inference endpoint

The system SHALL expose **`GET /v1/camera/ai`** on the embedded local HTTP server (`0.0.0.0:8080`). The endpoint SHALL return **`text/event-stream`** per capability **`device-local-http-ai-inference-sse`**. The endpoint SHALL push **`inference`** events for completed live-camera samples (production PR1 infer and/or AI Vision live preview sampling when active). The endpoint SHALL NOT return video elementary stream bytes.

#### Scenario: LAN client receives inference events

- **WHEN** a client sends `GET /v1/camera/ai` while camera network is configured and live inference sampling is active
- **THEN** the response MUST be SSE with at least one `event: inference` after the first completed sample
- **AND** `Content-Type` MUST be `text/event-stream; charset=utf-8`

#### Scenario: Video paired on separate route

- **WHEN** a client needs live camera main-stream imagery with overlays
- **THEN** the client MUST use `rtsp://<device-lan-ip>:8554/camera/pr0` for video and `GET /v1/camera/ai` for overlay data
