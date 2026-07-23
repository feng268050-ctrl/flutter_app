## MODIFIED Requirements

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
