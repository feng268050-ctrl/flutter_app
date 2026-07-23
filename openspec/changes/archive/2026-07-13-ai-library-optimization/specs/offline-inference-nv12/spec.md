## ADDED Requirements

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
