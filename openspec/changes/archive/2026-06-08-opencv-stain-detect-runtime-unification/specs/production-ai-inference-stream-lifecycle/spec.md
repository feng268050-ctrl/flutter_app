## MODIFIED Requirements

### Requirement: Production-mode inference stream follows laser state

In Quick Mode and Engineer Mode, the system SHALL start **`LivePr1InferenceStreamClient`** when the device laser is ON and the OpenCV stain-detect session is active, and SHALL stop it when the laser is OFF or the session is unavailable. This lifecycle SHALL NOT depend on whether process video recording is active.

#### Scenario: Laser on without recording

- **WHEN** the user enables laser in Quick Mode or Engineer Mode and video recording is not started
- **THEN** the app SHALL connect to the sub-stream URL (`CameraConfig.LIVE_INFERENCE_RTSP_URL`, `/PR1`)
- **AND** decoded frames SHALL be subject to the OpenCV live-weld sampling gate (`AiFrameSamplingInterval.LIVE_WELD`, 2000 ms) before `OpencvStainDetectCoordinator` submits `opencvStainDetectFromI420`
- **AND** `nativeSetLaserOn` SHALL reflect the actual laser state from device status

#### Scenario: Laser off stops inference stream

- **WHEN** the user disables laser while the live PR1 inference stream is active
- **THEN** `LivePr1InferenceStreamClient` SHALL stop
- **AND** OpenCV live-weld frame sampling MUST reset
- **AND** recording MAY continue if the user had started it independently

### Requirement: Production sub-stream frames are decimated before stain detect

In Quick Mode and Engineer Mode, when `LivePr1InferenceStreamClient` delivers decoded I420 frames, the system SHALL apply `AiFrameSamplingInterval.LIVE_WELD` (2000 ms) before copying frame payload and calling `AiManager.opencvStainDetectFromI420` on a background worker. Decode callbacks MAY continue at full frame rate; only gated samples SHALL invoke stain detect.

#### Scenario: Laser on with sub-stream at video frame rate

- **WHEN** laser is ON and the inference RTSP client decodes at typical video frame rate (e.g. 25 fps)
- **THEN** at most one OpenCV stain detect MUST start per 2000 ms
- **AND** inference stream lifecycle (start/stop on laser) SHALL remain unchanged

### Requirement: Inference stream lifecycle observability

Diagnostics logs SHALL distinguish **`LivePr1InferenceStreamClient`** lifecycle from recording lifecycle.

#### Scenario: Inference stream starts for laser

- **WHEN** sub-stream inference client starts due to laser ON
- **THEN** logs SHALL include reason `laser_on`, profile `sub`, and the RTSP path suffix (e.g. `/PR1`)

## ADDED Requirements

### Requirement: Live PR1 stain detect runs on OpenCV session

When `AiManager.isOpencvStainDetectSessionActive()` is true and laser is ON, `OpencvStainDetectCoordinator` SHALL sample PR1 I420 frames at `LIVE_WELD` and invoke `AiManager.opencvStainDetectFromI420` with `StainDetectSource.LIVE` on a background executor. The RTSP decode callback MUST NOT block on detect completion.

#### Scenario: Decode callback stays non-blocking

- **WHEN** the live-weld gate accepts a frame at video frame rate
- **THEN** the decode callback MUST return without waiting for OpenCV stain detect completion
- **AND** detect MUST run on the OpenCV live-weld worker thread

#### Scenario: OpenCV session inactive skips stream

- **WHEN** laser is ON but `isOpencvStainDetectSessionActive()` is false
- **THEN** `LivePr1InferenceStreamCoordinator` MUST NOT keep streaming for stain detect
- **AND** MUST stop with reason documenting session unavailability

### Requirement: Live PR1 SSE lifecycle uses live_stain_detect source

When **`GET /v1/camera/ai`** has subscribers, `LivePr1InferenceStreamClient` SHALL emit camera AI SSE lifecycle events:

- **`start`** with `source` `live_stain_detect` and `samplingIntervalMs` `2000` when the infer RTSP session starts.
- **`stop`** with `reason` `laser_off`, `opencv_session_off`, `stream_error`, or `release` as appropriate.

#### Scenario: Laser on notifies subscribers

- **WHEN** laser turns ON, live PR1 stream starts, and at least one `/v1/camera/ai` subscriber is connected
- **THEN** subscribers MUST receive `event: start` with `source` `live_stain_detect` before the first `running` of that session

## REMOVED Requirements

### Requirement: Production inference uses inferFromI420 on a background worker

**Reason**: Replaced by OpenCV `opencvStainDetectFromI420` on `OpencvStainDetectCoordinator`.

**Migration**: See **Live PR1 stain detect runs on OpenCV session**.

### Requirement: Production on-frame compositing only when camera AI HTTP has subscribers

**Reason**: `GET /v1/camera/ai` is SSE JSON only; no composited H.264 encode path.

**Migration**: LAN clients render overlays client-side from `running` events.

### Requirement: Production path drops samples when unified infer is in flight

**Reason**: Superseded by OpenCV busy-drop + hold-forward in `lens-det-app-inference` and SSE hub.

**Migration**: Use `isOpencvStainDetectBusy()` semantics.

### Requirement: Production infer stream notifies camera AI SSE lifecycle

**Reason**: Superseded by **Live PR1 SSE lifecycle uses live_stain_detect source** (updated class names and source tag).

**Migration**: N/A — content merged into ADDED requirement.
