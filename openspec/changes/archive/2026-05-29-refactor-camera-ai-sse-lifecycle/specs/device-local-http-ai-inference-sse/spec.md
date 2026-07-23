## MODIFIED Requirements

### Requirement: Inference event payload

The system SHALL emit **`event: running`** (not `inference`) for each completed unified inference sample pushed to subscribers. The `data` line SHALL be a single JSON object containing at minimum:

- **`timestampMs`** (number, required): time associated with the sample — per route clock semantics (see **Requirement: Per-route timestampMs clock**).
- **`sessionId`** (string, optional but SHOULD be present when a session is active): correlates with the current `start` epoch.
- **`success`**, **`code`**, **`level`**, **`status`**, **`message`** (unified result semantics).
- **`imageWidth`**, **`imageHeight`** (numbers).
- **`boxes`**: array of objects with **`x1`**, **`y1`**, **`x2`**, **`y2`**, **`classId`**, **`label`**, **`score`**.
- **`source`**: string identifying infer path (e.g. `preview_det`, `process_video`, `live_infer`).

#### Scenario: Client parses one running event

- **WHEN** the device completes an inference sample and pushes to SSE
- **THEN** subscribers MUST receive `event: running` with JSON `data` containing `timestampMs` and `boxes` when detection succeeded

### Requirement: Heartbeat and error events

While a connection remains open, the publisher SHALL emit **`event: idle`** (not `heartbeat`) at least every **15 seconds** with `data` containing **`timestampMs`** and **`inferenceActive`** (boolean). On non-recoverable failures (e.g. LensGuard cannot run, unknown `video_id`), the publisher SHALL emit **`event: error`** with JSON `data` containing **`code`** and **`message`**, then close the HTTP response.

#### Scenario: Idle connection stays alive

- **WHEN** no `running` event completes for 20 seconds but the subscriber remains connected
- **THEN** the client MUST still receive at least one `idle` event in that interval

#### Scenario: Fatal publisher error

- **WHEN** inference cannot start for a subscribed process video
- **THEN** the client MUST receive `event: error` before the connection ends
- **AND** the connection MUST NOT continue as an infinite empty stream

### Requirement: Single infer fan-out to multiple SSE subscribers

The device SHALL run **at most one** inference sampling pipeline per logical source (live camera vs `ProcessVideoAiSession` cache key) regardless of SSE subscriber count. Each completed sample SHALL be serialized once and written to all active subscriber streams.

#### Scenario: Two LAN clients same video

- **WHEN** two clients connect to `GET /v1/videos/V/ai` for the same active session
- **THEN** both MUST receive the same sequence of `running` events
- **AND** the device MUST NOT run duplicate decode/infer pipelines per client

## ADDED Requirements

### Requirement: Shared AI SSE lifecycle events

All AI inference HTTP endpoints (`GET /v1/camera/ai`, `GET /v1/videos/:video_id/ai`) SHALL use the same SSE event types:

| Event | When |
|-------|------|
| **`idle`** | Immediately on connect; then at least every **15 seconds** while connected |
| **`start`** | When an inference session begins for that route's data source |
| **`running`** | Each completed unified inference sample |
| **`stop`** | When that inference session ends |
| **`error`** | Non-recoverable failure |

The system MUST NOT emit `heartbeat` or `inference` on either route.

#### Scenario: Both routes use lifecycle events

- **WHEN** a client opens `GET /v1/camera/ai` or `GET /v1/videos/<id>/ai`
- **THEN** the SSE stream MUST use only `idle`, `start`, `running`, `stop`, and `error` event names

### Requirement: Immediate idle on SSE connect

When a client opens either `/ai` route, the publisher SHALL emit **`event: idle`** as the first SSE frame on that connection, immediately after HTTP response headers and before any other event for that subscriber.

The `data` JSON MUST include **`timestampMs`** (number, `0` for the first idle on connect) and **`inferenceActive`** (boolean) reflecting whether an inference session is active at connect time for that route's data source.

#### Scenario: First event is idle

- **WHEN** a client opens either `/ai` route
- **THEN** the first SSE event on that connection MUST be `event: idle`

#### Scenario: Idle when session already active

- **WHEN** a client opens either route while inference is already active for that source
- **THEN** the first event MUST be `idle` with `inferenceActive` `true`
- **AND** `start` for the current session MUST follow before the next `running`

### Requirement: Shared start payload

The `data` line for **`event: start`** on both routes SHALL be a JSON object with:

- **`sessionId`** (string, required): UUID unique to this inference epoch.
- **`timestampMs`** (number, required): per-route clock at session start.
- **`source`** (string, required): session source — `production_weld`, `ai_vision_live`, or `process_video`.
- **`samplingIntervalMs`** (number, required): `2000` for production weld; `500` for AI Vision live and process video.
- **`imageWidth`**, **`imageHeight`** (numbers, optional): frame dimensions when known.

#### Scenario: Process video start source

- **WHEN** `ProcessVideoAiSession` begins for a valid recording
- **THEN** `start` `data.source` MUST be `process_video` and `samplingIntervalMs` MUST be `500`

### Requirement: Shared stop payload

The `data` line for **`event: stop`** on both routes SHALL be a JSON object with:

- **`sessionId`** (string, required): MUST match the preceding `start` for that epoch.
- **`timestampMs`** (number, required): per-route clock at session end.
- **`reason`** (string, required): one of `laser_off`, `preview_stopped`, `session_complete`, `session_cancelled`, `force_restart`, `stream_error`, or `release`.

#### Scenario: Video session complete

- **WHEN** `ProcessVideoAiSession` reaches end-of-file
- **THEN** `stop` `data.reason` MUST be `session_complete`

### Requirement: Per-route timestampMs clock

Both routes SHALL use the field name **`timestampMs`** on all lifecycle events. The **meaning** of `timestampMs` SHALL differ by route:

- **`GET /v1/camera/ai`**: milliseconds since **this SSE connection** was established.
- **`GET /v1/videos/:video_id/ai`**: milliseconds on the **source recording media timeline** from 0, aligned with playback position on `GET /v1/videos/:video_id/stream`.

The system MUST NOT emit a separate `streamTimeMs` field on the unified contract.

#### Scenario: Camera running uses connection clock

- **WHEN** a `running` event is emitted on `/v1/camera/ai` 2.1 s after the client connected
- **THEN** `data.timestampMs` MUST be approximately 2100 (connection-relative)

#### Scenario: Video running uses media clock

- **WHEN** a `running` event is emitted on `/v1/videos/V/ai` for a sample taken at media position 5000 ms
- **THEN** `data.timestampMs` MUST be `5000`
