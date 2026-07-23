## ADDED Requirements

### Requirement: Offline OpenCV inference SHALL use NV12 direct buffers

For Java-owned offline frame sampling (process video Detect, manual zero-point offline stages, and other non-live OpenCV one-shot paths covered by this capability), the App SHALL convert sampled frames to **NV12** layout (Y plane followed by interleaved UV, stride equal to frame width) in a **direct** `ByteBuffer` before invoking native OpenCV detect JNI.

The NV12 payload size MUST be `width * height * 3 / 2` bytes. Width and height MUST match the sampled bitmap dimensions after any existing product-side dimension resolution.

#### Scenario: Process video sample produces NV12

- **WHEN** `ProcessVideoAiSession` accepts a process-video infer sample at time `sampleMs`
- **THEN** the App MUST convert the retriever bitmap to NV12 via the shared NV12 frame utility
- **AND** MUST NOT pass I420 buffers to OpenCV stain detect for that sample

#### Scenario: Invalid NV12 buffer rejected before JNI

- **WHEN** an NV12 buffer capacity is smaller than `width * height * 3 / 2`
- **THEN** the App MUST fail fast without calling native OpenCV detect JNI
- **AND** MUST log a diagnostic without crashing the session

### Requirement: Native offline OpenCV JNI SHALL accept NV12 and convert via shared nv12ToBgr

Native OpenCV stain, zero_point, and edgedrawing one-shot entry points for offline use SHALL include `nativeOpencv*FromNv12` methods that accept a direct NV12 buffer and dimensions, convert to BGR using the same **`nv12ToBgr`** implementation as `StreamDetectPipeline`, and then invoke the existing in-process detect logic.

#### Scenario: Stain detect FromNv12 matches live color path

- **WHEN** `nativeOpencvStainDetectFromNv12` is called with a valid NV12 buffer and active session handle
- **THEN** native code MUST use `nv12ToBgr` (or shared equivalent) before stain detect analysis
- **AND** MUST NOT use `cv::COLOR_YUV2BGR_I420` on the primary NV12 entry path

#### Scenario: Zero point FromNv12 on offline manual stage

- **WHEN** an offline manual auto stage submits a retriever frame to zero_point detect
- **THEN** the App MUST call `nativeOpencvZeroPointDetectFromNv12` (or session wrapper that uses it)
- **AND** MUST NOT call `nativeOpencvZeroPointDetectFromI420` for that offline sample

### Requirement: Deprecated I420 JNI SHALL shim through NV12 conversion

Existing `nativeOpencv*FromI420` symbols SHALL remain available for compatibility. Their implementation SHALL convert I420 to NV12 via `i420ToNv12` then follow the same BGR/detect path as `FromNv12`, so deprecated and NV12 entry points produce equivalent results for the same planar input.

#### Scenario: FromI420 shim uses i420ToNv12

- **WHEN** legacy code invokes `nativeOpencvStainDetectFromI420`
- **THEN** native code MUST convert I420 to NV12 before BGR conversion
- **AND** MUST NOT maintain a separate permanent `COLOR_YUV2BGR_I420` detect path

#### Scenario: verify_libai_jni lists both symbol families

- **WHEN** CI runs `native/lensinspector/scripts/verify_libai_jni.sh`
- **THEN** the script MUST require `nativeOpencvStainDetectFromNv12`, `nativeOpencvZeroPointDetectFromNv12`, and `nativeOpencvEdgeDrawingDetectFromNv12`
- **AND** MUST continue to require existing `FromI420` symbols until a future removal change
