## Purpose

Define **`GET /v1/camera/ai`** on the embedded LAN HTTP server: bridge the industrial camera **RTSP sub-stream (`/PR1`)** to HTTP clients with **pass-through** when AI is inactive and **composited** overlay relay when AI inference is active, including hot switch on the same connection.
## Requirements
### Requirement: Camera AI SSE inference endpoint

The system SHALL expose **`GET /v1/camera/ai`** on the embedded local HTTP server (`0.0.0.0:5580`; port **8080** deprecated). The endpoint SHALL return **`text/event-stream`** per capability **`device-local-http-ai-inference-sse`**. The endpoint SHALL use shared lifecycle SSE events **`idle`**, **`start`**, **`running`**, and **`stop`**. The endpoint SHALL push **`running`** events for each completed live-camera sample (production PR1 infer and/or AI Vision live preview sampling when active). On this route, **`timestampMs`** on all events SHALL be **connection-relative** (milliseconds since this SSE connection was established). The endpoint SHALL NOT return video elementary stream bytes.

#### Scenario: LAN client receives running events

- **WHEN** a client sends `GET /v1/camera/ai` while camera network is configured and live inference sampling is active
- **THEN** the response MUST be SSE with at least one `event: running` after the first completed sample
- **AND** `Content-Type` MUST be `text/event-stream; charset=utf-8`

#### Scenario: Video paired on separate route

- **WHEN** a client needs live camera main-stream imagery with overlays
- **THEN** the client MUST use `rtsp://<device-lan-ip>:8554/camera/pr0` for video and `GET /v1/camera/ai` for overlay data

### Requirement: Camera AI SSE ties to unified infer without server compositing

When pushing **`running`** events, the publisher SHALL use **`LensGuardInferenceResult`** (or equivalent unified mapping) from the active live sampling path. The device SHALL NOT burn boxes or status text into frame bitmaps for this HTTP route.

#### Scenario: Event carries box coordinates

- **WHEN** a live sample completes with detection boxes
- **THEN** the next `running` SSE event MUST include `boxes` and `imageWidth`/`imageHeight` in JSON `data`
- **AND** the device MUST NOT re-encode H.264 with overlays for HTTP subscribers

### Requirement: Camera inference session start sources

On **`GET /v1/camera/ai`**, **`event: start`** SHALL be emitted when a live-camera inference session begins. The `start` `data.source` MUST be one of:

- **`production_weld`** — `ProductionInferenceStreamClient` starts (laser ON in Quick/Engineer Mode).
- **`ai_vision_live`** — AI Vision live preview inference becomes active.

At most one active camera SSE session at a time; if production weld is active, it takes precedence over AI Vision live.

#### Scenario: Production start before first running

- **WHEN** laser turns ON, production infer stream starts, and at least one `/v1/camera/ai` subscriber is connected
- **THEN** subscribers MUST receive `event: start` with `source` `production_weld` before the first `running` of that session

#### Scenario: Laser off emits stop

- **WHEN** laser turns OFF while subscribers are connected
- **THEN** subscribers MUST receive `event: stop` with `reason` `laser_off`

