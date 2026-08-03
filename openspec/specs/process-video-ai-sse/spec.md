## ADDED Requirements

### Requirement: Process-video AI SSE when daemon ready

When the AI daemon is ready and a process video exists with a readable source file, `GET /v1/videos/:videoId/ai` SHALL return HTTP 200 with `Content-Type: text/event-stream; charset=utf-8`, acquire an HTTP holder on a per-video `ProcessVideoAiSession`, and start the session if not already running. Events SHALL include `idle`, `start`, `running`, `stop`, and `error` using the shared AI inference SSE JSON shapes. `running.timestampMs` and stop timestamps MUST be media-relative (source timeline ms), not connection-relative.

#### Scenario: Phone detect opens SSE

- **WHEN** the daemon is ready and a client GETs `/v1/videos/{id}/ai` for an existing video
- **THEN** the response MUST be 200 with `text/event-stream`
- **AND** the first event MUST be `idle`
- **AND** subsequent `running` events MUST use media `timestampMs` on the sample grid

#### Scenario: Daemon not ready

- **WHEN** the AI daemon is not ready
- **AND** a client GETs `/v1/videos/{id}/ai`
- **THEN** the status MUST be 503 with plain text `process_video_ai_unavailable`

### Requirement: Media-timeline sampling drives offline JPG infer

Process-video sessions SHALL sample at 500 ms intervals (first sample at 500 ms; 0 ms never sampled), extract a JPEG via the product **GStreamer frame-extract** path (rootfs GStreamer; not App-bundled ffmpeg), and invoke daemon `offline_infer_opencv_stain_jpg`. Results SHALL append to an in-memory timeline and fan out on the session SSE hub.

#### Scenario: Sample on grid

- **WHEN** the playback clock reaches a new sample bucket
- **THEN** the session MUST extract one frame via GStreamer frame-extract and request offline JPG infer
- **AND** publish a `running` event with that sample's media timestamp

### Requirement: AI replay endpoint

`GET /v1/videos/:videoId/ai/replay` SHALL return `ApiResult` success with `{ version, videoId, generatedAtMs, frames }` when a persisted (or in-memory completed) timeline exists; otherwise `ai_replay_not_found` / 404. Each frame MUST match the SSE `running` data shape.

#### Scenario: Replay hit

- **WHEN** a timeline file exists for the video cache key
- **AND** a client GETs `/v1/videos/{id}/ai/replay`
- **THEN** the response MUST be ApiResult success with a non-empty `frames` array when samples were persisted
