# Rendering path evaluation: TextureView vs SurfaceView

## Current path

AI Vision currently renders through `EasyPlayerClient(context, binding.textureVisionView, ...)`, so the visible surface is a `TextureView`. Pinch zoom uses `TextureView.setTransform(Matrix)` plus a separate `DetectionOverlayView` transform.

## SurfaceView recommendation in `实时视频流.md`

The document recommends `SurfaceView` for a lower-latency industrial path because it can compose through SurfaceFlinger with less UI-layer overhead. This is directionally correct for a future FFmpeg/MPP/OES pipeline.

## Decision for phase 1

Keep `TextureView` for now.

Rationale:

- Current field logs show the dominant issue is **producer/consumer queue backlog** (`queue full:500`, ~34s cache), not UI composition alone.
- `TextureView` supports the existing zoom transform directly; replacing it with `SurfaceView` would require reworking pinch zoom and overlay composition.
- `EasyPlayerClient` already accepts a `TextureView` lifecycle and internally owns the `Surface`; changing this now would expand risk beyond the root-cause fix.

## Future path

Revisit `SurfaceView` only after:

1. Low-latency queue behavior is verified on device.
2. `decodeType=1` (MediaCodec) is confirmed or fixed.
3. AI frame copy/decimation is evaluated.

If still high-latency after those steps, run a dedicated phase-2 spike: SurfaceView/OES or FFmpeg + MPP direct surface output.
