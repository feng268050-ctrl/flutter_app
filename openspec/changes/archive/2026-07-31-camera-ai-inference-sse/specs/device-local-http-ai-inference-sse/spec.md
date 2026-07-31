## ADDED Requirements

### Requirement: Shared SSE media type and connection headers

`GET /v1/camera/ai` SHALL respond with **`Content-Type: text/event-stream; charset=utf-8`** on success. The response SHALL include **`Cache-Control: no-cache`**. The response body SHALL use Server-Sent Events framing (`event:` / `data:` lines, blank line between events). Successful responses MUST NOT wrap payloads in `ApiResult`.

#### Scenario: Successful SSE connection

- **WHEN** a client opens `GET /v1/camera/ai` and the publisher starts successfully
- **THEN** the HTTP status MUST be 200
- **AND** `Content-Type` MUST be `text/event-stream; charset=utf-8`
- **AND** the body MUST deliver valid SSE frames

### Requirement: Shared AI SSE lifecycle events

`GET /v1/camera/ai` SHALL use only these SSE event names:

| Event | When |
|-------|------|
| **`idle`** | Immediately on connect; then at least every **15 seconds** while connected |
| **`start`** | When an inference session begins for the live camera source |
| **`running`** | Each completed unified inference sample (lens_det) |
| **`stop`** | When that inference session ends |
| **`error`** | Non-recoverable failure (then close the HTTP response) |

The system MUST NOT emit `heartbeat` or `inference` on this route.

#### Scenario: Event vocabulary

- **WHEN** a client opens `GET /v1/camera/ai`
- **THEN** the SSE stream MUST use only `idle`, `start`, `running`, `stop`, and `error` event names

### Requirement: Immediate idle on SSE connect

When a client opens `GET /v1/camera/ai`, the publisher SHALL emit **`event: idle`** as the first SSE frame on that connection, immediately after HTTP response headers. The `data` JSON MUST include **`timestampMs`** (number; `0` for the first idle on connect) and **`inferenceActive`** (boolean) reflecting whether an inference session is active at connect time.

#### Scenario: First event is idle

- **WHEN** a client opens `GET /v1/camera/ai`
- **THEN** the first SSE event on that connection MUST be `event: idle`

#### Scenario: Idle when session already active

- **WHEN** a client opens the route while inference is already active
- **THEN** the first event MUST be `idle` with `inferenceActive` `true`
- **AND** `start` for the current session MUST follow before the next `running`

### Requirement: Inference running payload

The system SHALL emit **`event: running`** for each completed live lens_det sample pushed to subscribers. The `data` line SHALL be a single JSON object containing at minimum:

- **`timestampMs`** (number, required): milliseconds since **this SSE connection** was established
- **`sessionId`** (string, optional but SHOULD be present when a session is active)
- **`success`**, **`code`**, **`level`**, **`status`**, **`message`**
- **`imageWidth`**, **`imageHeight`** (numbers)
- **`boxes`**: array of objects with **`x1`**, **`y1`**, **`x2`**, **`y2`**, **`classId`**, **`label`**, **`score`** (pixel coordinates)
- **`source`**: typically **`live_stain_detect`** (or `ai_vision_live` when that holder is active)

#### Scenario: Client parses one running event

- **WHEN** the device completes a live lens_det sample and pushes to SSE
- **THEN** subscribers MUST receive `event: running` with JSON `data` containing `timestampMs` and `boxes` (possibly empty)

### Requirement: Shared start and stop payloads

`event: start` `data` SHALL include **`sessionId`**, **`timestampMs`**, **`source`**, **`samplingIntervalMs`** (500 for live weld), and optional **`imageWidth`** / **`imageHeight`**.

`event: stop` `data` SHALL include **`sessionId`**, **`timestampMs`**, and **`reason`** one of `laser_off`, `preview_stopped`, `session_complete`, `session_cancelled`, `force_restart`, `stream_error`, or `release`.

#### Scenario: Live weld start source

- **WHEN** StreamDetect session starts for weld with SSE subscribers
- **THEN** `start` `data.source` MUST be `live_stain_detect`
- **AND** `samplingIntervalMs` MUST be `500`

#### Scenario: Laser off stop reason

- **WHEN** weld StreamDetect stops because laser turned OFF
- **THEN** `stop` `data.reason` MUST be `laser_off`

### Requirement: Idle heartbeat cadence

While a connection remains open, the publisher SHALL emit **`event: idle`** at least every **15 seconds** with `data` containing **`timestampMs`** and **`inferenceActive`**. On non-recoverable failures, the publisher SHALL emit **`event: error`** with JSON `data` containing **`code`** and **`message`**, then close the HTTP response.

#### Scenario: Idle connection stays alive

- **WHEN** no `running` event completes for 20 seconds but the subscriber remains connected
- **THEN** the client MUST still receive at least one `idle` event in that interval

### Requirement: Video bytes are not on the AI SSE route

`GET /v1/camera/ai` SHALL NOT include H.264, MPEG-TS, or MP4 bytes. Clients needing live camera video SHALL use MediaMTX **`rtsp://<device-lan-ip>:8554/camera/pr0`**.

#### Scenario: Client expects video on ai route

- **WHEN** a client requests `GET /v1/camera/ai`
- **THEN** the response MUST NOT use `Content-Type: video/H264` or `video/mp2t`

### Requirement: Single infer fan-out to multiple SSE subscribers

The device SHALL run at most one live StreamDetect pipeline for the weld camera source regardless of SSE subscriber count. Each completed sample SHALL be serialized once and written to all active `/v1/camera/ai` subscriber streams.

#### Scenario: Two LAN clients

- **WHEN** two clients connect to `GET /v1/camera/ai` while laser is ON and detect is running
- **THEN** both MUST receive the same sequence of `running` events
- **AND** the device MUST NOT run duplicate native decode/infer pipelines per client
