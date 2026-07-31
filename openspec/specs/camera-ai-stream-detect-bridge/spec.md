# camera-ai-stream-detect-bridge Specification

## Purpose

Bridge lws_ai_daemon StreamDetect evt.sock into camera AI SSE and weld laser lifecycle.

## Requirements

### Requirement: Daemon evt drives camera AI SSE

The App SHALL subscribe to `lws_ai_daemon` **evt.sock** JSON Lines and forward StreamDetect uplink types (`session_start`, `session_stop`, `detect_result`, `pipeline_state`) into `CameraAiHttpPublisher` (or equivalent). `detect_result` with `module` equal to `lens_det` MUST map to SSE `running`. Non-lens modules MUST NOT emit camera AI `running` events.

#### Scenario: Running from lens_det

- **WHEN** the daemon publishes a `detect_result` with `module` `lens_det` and at least one `/v1/camera/ai` subscriber is connected
- **THEN** the publisher MUST emit `event: running` to all subscribers

#### Scenario: Pipeline error

- **WHEN** the daemon publishes `pipeline_state` with `state` `error`
- **THEN** connected `/v1/camera/ai` clients MUST receive `event: error` when the publisher policy requires it
- **AND** the HTTP response for those subscribers MUST close

### Requirement: Weld StreamDetect lifecycle on laser ON

When laser enable / laser-on becomes active and AI lens-contamination assistance is enabled, the App SHALL ensure StreamDetect is configured and started against the local MediaMTX PR1 URL (`rtsp://127.0.0.1:8554/camera/pr1` or product-equivalent), push `laser_state` / `ai_assist_config` as needed, and stop with reason mapped to `laser_off` when laser turns off. Missing daemon MUST be non-fatal to the HMI process.

#### Scenario: Laser on starts detect

- **WHEN** laser turns ON, MediaMTX PR1 is the configured infer source, and the AI daemon is ready
- **THEN** the App MUST issue `configure_session` (if needed) and `stream_detect_start` with the PR1 RTSP URL

#### Scenario: Laser off stops detect

- **WHEN** laser turns OFF while weld StreamDetect is running
- **THEN** the App MUST stop the weld detect session
- **AND** SSE subscribers MUST receive `event: stop` with `reason` `laser_off` when a session was active
