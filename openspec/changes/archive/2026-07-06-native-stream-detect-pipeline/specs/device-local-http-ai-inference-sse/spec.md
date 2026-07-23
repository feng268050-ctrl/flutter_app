## MODIFIED Requirements

### Requirement: Shared start payload

The `data` line for **`event: start`** on both routes SHALL be a JSON object with:

- **`sessionId`** (string, required): UUID unique to this inference epoch.
- **`timestampMs`** (number, required): per-route clock at session start.
- **`source`** (string, required): session source — **`live_stain_detect`**, **`offline_stain_detect`**, or **`ai_vision_live`**
- **`samplingIntervalMs`** (number, required): **`500`** for live weld and AI Vision live native pipeline; **`200`** for process video
- **`imageWidth`**, **`imageHeight`** (numbers, optional): frame dimensions when known.

#### Scenario: Process video start source and interval

- **WHEN** `ProcessVideoAiSession` begins for a valid recording
- **THEN** `start` `data.source` MUST be `offline_stain_detect`
- **AND** `samplingIntervalMs` MUST be `200`

#### Scenario: Live weld start source

- **WHEN** `StreamDetectPipeline` session starts with SSE subscribers on `/v1/camera/ai`
- **THEN** `start` `data.source` MUST be `live_stain_detect`
- **AND** `samplingIntervalMs` MUST be `500`

#### Scenario: AI Vision live start source

- **WHEN** AI Vision live native detect session starts with SSE subscribers
- **THEN** `start` `data.source` MUST be `ai_vision_live`
- **AND** `samplingIntervalMs` MUST be `500`

## ADDED Requirements

### Requirement: Camera AI SSE consumes StreamDetectResultBus

`CameraAiHttpPublisher` for **`GET /v1/camera/ai`** SHALL subscribe to **`StreamDetectResultBus`** for live camera inference. SSE `start`, `running`, `stop`, and fatal `error` events MUST be derived from native pipeline session and `detect_result` events. The publisher MUST NOT depend on `LivePr1InferenceStreamClient` decode callbacks or Java I420 sampling to emit `running`.

#### Scenario: Running event from detect_result

- **WHEN** native pipeline completes a live stain detect sample and subscribers are connected
- **THEN** `CameraAiHttpPublisher` MUST emit `event: running` with unified JSON mapped from the bus payload
- **AND** MUST fan out to all active `/v1/camera/ai` subscribers without duplicate native infer runs

#### Scenario: Stream error emits SSE error

- **WHEN** native pipeline publishes `error` or non-recoverable `pipeline_state`
- **THEN** connected `/v1/camera/ai` clients MUST receive `event: error` when the publisher policy requires it
- **AND** Java playback on a separate session MUST continue

### Requirement: Single infer fan-out applies to native live pipeline

The device SHALL run **at most one** native live detect pipeline per logical live camera source regardless of SSE subscriber count. Each completed sample from `StreamDetectPipeline` SHALL be serialized once and written to all active `/v1/camera/ai` subscriber streams.

#### Scenario: Two LAN clients same live camera

- **WHEN** two clients connect to `GET /v1/camera/ai` while laser is ON
- **THEN** both MUST receive the same sequence of `running` events
- **AND** the device MUST NOT run duplicate native decode/infer pipelines per client
