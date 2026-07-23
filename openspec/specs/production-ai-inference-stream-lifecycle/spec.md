# production-ai-inference-stream-lifecycle Specification

## Purpose

Quick/Engineer weld modes: native **`StreamDetectPipeline`** follows laser ON/OFF and OpenCV stain-detect session availability; PR0 recording is independent.
## Requirements
### Requirement: Production-mode inference stream follows laser state

In Quick Mode and Engineer Mode, the system SHALL start the native **`StreamDetectPipeline`** when the device laser Bit0 is ON and the OpenCV stain-detect / AI assist session gates are active, and SHALL stop sampling or stop the session when Bit0 is OFF or the session is unavailable, per existing product rules. Control MUST go through the Java control plane that targets the AI native process—**daemon `cmd.sock` after P1 cutover**, with transitional JNI allowed only until that cutover. This lifecycle SHALL NOT depend on whether process video recording is active. The App MUST NOT start **`LivePr1InferenceStreamClient`** for detection decode after the prior native-pipeline migration is fully applied.

#### Scenario: Laser on without recording

- **WHEN** the user enables laser in Quick Mode or Engineer Mode and video recording is not started
- **THEN** the app SHALL start `StreamDetectPipeline` consuming the sub-stream URL (`CameraConfig.LIVE_INFERENCE_RTSP_URL`, MediaMTX relay `/camera/pr1`)
- **AND** detect sampling SHALL occur inside the native pipeline at `LIVE_WELD` (500 ms) in normal mode
- **AND** laser gate MUST reflect the actual Bit0 laser state from device status

#### Scenario: Laser off stops inference stream

- **WHEN** the user disables laser while the native detect pipeline is active
- **THEN** `StreamDetectPipeline` SHALL stop or cease scheduling detect samples
- **AND** native burst and sampling state MUST reset
- **AND** recording MAY continue if the user had started it independently

#### Scenario: Recording without laser does not drive weld stain detect

- **WHEN** the user starts process video recording with laser OFF
- **THEN** the main stream for mux/file output MUST be consumed from the MediaMTX relay reader URL
- **AND** the app SHALL NOT start the detect pipeline solely because recording started

#### Scenario: P1 uses daemon commands not live JNI start

- **WHEN** P1 live cutover is complete
- **THEN** production laser-gated start/stop MUST use daemon stream detect cmds / Supervisor
- **AND** MUST NOT call in-process `nativeStartStreamDetect` for that path

### Requirement: Live PR1 frames are decimated before OpenCV stain detect

When `StreamDetectPipeline` decodes PR1 frames, the native pipeline SHALL apply **`AiFrameSamplingInterval.LIVE_WELD` (500 ms)** in normal mode before invoking OpenCV stain detect in-process. Decode MAY continue at full frame rate; only gated samples SHALL invoke stain detect. Java MUST NOT decimate I420 frames for live weld stain detect.

#### Scenario: Laser on with sub-stream at video frame rate

- **WHEN** laser is ON and the native pipeline decodes at typical video frame rate in normal mode
- **THEN** at most one OpenCV stain detect MUST start per 500 ms

#### Scenario: Laser off stops push regardless of sampling

- **WHEN** laser turns OFF and the detect pipeline stops or idles
- **THEN** OpenCV stain detect from the live PR1 path SHALL cease
- **AND** native live-weld sampling state SHALL reset

### Requirement: Recording and inference streams are independent clients

The system SHALL use separate RTSP reader instances for main-stream recording (PR0) and sub-stream native detection (PR1) so that starting or stopping one does not implicitly start or stop the other. Native detection MUST NOT share the recording player's decode session.

#### Scenario: Laser on and recording on concurrently

- **WHEN** laser is ON and the user starts video recording
- **THEN** main stream recording and native sub-stream detection SHALL both be active on independent sessions
- **AND** stopping recording SHALL NOT stop native sub-stream detection while laser remains ON

### Requirement: Inference stream lifecycle observability

Diagnostics logs SHALL distinguish **`StreamDetectPipeline`** lifecycle from recording lifecycle. Logs MUST NOT refer to `LivePr1InferenceStreamClient` for production detect decode after migration.

#### Scenario: Inference stream starts for laser

- **WHEN** native detect pipeline starts due to laser ON
- **THEN** logs SHALL include reason `laser_on`, profile `sub`, pipeline `native`, and the RTSP path suffix (e.g. `/camera/pr1`)

### Requirement: Live PR1 stain detect runs on OpenCV session

When `AiManager.isOpencvStainDetectSessionActive()` is true and laser is ON, **`OpencvStainDetectCoordinator`** SHALL subscribe to `detect_result` events from `StreamDetectResultBus` for live weld stain detect with `StainDetectSource.LIVE`. The coordinator MUST NOT invoke `AiManager.opencvStainDetectFromI420` with live PR1 I420 frames. Native detect MUST NOT block Java RTSP decode because Java no longer decodes PR1 for detect.

#### Scenario: Detect completion stays non-blocking for Java

- **WHEN** a live-weld `detect_result` arrives on the bus
- **THEN** coordinator business logic MUST run off the native uplink thread
- **AND** MUST NOT block any Java media thread waiting for native completion beyond enqueue

#### Scenario: OpenCV session inactive skips pipeline detect

- **WHEN** laser is ON but `isOpencvStainDetectSessionActive()` is false
- **THEN** Java MUST NOT start or keep the detect pipeline running solely for stain detect

### Requirement: Live PR1 SSE lifecycle uses live_stain_detect source

When **`GET /v1/camera/ai`** has subscribers, native pipeline session events routed through `StreamDetectResultBus` SHALL drive camera AI SSE lifecycle:

- **`start`** with `source` `live_stain_detect` and `samplingIntervalMs` **500** when the native detect session starts.
- **`stop`** with `reason` `laser_off`, `opencv_session_off`, `stream_error`, or `release` as appropriate.

#### Scenario: Laser on notifies subscribers

- **WHEN** laser turns ON, native detect pipeline starts, and at least one `/v1/camera/ai` subscriber is connected
- **THEN** subscribers MUST receive `event: start` with `source` `live_stain_detect` before the first `running` of that session

#### Scenario: No subscribers skips SSE lifecycle

- **WHEN** laser turns ON but zero `/v1/camera/ai` subscribers exist
- **THEN** native detect pipeline MUST still start per existing requirements when laser and session gates allow
- **AND** the system MUST NOT emit `start` or `stop` on the camera AI SSE hub

### Requirement: Cold-start AI path supervises daemon process

Production AI cold start SHALL ensure `AiDaemonSupervisor` (or equivalent) brings up `lws_ai_daemon` as a resident child at the same phase as today's `initAiEngine`, even before live StreamDetect is fully moved off JNI. Observability logs MUST distinguish daemon spawn outcome (`startup_phase=ai_daemon`) from recording lifecycle.

#### Scenario: Daemon resident after cold start

- **WHEN** App cold start completes AI initialization with Supervisor enabled
- **THEN** `lws_ai_daemon` MUST be running
- **AND** logs MUST include `startup_phase=ai_daemon` outcome

