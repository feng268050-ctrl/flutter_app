# stream-detect-result-bus Specification

## Purpose
TBD - created by archiving change native-stream-detect-pipeline. Update Purpose after archive.
## Requirements
### Requirement: StreamDetectResultBus dispatches native detection events

The App SHALL provide **`StreamDetectResultBus`** (or equivalent facade) as the single Java entry point for C++ `StreamDetectPipeline` uplink events. Ingress MUST be a single fan-in: either the transitional JNI callback **or** the daemon `evt.sock` subscriber adapter (P1+), which forwards all event types into this bus. Product code MUST NOT require each subscriber to bind a separate native method.

#### Scenario: Single native uplink fans out to subscribers

- **WHEN** native publishes a `detect_result` event via the active uplink
- **THEN** `StreamDetectResultBus` MUST dispatch to all registered subscribers on a documented thread
- **AND** MUST NOT require each subscriber to bind a separate JNI native method

#### Scenario: Subscriber registration is decoupled from pipeline start

- **WHEN** a UI component registers a listener before the pipeline starts
- **THEN** it MUST receive subsequent events after the pipeline begins publishing
- **AND** MUST NOT block pipeline startup

#### Scenario: Evt adapter feeds the same bus

- **WHEN** P1 is active and Supervisor reads a `detect_result` JSON Line from `evt.sock`
- **THEN** it MUST enqueue an equivalent bus dispatch
- **AND** existing coordinators MUST continue to subscribe via the bus API

### Requirement: Event types match pipeline contract

The bus SHALL support at minimum these event categories with structured payloads:

| Event | Key fields |
|-------|------------|
| `detect_result` | module id, `timestampMs`, `frame_id`, detection JSON / parsed result |
| `combined_frame` | `frame_pts_ms`, `modules` map of module id → detection JSON |
| `pipeline_state` | `running` / `idle` / `error`, optional reconnect reason |
| `session_start` | `sessionId`, `source`, `samplingIntervalMs`, optional dimensions |
| `session_stop` | `sessionId`, `reason` |
| `error` | `code`, `message` |

Per-module `detect_result` events from separate native JNI calls are deprecated; new implementations MUST prefer `combined_frame` as the primary live sample uplink.

#### Scenario: Detect result carries timestamp for overlay sync

- **WHEN** `DetectionOverlayView` subscribes to `detect_result`
- **THEN** each event MUST include `timestampMs` and/or `frame_id` for visualization tolerance (100–300 ms)

#### Scenario: Session start before first running

- **WHEN** SSE subscribers exist and the pipeline session starts
- **THEN** subscribers MUST receive `session_start` before the first `detect_result` of that epoch

#### Scenario: Combined frame provides per-module timestamps

- **WHEN** a `combined_frame` event is received
- **THEN** each module entry dispatched to subscribers MUST include `timestampMs` derived from `frame_pts_ms` or module JSON
- **AND** overlay sync tolerance rules MUST apply identically to per-module dispatch

### Requirement: Subscribers MUST NOT block native detect thread

`StreamDetectResultBus` dispatch MUST NOT perform heavy work on the native uplink thread (JNI callback thread **or** daemon evt reader thread that is considered the uplink). Subscribers that update UI, write SSE, or run business logic SHALL use documented executors or main-thread handlers. Daemon evt backpressure rules also require Java not to block the socket read loop with heavy work.

#### Scenario: Coordinator alarm on background executor

- **WHEN** `OpencvStainDetectCoordinator` receives a heavy-contamination `detect_result`
- **THEN** alarm and Modbus side effects MUST run off the uplink thread

#### Scenario: SSE publisher serializes on infer fan-out thread

- **WHEN** `CameraAiHttpPublisher` maps `detect_result` to SSE `running`
- **THEN** serialization MUST occur on the existing camera AI publisher executor
- **AND** MUST NOT block the uplink beyond minimal enqueue

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

Session `start`/`stop`, laser Bit0 gate, `setBurstMode`, and module configuration MUST use the **command plane** (`cmd.sock` after daemon cutover; transitional command JNI on `NativeBridge` / `AiManager` until then), not Pub-Sub topics on `StreamDetectResultBus`.

#### Scenario: Laser state via command not event

- **WHEN** device laser Bit0 transitions OFF→ON
- **THEN** Java MUST send laser-on via the control API (`laser_state` / transitional `setLaserOn(true)`)
- **AND** MUST NOT rely on subscribers to infer laser state from detect events alone

#### Scenario: Daemon cmds are not bus messages

- **WHEN** Java starts a StreamDetect session after P1 cutover
- **THEN** it MUST use `stream_detect_start` on `cmd.sock`
- **AND** MUST NOT publish that start as a substitute for Supervisor cmd handling on the result bus

### Requirement: StreamDetectResultBus SHALL parse combined frame JSON

`StreamDetectResultBus` MUST accept combined frame events from native containing `frame_pts_ms` and a `modules` object. It MUST parse each module entry and dispatch to existing per-module subscribers without requiring separate native JNI invocations per module.

#### Scenario: Combined event fans out to per-module listeners

- **WHEN** native publishes one combined JSON with `modules.lens_det` and `modules.zero_point`
- **THEN** `StreamDetectResultBus` MUST invoke lens_det subscribers with the lens_det payload
- **AND** MUST invoke zero_point subscribers with the zero_point payload
- **AND** MUST perform dispatch off the native callback thread per existing executor rules

#### Scenario: Coordinator API unchanged after combined callback

- **WHEN** `OpencvStainDetectCoordinator` subscribes via existing registration API
- **THEN** it MUST receive stain results with the same parsed fields as before per-module callbacks
- **AND** MUST NOT require caller changes

