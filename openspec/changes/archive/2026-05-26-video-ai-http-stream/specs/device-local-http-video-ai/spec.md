## ADDED Requirements

### Requirement: Process video AI live stream HTTP endpoint

The system SHALL expose **`GET /v1/videos/:video_id/ai`** on the embedded local HTTP server (`0.0.0.0:8080`), where `:video_id` is the business UUID in `ProcessParamsVideo.videoId`. The endpoint SHALL deliver a **chunked live** composited video stream over HTTP, **not** a static file download on first connect. The wire format SHALL match **`GET /v1/camera/ai`** conventions:

- **Default:** Annex-B H.264 (`Content-Type: video/H264`, header **`X-Video-Ai-Format: h264`**).
- **Optional `?format=ts`:** MPEG-TS (`Content-Type: video/mp2t`, **`X-Video-Ai-Format: ts`**).
- **`X-Video-Ai-Mode`:** **`composited`** while AI overlay production is active for the session; **`pass_through`** only before the first composited keyframe if the implementation briefly relays source-encoded units (same hot-switch semantics as camera AI).

The response SHALL NOT use `ApiResult` JSON for a successful stream body.

#### Scenario: Client opens live AI stream for a process video

- **WHEN** a client sends `GET /v1/videos/<videoId>/ai` and the row exists with a readable source `videoPath`, LensGuard can run, and decode starts successfully
- **THEN** the response MUST be HTTP 200 with a chunked body, `Cache-Control: no-cache`, and continuous H.264 or TS bytes from the active **`ProcessVideoAiSession`** without waiting for a completed inference MP4 on disk

#### Scenario: Client requests MPEG-TS

- **WHEN** a client sends `GET /v1/videos/<videoId>/ai?format=ts` while the session is active
- **THEN** the response MUST use `Content-Type: video/mp2t` and `X-Video-Ai-Format: ts`

#### Scenario: Unknown video id

- **WHEN** no database row exists for `video_id`
- **THEN** the endpoint MUST return HTTP 404 with failure semantics consistent with other `/v1/videos/*` routes

#### Scenario: Missing source recording

- **WHEN** the row exists but `videoPath` is null or the source file is missing or zero bytes
- **THEN** the endpoint MUST NOT return HTTP 200 with a video stream body

### Requirement: HTTP subscribers share the real-time processing session

The system SHALL maintain a **`ProcessVideoAiSession`** per active inference cache key for a given `video_id`. All **`GET /v1/videos/:video_id/ai`** connections SHALL subscribe to the **same** composited encoded output as AI Vision UI for that session (single decode, single compositor encoder, fan-out). Starting HTTP while AI Vision already processes the same video MUST join the existing session without starting a second decode.

#### Scenario: HTTP joins in-app session

- **WHEN** AI Vision is playing and inferring on `video_id` `V` and a LAN client opens `GET /v1/videos/V/ai`
- **THEN** the client MUST receive composited bytes from the shared session and MUST NOT open a parallel full-file offline analysis job

#### Scenario: HTTP starts session without UI

- **WHEN** no UI session exists and a client opens `GET /v1/videos/<videoId>/ai` for a valid recording
- **THEN** the system MUST start `ProcessVideoAiSession` for that video and begin streaming composited output as soon as the first composited keyframe is available

### Requirement: HTTP is live-only in v1

`GET /v1/videos/:video_id/ai` MUST NOT serve a completed inference `.mp4` as a static file with HTTP Range when no live session is active. If no session is running, the route MUST start a **new** real-time session from the beginning of the recording (unless blocked by `503`).

#### Scenario: Request after prior run completed

- **WHEN** a finalized inference `.mp4` exists on disk but no `ProcessVideoAiSession` is active and a client sends `GET /v1/videos/<videoId>/ai` without `force=1`
- **THEN** the system MUST start a new live composited stream from the start of the source recording
- **AND** MUST NOT return the on-disk `.mp4` as a complete static download

#### Scenario: No audio on HTTP stream

- **WHEN** a client receives composited bytes from `GET /v1/videos/<videoId>/ai`
- **THEN** the stream MUST be video-only (no audio elementary stream), consistent with `/v1/camera/ai`

### Requirement: Disk capture is parallel and not required for HTTP playback

While the session runs, the system SHALL mux composited output to **`…/ai-vision-inference-<owner>-<cacheKey>.mp4.tmp`**. On successful end-of-stream, the system SHALL **`rename`** the tmp file to **`…mp4`**. HTTP streaming MUST NOT wait for rename to begin. Incomplete **`.mp4`** files MUST NOT be served as static downloads by this route.

#### Scenario: HTTP streams before disk finalize

- **WHEN** a client is connected to `GET /v1/videos/<videoId>/ai` during the first half of the recording
- **THEN** the client MUST receive composited stream bytes while the `.mp4.tmp` file may still be growing

#### Scenario: Tmp finalized after playback ends

- **WHEN** the session reaches end-of-stream and mux finalize succeeds
- **THEN** the `.mp4.tmp` MUST be renamed to `.mp4` and the tmp path MUST NOT remain

### Requirement: Session unavailable responses

When the session cannot start (AI engine not ready, offline infer unavailable, decode failure), the system SHALL return HTTP **503** with short plain-text body and MAY set **`X-Video-Ai-Status: unavailable`**. The system MUST NOT use HTTP 503 solely because inference MP4 is still being written.

#### Scenario: LensGuard unavailable

- **WHEN** preview inference cannot run and decode cannot produce composited output
- **THEN** the response MUST be HTTP 503 and MUST NOT imply a retry-after file poll

### Requirement: Force re-inference query parameter

The system SHALL accept optional **`force=1`**. When present, the system SHALL stop any existing session for that `video_id`, delete **`*.mp4.tmp`** and the inference **`*.mp4`** for the current cache key, and start a new **`ProcessVideoAiSession`**.

#### Scenario: Force restart from HTTP

- **WHEN** `GET /v1/videos/<videoId>/ai?force=1` is requested
- **THEN** any prior inference MP4 for the current cache key MUST be invalidated and a new live session MUST begin

### Requirement: Off-main-thread handler work

Session start, database resolution, and subscriber attach for `GET /v1/videos/:video_id/ai` SHALL NOT run on the Android main thread.

#### Scenario: HTTP request does not block UI thread

- **WHEN** `GET /v1/videos/<videoId>/ai` is invoked
- **THEN** row lookup and session enqueue MUST complete off the main thread
