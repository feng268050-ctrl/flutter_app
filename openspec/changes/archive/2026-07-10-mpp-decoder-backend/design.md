## Context

Live detect today: `RtspTcpSession` → Annex-B AU → `MediaCodecDecoder` (`NdkMediaCodec`) → NV12 → `nv12ToBgr` → `StreamDetectPipeline`. Java `EasyPlayerClient` uses a separate Android `MediaCodec` session for UI only.

Target (MPP.md §2–§11): inference core must not `#include` NDK MediaCodec; decode injects via `IVideoDecoder`.

## Goals / Non-Goals

**Goals**

- `StreamDetectPipeline` / `RtspDemux` depend only on `IVideoDecoder` + `IFrameConverter`.
- `MppVideoDecoder` produces stride-aware NV12 `DecodedFrame` on RK3566 when `ENABLE_ROCKCHIP_MPP=ON`.
- Dev/emulator builds keep working via Ndk transitional fallback + existing OpenCV RTSP fallback.

**Non-Goals**

- Replace Java playback decode (`EasyPlayerClient`).
- RGA `RgaConverter` in this change (portable `nv12ToBgr` remains default).
- H.265 MPP path (follow-up after H.264 MPP lands).

## Decisions

### 1. Interface boundary

```text
RtspDemux
  → IVideoDecoder::queueAccessUnit / tryReceiveFrame(DecodedFrame)
  → IFrameConverter::toBgr(DecodedFrame, cv::Mat)
```

`DecodedFrame` carries `width`, `height`, `stride`, `slice_height`, `PixelFormat::NV12`, `pts_us`.

### 2. Backend selection (`video_decoder_factory`)

| Priority | Backend | When |
|----------|---------|------|
| 1 | `MppVideoDecoder` | `LWS_HAVE_ROCKCHIP_MPP` and `configureAvc` succeeds |
| 2 | `NdkMediaCodecVideoDecoder` | Android && `ENABLE_STREAM_DETECT_NDK_FALLBACK` (default ON) |
| 3 | (none) | `RtspDemux` tries OpenCV `VideoCapture` fallback |

### 3. CMake

```cmake
option(ENABLE_ROCKCHIP_MPP "Rockchip MPP decoder for stream_detect" OFF)
option(ENABLE_STREAM_DETECT_NDK_FALLBACK "NdkMediaCodec fallback when MPP unavailable" ON)
```

Device BSP build sets `ENABLE_ROCKCHIP_MPP=ON` and `ROCKCHIP_MPP_INCLUDE` / `ROCKCHIP_MPP_LIB`.

### 4. File layout

```text
stream_detect/decoded_frame.h
stream_detect/ivideo_decoder.h
stream_detect/iframe_converter.h
stream_detect/portable_bgr_converter.*
stream_detect/video_decoder_factory.*
platform/rockchip/mpp_video_decoder.*
platform/android/ndk_media_codec_video_decoder.*  # wraps legacy MediaCodecDecoder logic
```

Remove direct `media_codec_decoder.h` include from `rtsp_demux.h`.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| MPP headers/libs absent on macOS CI | MPP behind `ENABLE_ROCKCHIP_MPP`; default OFF; Ndk + OpenCV fallback |
| Stride ≠ width | `DecodedFrame.stride`; `nv12ToBgr` uses stride when set |
| Spec still says NdkMediaCodec | Delta updates normative requirement to MPP-first |

## Migration Plan

1. Land interfaces + factory + Ndk adapter (behavior unchanged when MPP OFF).
2. Enable `ENABLE_ROCKCHIP_MPP` on RK3566 device CI / `make ai` with BSP paths.
3. Field validate PR1 detect; then default `ENABLE_STREAM_DETECT_NDK_FALLBACK=OFF` on product images.

## Open Questions

- Exact BSP path for `librkmpp.so` on current RK3566 image (document in README when known).
- H.265 PR1 codec support timeline.
