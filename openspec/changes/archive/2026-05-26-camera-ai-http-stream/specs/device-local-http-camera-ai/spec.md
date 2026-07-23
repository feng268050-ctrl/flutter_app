## ADDED Requirements

### Requirement: Camera AI HTTP endpoint

The system SHALL expose **`GET /v1/camera/ai`** on the embedded local HTTP server (`0.0.0.0:8080`). The endpoint SHALL target the industrial camera **RTSP sub-stream** at `CameraConfig.LIVE_INFERENCE_RTSP_URL` (path **`/PR1`**, TCP transport consistent with existing `EasyPlayerClient` usage). The response SHALL be HTTP **200** with a chunked body suitable for LAN video players.

- **Default:** **`Content-Type: video/H264`** with **Annex-B H.264** elementary stream bytes.
- **Optional `?format=ts`:** **`Content-Type: video/mp2t`** with **MPEG-TS** muxed from the same encoded access units.
- **Optional `?format=h264`:** same as default.
- The response SHALL include **`X-Camera-Ai-Format`** with value **`h264`** or **`ts`** matching the active mux mode.
- The response SHOULD include **`X-Camera-Ai-Mode`** with value **`pass_through`** or **`composited`** reflecting the active relay source.

#### Scenario: Client opens default AI stream while AI is inactive

- **WHEN** a client sends `GET /v1/camera/ai` (no `format` query) while the camera network is configured, RTSP to `LIVE_INFERENCE_RTSP_URL` is reachable, and AI compositing is not active
- **THEN** the response status MUST be 200, `Content-Type` MUST be `video/H264`, `X-Camera-Ai-Format` MUST be `h264`, `X-Camera-Ai-Mode` MUST be `pass_through`, and the body MUST deliver continuous Annex-B H.264 access units from PR1 without on-device re-encode

#### Scenario: Client requests MPEG-TS

- **WHEN** a client sends `GET /v1/camera/ai?format=ts` while RTSP is reachable
- **THEN** the response status MUST be 200, `Content-Type` MUST be `video/mp2t`, `X-Camera-Ai-Format` MUST be `ts`, and the body MUST deliver continuously muxed transport-stream bytes while the connection remains open

#### Scenario: Wrong method

- **WHEN** a client sends a method other than `GET` to `/v1/camera/ai`
- **THEN** the server MUST NOT return a successful live stream body

### Requirement: Pass-through when AI inference is not active

When AI inference overlay production is not active, the system SHALL relay **encoded PR1 access units** directly to HTTP subscribers using the same pass-through technique as `GET /v1/camera/live` (demux → HTTP, no decode solely for HTTP). The system SHALL NOT run a compositor encoder in this state.

AI inference overlay production SHALL be considered **inactive** when `LensGuardManager` is not running, or when running but none of the following hold: AI Vision preview classification enabled, AI Vision preview detection enabled, production sub-stream inference streaming (`ProductionInferenceStreamClient`), or AI Vision tab live preview player streaming.

#### Scenario: LensGuard stopped

- **WHEN** `LensGuardManager.isRunning()` is false and a client connects to `GET /v1/camera/ai`
- **THEN** the stream MUST remain `pass_through` from PR1 for the duration of the connection unless AI becomes active during the connection

#### Scenario: No redundant decode in pass-through

- **WHEN** the publisher is in `pass_through` mode
- **THEN** the implementation MUST NOT decode video to YUV/RGB solely to serve HTTP clients

### Requirement: Hot switch to composited stream when AI becomes active

When AI inference overlay production becomes active while one or more `GET /v1/camera/ai` connections are open, the system SHALL begin producing a **composited** encoded video stream (camera imagery plus inference overlay texture and detection graphics consistent with AI Vision preview). The system SHALL switch HTTP subscribers to the composited source on the **same connection** without requiring a different URL. The switch SHALL occur as soon as the first composited **keyframe** is available. Until that keyframe, subscribers SHALL continue receiving PR1 pass-through bytes.

#### Scenario: AI starts during an open HTTP connection

- **WHEN** a client is connected to `GET /v1/camera/ai` in `pass_through` mode and AI inference overlay production becomes active
- **THEN** the server MUST continue the HTTP response on the same connection, MUST eventually set `X-Camera-Ai-Mode` to `composited`, and MUST deliver composited H.264 access units after the first composited keyframe

#### Scenario: AI stops during an open HTTP connection

- **WHEN** AI inference overlay production becomes inactive while clients remain connected
- **THEN** the server MUST revert to PR1 `pass_through` relay on the same connections after teardown of the compositor encoder

### Requirement: Single shared ingest per mode epoch

The system SHALL maintain **at most one** dedicated PR1 RTSP ingest for HTTP AI pass-through while any `GET /v1/camera/ai` connection is open and the publisher is in `pass_through` mode. Multiple simultaneous HTTP viewers requesting the **same** format SHALL share that ingest via in-process fan-out. The system SHALL NOT open a separate RTSP session per HTTP client.

While in `composited` mode, the system SHALL maintain **at most one** compositor encoder feeding all HTTP AI subscribers. The compositor encoder SHALL run only while at least one HTTP AI subscriber is connected **and** AI inference overlay production is active.

#### Scenario: Two concurrent viewers same format in pass-through

- **WHEN** two clients connect to `GET /v1/camera/ai` at the same time in `pass_through` with the same effective format
- **THEN** the device MUST use one shared PR1 ingest and MUST fan out encoded data to both connections

#### Scenario: Compositor stops with subscribers

- **WHEN** the last HTTP AI subscriber disconnects
- **THEN** the compositor encoder MUST stop and the dedicated PR1 pass-through ingest MUST stop within a reasonable teardown window

### Requirement: Coexistence with existing PR1 consumers

When `ProductionInferenceStreamClient` or AI Vision preview already holds a PR1 RTSP session, the system SHOULD share encoded frames from that client when technically feasible. If sharing is not implemented, HTTP AI MAY use a separate PR1 session and MUST log a diagnosable warning (`duplicate_rtsp=pr1_inference_active` or `duplicate_rtsp=ai_vision_preview`) when both run concurrently.

#### Scenario: Production inference and HTTP AI concurrent

- **WHEN** production sub-stream inference is streaming and a client requests `GET /v1/camera/ai`
- **THEN** the system MUST either serve pass-through from a shared encoded-frame tap OR log `duplicate_rtsp=pr1_inference_active`

### Requirement: AI stream error responses

When the camera network is not ready, RTSP cannot be established within a bounded start timeout, or the publisher fails, the system SHALL respond with HTTP **503** and a short plain-text body. When the maximum number of concurrent AI stream subscribers is exceeded, the system SHALL respond with HTTP **503**.

#### Scenario: Camera unreachable

- **WHEN** `GET /v1/camera/ai` is requested and RTSP to `LIVE_INFERENCE_RTSP_URL` cannot be established in pass-through mode
- **THEN** the response status MUST be 503 and the connection MUST close without pretending to stream video

#### Scenario: Subscriber limit

- **WHEN** active AI HTTP subscribers already equal the configured maximum and another client connects
- **THEN** the new request MUST receive HTTP 503

### Requirement: AI stream cache headers

Successful AI stream responses SHALL include **`Cache-Control: no-cache`**. The endpoint SHALL NOT wrap the stream body in `ApiResult` JSON.

#### Scenario: Headers on success

- **WHEN** AI streaming starts successfully
- **THEN** the response MUST include `Cache-Control: no-cache` and MUST NOT use the `ApiResult` envelope for the stream body

### Requirement: Overlay parity with AI Vision preview

When the publisher is in `composited` mode, detection boxes and status overlay semantics SHALL be derived from the same normalized overlay state (`CameraAiOverlayState` or successor) used by AI Vision preview (`DetectionOverlayView` / status overlay). The system SHALL NOT maintain a second independent box-parsing implementation for HTTP compositing.

#### Scenario: Preview det updates both UI and HTTP

- **WHEN** a `preview_det` check result arrives while AI Vision preview detection is enabled and an HTTP `/v1/camera/ai` client is in `composited` mode
- **THEN** the composited stream MUST reflect the same box geometry and labels as the on-device overlay snapshot for that result generation

### Requirement: Shared LAN HTTP stream infrastructure with live route

`CameraAiHttpPublisher` SHALL reuse the same pass-through subscriber, queue, MPEG-TS mux, and RTSP bootstrap abstractions as `CameraLiveHttpPublisher` via a shared core component (`CameraHttpStreamPublisherCore` or equivalent). This requirement SHALL NOT merge `GET /v1/camera/live` and `GET /v1/camera/ai` into a single route.

#### Scenario: Live route unchanged after core extraction

- **WHEN** `CameraLiveHttpPublisher` is refactored to use the shared core
- **THEN** `GET /v1/camera/live` MUST continue to source `RECORDING_RTSP_URL` (PR0) with the same response headers and pass-through semantics as before the refactor
