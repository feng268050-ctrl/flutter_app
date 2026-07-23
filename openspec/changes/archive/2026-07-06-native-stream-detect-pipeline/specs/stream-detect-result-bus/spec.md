## ADDED Requirements

### Requirement: StreamDetectResultBus dispatches native detection events

The App SHALL provide **`StreamDetectResultBus`** (or equivalent facade) as the single Java entry point for C++ `StreamDetectPipeline` uplink events. Native code MUST register one JNI callback that forwards all event types into this bus.

#### Scenario: Single native callback fans out to subscribers

- **WHEN** native publishes a `detect_result` event
- **THEN** `StreamDetectResultBus` MUST dispatch to all registered subscribers on a documented thread
- **AND** MUST NOT require each subscriber to bind a separate JNI native method

#### Scenario: Subscriber registration is decoupled from pipeline start

- **WHEN** a UI component registers a listener before the pipeline starts
- **THEN** it MUST receive subsequent events after the pipeline begins publishing
- **AND** MUST NOT block pipeline startup

### Requirement: Event types match pipeline contract

The bus SHALL support at minimum these event categories with structured payloads:

| Event | Key fields |
|-------|------------|
| `detect_result` | module id, `timestampMs`, `frame_id`, detection JSON / parsed result |
| `pipeline_state` | `running` / `idle` / `error`, optional reconnect reason |
| `session_start` | `sessionId`, `source`, `samplingIntervalMs`, optional dimensions |
| `session_stop` | `sessionId`, `reason` |
| `error` | `code`, `message` |

#### Scenario: Detect result carries timestamp for overlay sync

- **WHEN** `DetectionOverlayView` subscribes to `detect_result`
- **THEN** each event MUST include `timestampMs` and/or `frame_id` for visualization tolerance (100–300 ms)

#### Scenario: Session start before first running

- **WHEN** SSE subscribers exist and the pipeline session starts
- **THEN** subscribers MUST receive `session_start` before the first `detect_result` of that epoch

### Requirement: Subscribers MUST NOT block native detect thread

`StreamDetectResultBus` dispatch MUST NOT perform heavy work on the native callback thread. Subscribers that update UI, write SSE, or run business logic SHALL use documented executors or main-thread handlers.

#### Scenario: Coordinator alarm on background executor

- **WHEN** `OpencvStainDetectCoordinator` receives a heavy-contamination `detect_result`
- **THEN** alarm and Modbus side effects MUST run off the native uplink thread

#### Scenario: SSE publisher serializes on infer fan-out thread

- **WHEN** `CameraAiHttpPublisher` maps `detect_result` to SSE `running`
- **THEN** serialization MUST occur on the existing camera AI publisher executor
- **AND** MUST NOT block the native callback beyond minimal enqueue

### Requirement: Latest-result cache for overlay consumers

The bus or a dedicated holder SHALL maintain the **latest completed** detect result per module (or unified live view) so overlay consumers can render when playback and detect buffers diverge.

#### Scenario: Overlay uses latest result when detect lags playback

- **WHEN** Java playback advances but no new `detect_result` arrives within the configured timeout
- **THEN** overlay MAY show the last completed result or a「检测中」/ hidden state per product rules
- **AND** MUST NOT block or pause RTSP playback

#### Scenario: Result timeout clears stale overlay

- **WHEN** no `detect_result` arrives for longer than the configured stale threshold (e.g. 300 ms–1 s, product-tuned)
- **THEN** overlay MUST hide boxes or show inactive detect state
- **AND** playback MUST continue

### Requirement: Control plane remains outside the bus

Session `start`/`stop`, `setLaserOn`, `setBurstMode`, and module configuration MUST use **command JNI** on `NativeBridge` / `AiManager`, not Pub-Sub topics on `StreamDetectResultBus`.

#### Scenario: Laser state via command not event

- **WHEN** device laser transitions OFF→ON
- **THEN** Java MUST call native `setLaserOn(true)` via the control API
- **AND** MUST NOT rely on subscribers to infer laser state from detect events alone
