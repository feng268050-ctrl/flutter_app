## ADDED Requirements

### Requirement: C++ StreamDetectPipeline consumes MediaMTX local PR1

The system SHALL provide a native **`StreamDetectPipeline`** in `libai.so` that independently connects to **`rtsp://127.0.0.1:8554/camera/pr1`** (or the configured MediaMTX relay sub-stream URL), demuxes video, and decodes frames without Java decode callbacks or JNI image transfer.

#### Scenario: Pipeline starts on Java command

- **WHEN** Java invokes native `startStreamDetect` with a valid RTSP URL and active detection session handles
- **THEN** the pipeline MUST open an independent RTSP reader session to the relay sub-stream
- **AND** MUST NOT require `LivePr1InferenceStreamClient` or `EasyPlayerClient` to supply frames

#### Scenario: Pipeline stops and releases resources

- **WHEN** Java invokes native `stopStreamDetect` or the App process releases the native layer
- **THEN** the pipeline MUST stop demux/decode threads
- **AND** MUST release `NdkMediaCodec` and RTSP client resources

### Requirement: Native hardware decode uses OutputBuffer mode with NV12 normalization

The pipeline SHALL decode video using **`NdkMediaCodec`** in **OutputBuffer** mode (no Surface output). Regardless of decoder output `color-format` (NV12, I420, or flexible), the pipeline MUST normalize to **NV12** before color conversion to **BGR** (OpenCV) or **RGB** (RKNN).

#### Scenario: Hard decode outputs semi-planar NV12

- **WHEN** `NdkMediaCodec` delivers a decoded buffer with semi-planar YUV
- **THEN** the pipeline MUST treat it as NV12 (or convert to NV12 if required)
- **AND** MUST convert to BGR `cv::Mat` for OpenCV detect entry points

#### Scenario: Soft decode fallback outputs I420

- **WHEN** hardware decode is unavailable and FFmpeg soft decode produces I420
- **THEN** the pipeline MUST convert I420 to NV12 before BGR/RGB conversion
- **AND** MUST use the same detect entry path as hardware decode

### Requirement: Frame sampling runs inside native pipeline

The pipeline SHALL apply frame-sampling intervals internally:

- **500 ms** normal mode for live weld stain detect and zero-point (`LIVE_WELD` / `ZERO_POINT_ON_LASER` alignment)
- **100 ms** burst mode when burst is active after native `code=-5` (`FRAME_REJECTED_BURST` alignment)

Decode MAY run at full frame rate; only gated samples SHALL invoke detection.

#### Scenario: Normal weld sampling at 500 ms

- **WHEN** laser is ON, burst mode is inactive, and decode runs at 25 fps
- **THEN** at most one detect sample per active module MUST start per 500 ms

#### Scenario: Burst mode uses 100 ms

- **WHEN** burst mode is active after a `code=-5` result on the live path
- **THEN** subsequent detect samples MUST use at most one accept per 100 ms per participating module

### Requirement: Detection modules run in-process without JNI image transfer

The pipeline SHALL invoke existing native detection logic in-process after BGR/RGB conversion:

- OpenCV stain detect (`opencv_stain_detect` / `analyzeBgr`)
- Zero-point detect (machine-model routed native detector)
- EdgeDrawing detect
- RKNN streaming path when the product switch enables it

The pipeline MUST NOT call Java JNI methods that accept I420 byte arrays for live RTSP samples.

#### Scenario: Lens det in-process

- **WHEN** a gated BGR frame is ready and the OpenCV stain session is active
- **THEN** the pipeline MUST run stain detect in native code
- **AND** MUST publish the JSON summary via the event bridge without `nativeOpencvStainDetectFromI420` from Java

#### Scenario: RKNN streaming when enabled

- **WHEN** RKNN live streaming is enabled and a gated RGB/BGR frame is ready
- **THEN** the pipeline MUST push the frame through the native RKNN streaming entry in-process
- **AND** MUST publish unified inference results via the same event bridge

### Requirement: Pipeline publishes lightweight events to Java

After each completed detect sample or pipeline state change, the native layer MUST publish events through a **single JNI uplink callback** with types including:

- `detect_result` — parsed detection JSON, `timestampMs`, `frame_id`, module id
- `pipeline_state` — `running`, `idle`, `error`, reconnect reason
- `session_start` / `session_stop` — `sessionId`, `source`, `samplingIntervalMs`
- `error` — `code`, `message`

The pipeline MUST NOT publish raw YUV or bitmap payloads to Java.

#### Scenario: Detect result published after sample

- **WHEN** a gated detect sample completes in native code
- **THEN** Java MUST receive a `detect_result` event on the registered uplink callback
- **AND** the payload MUST include `timestampMs` and detection JSON fields per existing native API contracts

#### Scenario: Stream error does not crash Java playback

- **WHEN** the C++ RTSP session fails or decode errors occur
- **THEN** the pipeline MUST publish `pipeline_state` or `error` events
- **AND** Java `EasyPlayerClient` playback on a separate RTSP session MUST continue unaffected

### Requirement: Java control plane commands native pipeline

Java SHALL control the pipeline via command JNI (non Pub-Sub):

- `start` / `stop` session lifecycle
- `setLaserOn(boolean)` synchronized with device laser state
- `setBurstMode(boolean)` or equivalent burst entry/exit signal
- Per-module enable flags and ROI/config paths for lens_det, zero_point, edgedrawing

#### Scenario: Laser off stops detect scheduling

- **WHEN** Java calls `setLaserOn(false)` while the pipeline is running
- **THEN** the pipeline MUST stop scheduling new detect samples for laser-gated modules
- **AND** MUST reset burst and sampling state for the live weld path

#### Scenario: Laser on with active session starts sampling

- **WHEN** laser is ON, OpenCV session is active, and Java has started the pipeline
- **THEN** the pipeline MUST resume gated detect sampling without restarting Java decode clients

### Requirement: Reconnect and lifecycle tie to Java session

The pipeline SHALL support stream disconnect detection, bounded reconnect with backoff, and clean shutdown when Java stops the session or the App background-releases native resources.

#### Scenario: RTSP disconnect triggers reconnect

- **WHEN** the MediaMTX relay or upstream source drops the C++ reader session
- **THEN** the pipeline MUST attempt reconnect with documented backoff
- **AND** MUST publish `pipeline_state` reflecting reconnect attempts

#### Scenario: Java stop cancels reconnect loop

- **WHEN** Java invokes `stopStreamDetect` during reconnect
- **THEN** reconnect MUST cease
- **AND** the pipeline MUST reach `idle` state
