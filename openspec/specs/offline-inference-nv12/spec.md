# offline-inference-nv12 Specification

## Purpose
TBD - created by archiving change offline-inference-nv12-unification. Update Purpose after archive.
## Requirements
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

### Requirement: I420 JNI symbols SHALL NOT be exported

The App and native layer SHALL use **NV12** as the sole YUV contract for inference JNI. `nativeOpencv*FromI420` and `nativeRknnStainDetectFromI420` symbols SHALL NOT be exported from `libai.so`. Legacy decoder callbacks that emit planar I420 MUST convert at ingress via `Nv12FrameUtil.i420DirectToNv12Direct` (Java) or `i420ToNv12` (native pipeline only).

#### Scenario: verify_libai_jni requires NV12 symbols only

- **WHEN** CI runs `native/lensinspector/scripts/verify_libai_jni.sh`
- **THEN** the script MUST require `nativeOpencvStainDetectFromNv12`, `nativeOpencvZeroPointDetectFromNv12`, `nativeOpencvEdgeDrawingDetectFromNv12`, and `nativeRknnStainDetectFromNv12`
- **AND** MUST NOT require any `FromI420` symbol

#### Scenario: Java App has no FromI420 JNI declarations

- **WHEN** the App layer invokes OpenCV or RKNN one-shot YUV infer
- **THEN** it MUST call `*FromNv12` or push NV12 via `nativeRknnStainDetectFromStream`
- **AND** MUST NOT declare or link `nativeOpencv*FromI420` or `nativeRknnStainDetectFromI420`

### Requirement: Offline sessions SHALL reuse direct ByteBuffer pool

`ProcessVideoAiSession` and other offline Java sampling paths covered by this capability MUST reuse session-scoped direct `ByteBuffer` instances for NV12 conversion instead of calling `ByteBuffer.allocateDirect` on every sample.

#### Scenario: Process video sample reuses buffer

- **WHEN** `ProcessVideoAiSession` accepts consecutive infer samples at 500 ms intervals
- **THEN** it MUST convert bitmap to NV12 into a reused direct buffer when dimensions are unchanged
- **AND** MUST only reallocate when frame width or height changes

#### Scenario: Buffer pool does not change infer contract

- **WHEN** a reused NV12 buffer is passed to `nativeOpencvStainDetectFromNv12`
- **THEN** native detect results MUST match pre-pool baseline for the same input frame (bbox IoU ≥ 0.95)

### Requirement: Native MAY accept I420 direct buffer for offline infer

Native MAY expose `nativeOpencvStainDetectFromI420Direct` (and equivalent zero_point entry) accepting a direct I420 buffer for offline paths when Java can obtain YUV planes from `MediaMetadataRetriever` without Bitmap round-trip. This path is optional (Phase 4) and MUST use the same `nv12ToBgr` / color conversion chain as live pipeline when I420 is converted at ingress.

#### Scenario: I420 direct path matches NV12 bbox output

- **WHEN** offline infer uses I420 direct entry with a valid retriever frame
- **THEN** bounding box output MUST match the NV12 bitmap-conversion path within IoU ≥ 0.95
- **AND** MUST NOT require Bitmap→NV12 Java conversion for that sample

