## ADDED Requirements

### Requirement: Shared SSE media type and connection headers

All AI inference HTTP endpoints (`GET /v1/camera/ai`, `GET /v1/videos/:video_id/ai`) SHALL respond with **`Content-Type: text/event-stream; charset=utf-8`** on success. The response SHALL include **`Cache-Control: no-cache`**. The response body SHALL use [Server-Sent Events](https://html.spec.whatwg.org/multipage/server-sent-events.html) framing (`event:` / `data:` lines, blank line between events).

#### Scenario: Successful SSE connection

- **WHEN** a client opens either `/ai` route and the publisher starts successfully
- **THEN** the HTTP status MUST be 200
- **AND** `Content-Type` MUST be `text/event-stream; charset=utf-8`
- **AND** the body MUST deliver valid SSE frames

### Requirement: Inference event payload

The system SHALL emit **`event: inference`** for each completed unified inference sample pushed to subscribers. The `data` line SHALL be a single JSON object containing at minimum:

- **`timestampMs`** (number, required): time associated with the sample.
- **`streamTimeMs`** (number or `null`): media timeline position for recorded video; MAY be `null` for live camera when not tied to a file clock.
- **`success`**, **`code`**, **`level`**, **`status`**, **`message`** (unified result semantics).
- **`imageWidth`**, **`imageHeight`** (numbers).
- **`boxes`**: array of objects with **`x1`**, **`y1`**, **`x2`**, **`y2`**, **`classId`**, **`label`**, **`score`**.
- **`source`**: string identifying infer path (e.g. `preview_det`, `process_video`).

#### Scenario: Client parses one inference event

- **WHEN** the device completes an inference sample and pushes to SSE
- **THEN** subscribers MUST receive `event: inference` with JSON `data` containing `timestampMs` and `boxes` when detection succeeded

### Requirement: Heartbeat and error events

While a connection remains open, the publisher SHALL emit **`event: heartbeat`** at least every **15 seconds** with `data: {}` or `data: {"ok":true}`. On non-recoverable failures (e.g. LensGuard cannot run, unknown `video_id`), the publisher SHALL emit **`event: error`** with JSON `data` containing **`code`** and **`message`**, then close the HTTP response.

#### Scenario: Idle connection stays alive

- **WHEN** no inference completes for 20 seconds but the subscriber remains connected
- **THEN** the client MUST still receive at least one heartbeat event in that interval

#### Scenario: Fatal publisher error

- **WHEN** inference cannot start for a subscribed process video
- **THEN** the client MUST receive `event: error` before the connection ends
- **AND** the connection MUST NOT continue as an infinite empty stream

### Requirement: Single infer fan-out to multiple SSE subscribers

The device SHALL run **at most one** inference sampling pipeline per logical source (live camera vs `ProcessVideoAiSession` cache key) regardless of SSE subscriber count. Each completed sample SHALL be serialized once and written to all active subscriber streams.

#### Scenario: Two LAN clients same video

- **WHEN** two clients connect to `GET /v1/videos/V/ai` for the same active session
- **THEN** both MUST receive the same sequence of `inference` events
- **AND** the device MUST NOT run duplicate decode/infer pipelines per client

### Requirement: Video bytes are not on SSE routes

SSE `/ai` endpoints SHALL NOT include H.264, MPEG-TS, or MP4 bytes in the response body. Clients needing video SHALL use **`GET /v1/camera/live`** or **`GET /v1/videos/:video_id/stream`** separately.

#### Scenario: Client expects video on ai route

- **WHEN** a client requests `GET /v1/camera/ai`
- **THEN** the response MUST NOT use `Content-Type: video/H264` or `video/mp2t`
