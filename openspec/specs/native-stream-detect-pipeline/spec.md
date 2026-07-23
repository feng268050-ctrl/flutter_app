# native-stream-detect-pipeline Specification

## Purpose
TBD - created by archiving change native-stream-detect-pipeline. Update Purpose after archive.
## Requirements
### Requirement: C++ StreamDetectPipeline consumes MediaMTX local PR1

The system SHALL provide a native **`StreamDetectPipeline`** in `libai.so` that independently connects to **`rtsp://127.0.0.1:8554/camera/pr1`** (or the configured MediaMTX relay sub-stream URL), demuxes video, and decodes frames without Java decode callbacks or JNI image transfer.

#### Scenario: Pipeline stops and releases resources

- **WHEN** Java invokes native `stopStreamDetect` or the App process releases the native layer
- **THEN** the pipeline MUST stop demux/decode threads
- **AND** MUST release injected **`IVideoDecoder`** instances and RTSP client resources

### Requirement: Native hardware decode uses OutputBuffer mode with NV12 normalization

The C++ detect pipeline SHALL decode H.264 access units through an injectable **`IVideoDecoder`** implementation. The **preferred** backend on RK3566 product images SHALL be **Rockchip MPP** (`MppVideoDecoder`), which MUST output **NV12** `DecodedFrame` values (stride-aware) before color conversion to **BGR** (OpenCV) or **RGB** (RKNN).

The pipeline core (`StreamDetectPipeline`, `RtspDemux`, `detect_runner`) MUST NOT include Android NDK MediaCodec headers. Android **`NdkMediaCodec`** MAY be used only inside `platform/android/` as a **transitional fallback** when MPP is unavailable (e.g. emulator builds).

#### Scenario: MPP hard decode outputs NV12

- **WHEN** `MppVideoDecoder` is active and receives a valid H.264 access unit
- **THEN** `tryReceiveFrame` MUST yield `DecodedFrame` with `PixelFormat::NV12`
- **AND** MUST convert to BGR `cv::Mat` via `IFrameConverter` before OpenCV detect entry points

#### Scenario: Soft decode fallback outputs I420

- **WHEN** hardware decode is unavailable and OpenCV/FFmpeg soft decode produces I420
- **THEN** the pipeline MUST convert I420 to NV12 before BGR/RGB conversion
- **AND** MUST use the same detect entry path as hardware decode

#### Scenario: Transitional Ndk fallback on emulator

- **WHEN** `ENABLE_ROCKCHIP_MPP` is off and the build targets Android with Ndk fallback enabled
- **THEN** `video_decoder_factory` MAY select `NdkMediaCodecVideoDecoder`
- **AND** MUST still normalize decoder output to NV12 before BGR conversion

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

The pipeline SHALL invoke existing native detection logic **inside the AI native process** (in-process `libai.so` during transition, or inside `lws_ai_daemon` after cutover) after BGR/RGB conversion:

- OpenCV stain detect (`opencv_stain_detect` / `analyzeBgr`)
- Zero-point detect (machine-model routed native detector)
- EdgeDrawing detect
- RKNN streaming path when the product switch enables it

The pipeline MUST NOT call Java JNI methods that accept I420 byte arrays for live RTSP samples.

#### Scenario: Lens det in-process

- **WHEN** a gated BGR frame is ready and the OpenCV stain session is active
- **THEN** the pipeline MUST run stain detect in native code
- **AND** MUST publish the JSON summary via the event uplink without `nativeOpencvStainDetectFromI420` from Java

#### Scenario: RKNN streaming when enabled

- **WHEN** RKNN live streaming is enabled and a gated RGB/BGR frame is ready
- **THEN** the pipeline MUST push the frame through the native RKNN streaming entry in the AI native process
- **AND** MUST publish unified inference results via the same event uplink

#### Scenario: Modules execute inside daemon after cutover

- **WHEN** live StreamDetect runs inside `lws_ai_daemon`
- **THEN** detect modules MUST execute in the daemon address space
- **AND** MUST NOT require copying full frames to the Java heap for inference

### Requirement: Pipeline publishes lightweight events to Java

After each completed detect sample or pipeline state change, the native layer MUST publish events through a **single uplink** into Java. In the daemon target architecture that uplink is **Unix socket `evt.sock` JSON Lines** (protocol `v=1`). Until the live path cutover completes, an in-process **JNI uplink callback** MAY remain as the transitional uplink, but the product live path MUST NOT retain JNI as the long-term publish mechanism.

Event types include:

- `combined_frame` — per sampled frame, all module results in one JSON with `frame_pts_ms` and `modules` map (preferred for live detect samples)
- `detect_result` — per-module parsed detection JSON, `timestampMs`, `frame_id`, module id (deprecated as separate native invocations; MAY remain as bus-dispatched events parsed from `combined_frame`)
- `pipeline_state` — `running`, `idle`, `error`, reconnect reason
- `session_start` / `session_stop` — `sessionId`, `source`, `samplingIntervalMs`
- `error` — `code`, `message`

For each gated detect sample frame with multiple active modules, native MUST publish **once** with `combined_frame`, not once per module.

The pipeline MUST NOT publish raw YUV or bitmap payloads to Java.

#### Scenario: Detect result published after sample

- **WHEN** a gated detect sample completes in native code
- **THEN** Java MUST receive detection events on the registered uplink (evt subscriber and/or transitional JNI callback during migration)
- **AND** the payload MUST include `timestampMs` / `frame_pts_ms` and detection JSON fields per existing native API contracts

#### Scenario: Stream error does not crash Java playback

- **WHEN** the C++ RTSP session fails or decode errors occur
- **THEN** the pipeline MUST publish `pipeline_state` or `error` events
- **AND** Java `EasyPlayerClient` playback on a separate RTSP session MUST continue unaffected

#### Scenario: One uplink invocation per multi-module sample

- **WHEN** lens_det and zero_point both complete on the same gated sample frame
- **THEN** native MUST publish one `combined_frame` event
- **AND** MUST NOT publish separate per-module uplink messages for that frame as the primary path

### Requirement: Java control plane commands native pipeline

Java SHALL control the pipeline via an explicit command plane (not Pub-Sub on the result bus):

- `start` / `stop` session lifecycle
- laser Bit0 gate (`laser_on` / `setLaserOn`)
- `setBurstMode(boolean)` or equivalent burst entry/exit signal
- Per-module enable flags and ROI/config paths for lens_det, zero_point, edgedrawing

In the daemon target architecture these commands MUST be issued over **`cmd.sock`** (`stream_detect_start` / `stream_detect_stop` / `laser_state` / `configure_session` / `ai_assist_config`). Transitional JNI command methods MAY remain until the live-path cutover (P1) completes, after which product live control MUST NOT call `nativeStartStreamDetect` / equivalent in-process JNI.

#### Scenario: Laser off stops detect scheduling

- **WHEN** Java sets laser gate false (`laser_state` / `setLaserOn(false)`) while the pipeline is running
- **THEN** the pipeline MUST stop scheduling new detect samples for laser-gated modules
- **AND** MUST reset burst and sampling state for the live weld path

#### Scenario: Laser on with active session starts sampling

- **WHEN** laser is ON, OpenCV/AI assist session gates allow, and Java has started the pipeline
- **THEN** the pipeline MUST resume gated detect sampling without restarting Java decode clients

#### Scenario: P1 live path uses socket commands

- **WHEN** P1 cutover is complete for live StreamDetect
- **THEN** Java MUST start/stop the live pipeline via daemon cmd types
- **AND** MUST NOT invoke process-in `nativeStartStreamDetect` for that product path

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

### Requirement: CentralScheduler stain path SHALL integrate frame ring buffer

The native stain scheduling path (`CentralScheduler` / `central_scheduler.cpp`) MUST use `FrameRingBuffer` for BGR frame handoff between decode and stain worker threads, eliminating redundant `cv::Mat::clone()` on the hot path.

#### Scenario: Ring buffer enabled by default

- **WHEN** `libai.so` is built with default options
- **THEN** stain frame handoff MUST use the ring buffer implementation
- **AND** `LENS_INFER_TIMING` MUST report reduced `frame_copy_ms` versus clone baseline

### Requirement: Stain worker SHALL use joinable lifecycle not detach

Stain detect worker threads MUST be managed by a `StainWorkerPool` (or equivalent) that supports `shutdown()` with queue drain and `join()`. `std::thread(...).detach()` MUST NOT be used for stain workers.

#### Scenario: Clean shutdown on scheduler destroy

- **WHEN** `CentralScheduler` is destroyed or native session stops
- **THEN** stain worker threads MUST be joined after pending work completes or is cancelled
- **AND** MUST NOT leave detached threads accessing freed scheduler state

