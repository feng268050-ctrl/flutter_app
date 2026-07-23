## MODIFIED Requirements

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

## ADDED Requirements

### Requirement: Cold-start AI path supervises daemon process

Production AI cold start SHALL ensure `AiDaemonSupervisor` (or equivalent) brings up `lws_ai_daemon` as a resident child at the same phase as today's `initAiEngine`, even before live StreamDetect is fully moved off JNI. Observability logs MUST distinguish daemon spawn outcome (`startup_phase=ai_daemon`) from recording lifecycle.

#### Scenario: Daemon resident after cold start

- **WHEN** App cold start completes AI initialization with Supervisor enabled
- **THEN** `lws_ai_daemon` MUST be running
- **AND** logs MUST include `startup_phase=ai_daemon` outcome
