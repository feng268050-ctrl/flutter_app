## MODIFIED Requirements

### Requirement: Camera LAN control routes

- `POST /v1/camera/record` with JSON `{ "switch": "on"|"off" }` → `ApiResult` with `data.switch`; invalid → `invalid_switch`; conflict → `recording_in_progress`.
- `POST /v1/camera/show-overlay` with `{ enable: 0|1, positionx?, positiony? }` → `ApiResult` on success. When the Linux IPC overlay write path is unavailable, the server MUST return structured failure (for example `show_overlay_unavailable`) rather than an indefinite hang or blank 501.
- `GET /v1/camera/ai` SHALL return Server-Sent Events per capability **`device-local-http-ai-inference-sse`** when the App AI daemon is ready; otherwise HTTP `503` plain text `camera_ai_unavailable` or `camera_unavailable`. On success the route MUST NOT return video elementary-stream bytes and MUST NOT wrap frames in `ApiResult`.

Live preview remains `rtsp://<lan-ip>:8554/camera/pr0` (not `GET /v1/camera/live`).

#### Scenario: Record switch on LAN

- **WHEN** a client posts `{ "switch": "on" }` to `/v1/camera/record` and recording can start
- **THEN** the response MUST be `ApiResult` success with `data.switch` equal to `on`

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
