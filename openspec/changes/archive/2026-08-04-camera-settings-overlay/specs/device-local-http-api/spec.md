## MODIFIED Requirements

### Requirement: Camera LAN control routes

The local HTTP server SHALL expose camera LAN control routes as follows:

- `POST /v1/camera/record` with JSON `{ "switch": "on"|"off" }` → `ApiResult` with `data.switch`; invalid → `invalid_switch`; conflict → `recording_in_progress`.
- `POST /v1/camera/show-overlay` with `{ enable: 0|1, positionx?, positiony? }` → `ApiResult` on success. The server MUST invoke the App camera OSD apply path (`camera-osd-overlay`) when that path is registered. On success, `data` MUST include at least `enable`, `positionx`, `positiony`, and SHOULD include `machineModel` (and `nameoverlayy` when enable=1). When the apply path is not registered, the server MUST return structured failure (for example `show_overlay_unavailable`) rather than an indefinite hang or blank 501. Invalid enable/coordinates → `invalid_show_overlay_request` (HTTP 400). Apply / camera failures → structured `ApiResult` failure with an appropriate non-2xx status (not a hang).
- `GET /v1/camera/ai` SHALL return Server-Sent Events per capability **`device-local-http-ai-inference-sse`** when the App AI daemon is ready; otherwise HTTP `503` plain text `camera_ai_unavailable` or `camera_unavailable`. On success the route MUST NOT return video elementary-stream bytes and MUST NOT wrap frames in `ApiResult`.

Live preview remains `rtsp://<lan-ip>:8554/camera/pr0` (not `GET /v1/camera/live`).

#### Scenario: Record switch on LAN

- **WHEN** a client posts `{ "switch": "on" }` to `/v1/camera/record` and recording can start
- **THEN** the response MUST be `ApiResult` success with `data.switch` equal to `on`

#### Scenario: Show-overlay success when apply path is wired

- **WHEN** the App OSD apply path is registered
- **AND** a client posts `{ "enable": 1, "positionx": 10, "positiony": 10 }` to `/v1/camera/show-overlay`
- **AND** the camera accepts the OSD writes
- **THEN** the response MUST be `ApiResult` success
- **AND** `data.enable` MUST be `1`

#### Scenario: Show-overlay unavailable when unwired

- **WHEN** the App OSD apply path is not registered
- **AND** a client posts to `/v1/camera/show-overlay`
- **THEN** the response MUST be a structured failure naming unavailability (for example `show_overlay_unavailable`)
- **AND** MUST NOT hang indefinitely

#### Scenario: Camera AI unavailable

- **WHEN** camera AI is not available
- **AND** a client calls `GET /v1/camera/ai`
- **THEN** the status MUST be 503 and the body MUST be plain text naming unavailability

#### Scenario: Camera AI SSE when available

- **WHEN** the AI daemon is ready
- **AND** a client calls `GET /v1/camera/ai`
- **THEN** the status MUST be 200
- **AND** `Content-Type` MUST be `text/event-stream; charset=utf-8`
- **AND** the first SSE event MUST be `idle`
