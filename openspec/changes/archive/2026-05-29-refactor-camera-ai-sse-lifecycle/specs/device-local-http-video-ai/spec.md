## MODIFIED Requirements

### Requirement: Process video AI SSE inference endpoint

The system SHALL expose **`GET /v1/videos/:video_id/ai`** where `:video_id` is the business UUID in `ProcessParamsVideo.videoId`. On success the endpoint SHALL return **`text/event-stream`** per **`device-local-http-ai-inference-sse`**. The endpoint SHALL use shared lifecycle SSE events **`idle`**, **`start`**, **`running`**, and **`stop`** (not `heartbeat` or `inference`). On this route, **`timestampMs`** on all events SHALL be the **source media timeline position** in milliseconds from 0, aligned with `GET /v1/videos/:video_id/stream` playback. The endpoint SHALL NOT return composited H.264, MPEG-TS, or static MP4 as the response body.

#### Scenario: Client opens SSE for valid recording

- **WHEN** a client sends `GET /v1/videos/<videoId>/ai` and the row exists with a readable `videoPath` and `ProcessVideoAiSession` starts
- **THEN** the response MUST be HTTP 200 SSE
- **THEN** the first SSE event MUST be `event: idle`
- **AND** `running` events MUST include `timestampMs` matching the session media position when each sample was taken

#### Scenario: Unknown video id

- **WHEN** no database row exists for `video_id`
- **THEN** the endpoint MUST return HTTP 404 or emit `event: error` before close per shared SSE error semantics

### Requirement: HTTP SSE shares ProcessVideoAiSession with AI Vision

All **`GET /v1/videos/:video_id/ai`** connections SHALL attach to the same **`ProcessVideoAiSession`** (per cache key) as AI Vision **Detect** for that video. Starting HTTP while UI already processes the same `video_id` MUST join the existing session without a second full-file offline analysis job.

#### Scenario: HTTP joins in-app detect session

- **WHEN** AI Vision is detecting on `video_id` `V` and a LAN client opens `GET /v1/videos/V/ai`
- **THEN** the client MUST receive the same `running` events as the session produces for UI overlay
- **AND** the device MUST NOT start a parallel composited encode pipeline

#### Scenario: HTTP starts session without UI

- **WHEN** no UI session exists and a client opens `GET /v1/videos/<videoId>/ai` for a valid recording
- **THEN** the system MUST start `ProcessVideoAiSession`, emit `start`, and emit `running` events as samples complete

### Requirement: Optional force restart query

The system MAY accept **`force=1`** query parameter to cancel and restart the session for that `video_id`. The system SHALL NOT accept **`format`** query parameters on this route.

#### Scenario: Force re-infer

- **WHEN** a client requests `GET /v1/videos/V/ai?force=1` while a session exists
- **THEN** the system MUST emit `stop` with `reason` `force_restart` for the prior session
- **AND** MUST begin a fresh lifecycle sequence (`idle` on new subscriber connect, then `start`, `running`, …)

## ADDED Requirements

### Requirement: Process video session lifecycle SSE hooks

`ProcessVideoAiSession` SHALL emit camera-shared lifecycle events to its SSE hub:

- **`start`** when session processing begins successfully (`source` `process_video`, `samplingIntervalMs` `500`).
- **`stop`** with `reason` `session_complete` on end-of-file, `session_cancelled` on user cancel, `force_restart` on `?force=1`, or `stream_error` / `release` on failure/shutdown.

#### Scenario: Session complete stop

- **WHEN** playback clock reaches end-of-file and the session finishes
- **THEN** all subscribers MUST receive `event: stop` with `reason` `session_complete` before the connection closes or returns to idle
