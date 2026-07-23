## REMOVED Requirements

### Requirement: Process video AI live stream HTTP endpoint

**Reason**: Replaced by SSE inference timeline for `GET /v1/videos/:video_id/ai`.

**Migration**: Use `GET /v1/videos/:id/stream` for MP4 bytes and `/ai` for SSE; client draws overlays by `streamTimeMs`.

### Requirement: HTTP subscribers share the real-time processing session

**Reason**: Session sharing retained but delivers SSE not H.264 fan-out.

**Migration**: Same session reference-count; subscribe to event stream instead of `EncodedStreamSubscriber`.

### Requirement: HTTP is live-only in v1

**Reason**: SSE is live-only by nature; no composited file poll.

**Migration**: N/A.

### Requirement: Disk capture is parallel and not required for HTTP playback

**Reason**: Composited MP4 artifact removed from HTTP path; timeline JSON persisted for replay.

**Migration**: Upload follow-up; LAN clients use SSE + source stream.

### Requirement: Session unavailable responses

**Reason**: Unavailable semantics move to SSE `event: error` and HTTP status before stream start.

**Migration**: See `device-local-http-ai-inference-sse`.

## ADDED Requirements

### Requirement: Process video AI SSE inference endpoint

The system SHALL expose **`GET /v1/videos/:video_id/ai`** where `:video_id` is the business UUID in `ProcessParamsVideo.videoId`. On success the endpoint SHALL return **`text/event-stream`** per **`device-local-http-ai-inference-sse`**. Each **`inference`** event SHALL include **`streamTimeMs`** set to the source media timeline position (milliseconds) of the sample. The endpoint SHALL NOT return composited H.264, MPEG-TS, or static MP4 as the response body.

#### Scenario: Client opens SSE for valid recording

- **WHEN** a client sends `GET /v1/videos/<videoId>/ai` and the row exists with a readable `videoPath` and `ProcessVideoAiSession` starts
- **THEN** the response MUST be HTTP 200 SSE
- **AND** `inference` events MUST include `streamTimeMs` matching the session clock position when each sample was taken

#### Scenario: Unknown video id

- **WHEN** no database row exists for `video_id`
- **THEN** the endpoint MUST return HTTP 404 or emit `event: error` before close per shared SSE error semantics

### Requirement: HTTP SSE shares ProcessVideoAiSession with AI Vision

All **`GET /v1/videos/:video_id/ai`** connections SHALL attach to the same **`ProcessVideoAiSession`** (per cache key) as AI Vision **Detect** for that video. Starting HTTP while UI already processes the same `video_id` MUST join the existing session without a second full-file offline analysis job.

#### Scenario: HTTP joins in-app detect session

- **WHEN** AI Vision is detecting on `video_id` `V` and a LAN client opens `GET /v1/videos/V/ai`
- **THEN** the client MUST receive the same `inference` events as the session produces for UI overlay
- **AND** the device MUST NOT start a parallel composited encode pipeline

#### Scenario: HTTP starts session without UI

- **WHEN** no UI session exists and a client opens `GET /v1/videos/<videoId>/ai` for a valid recording
- **THEN** the system MUST start `ProcessVideoAiSession` and emit `inference` events as samples complete

### Requirement: Optional force restart query

The system MAY accept **`force=1`** query parameter to cancel and restart the session for that `video_id`. The system SHALL NOT accept **`format`** query parameters on this route.

#### Scenario: Force re-infer

- **WHEN** a client requests `GET /v1/videos/V/ai?force=1` while a session exists
- **THEN** the system MUST restart processing for `V` and begin a fresh SSE event sequence
