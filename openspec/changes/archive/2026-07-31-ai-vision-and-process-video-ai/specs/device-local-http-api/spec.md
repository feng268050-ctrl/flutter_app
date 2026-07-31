## MODIFIED Requirements

### Requirement: Process-video AI LAN routes

- `GET /v1/videos/:videoId/ai` SHALL return Server-Sent Events per capability **`process-video-ai-sse`** when the App AI daemon is ready and the video exists; otherwise HTTP `503` plain text `process_video_ai_unavailable` (or `404` `video_not_found` when missing).
- `GET /v1/videos/:videoId/ai/replay` SHALL return `ApiResult` per **`process-video-ai-sse`** when a timeline is available; otherwise structured `ai_replay_not_found`.

#### Scenario: Process video AI unavailable

- **WHEN** process-video AI is not available (daemon not ready)
- **AND** a client calls `GET /v1/videos/{id}/ai` for an existing video
- **THEN** the status MUST be 503 and the body MUST be plain text `process_video_ai_unavailable`

#### Scenario: Process video AI SSE when available

- **WHEN** the AI daemon is ready
- **AND** a client calls `GET /v1/videos/{id}/ai` for an existing video with a readable file
- **THEN** the status MUST be 200
- **AND** `Content-Type` MUST be `text/event-stream; charset=utf-8`
