## MODIFIED Requirements

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

### Requirement: Subscribers MUST NOT block native detect thread

`StreamDetectResultBus` dispatch MUST NOT perform heavy work on the native uplink thread (JNI callback thread **or** daemon evt reader thread that is considered the uplink). Subscribers that update UI, write SSE, or run business logic SHALL use documented executors or main-thread handlers. Daemon evt backpressure rules also require Java not to block the socket read loop with heavy work.

#### Scenario: Coordinator alarm on background executor

- **WHEN** `OpencvStainDetectCoordinator` receives a heavy-contamination `detect_result`
- **THEN** alarm and Modbus side effects MUST run off the uplink thread

#### Scenario: SSE publisher serializes on infer fan-out thread

- **WHEN** `CameraAiHttpPublisher` maps `detect_result` to SSE `running`
- **THEN** serialization MUST occur on the existing camera AI publisher executor
- **AND** MUST NOT block the uplink beyond minimal enqueue
