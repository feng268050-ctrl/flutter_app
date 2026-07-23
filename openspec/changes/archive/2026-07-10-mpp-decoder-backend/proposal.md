## Why

`StreamDetectPipeline` still decodes live PR1 via Android `NdkMediaCodec`, coupling C++ detection to the OS media stack and blocking Linux/RK3566 reuse with the same inference core. Product architecture (`docs/MPP.md`) requires **Rockchip MPP → NV12** as the C++ detect decoder, with OS APIs limited to Java playback only.

## What Changes

- Introduce OS-agnostic **`DecodedFrame`**, **`IVideoDecoder`**, and **`IFrameConverter`** in `stream_detect/` (no Android/MPP headers in pipeline code).
- Add **`platform/rockchip/MppVideoDecoder`** (H.264 access units → stride-aware NV12) behind CMake `ENABLE_ROCKCHIP_MPP`.
- Move **`NdkMediaCodec`** decode behind `platform/android/` as a **transitional fallback** when MPP is unavailable (emulator / dev host builds).
- Refactor **`RtspDemux`** to select decoder via factory: MPP preferred → Ndk fallback → OpenCV RTSP fallback unchanged.
- Update **`native-stream-detect-pipeline`** OpenSpec: normative decoder is MPP/NV12; NdkMediaCodec is transitional only.

## Capabilities

### New Capabilities

- `os-agnostic-video-decode`: Injectable decoder/converter contracts and Rockchip MPP backend for live stream detect.

### Modified Capabilities

- `native-stream-detect-pipeline`: Replace NdkMediaCodec-normative decode requirement with MPP-first `IVideoDecoder` backend; document transitional Ndk fallback.

## Impact

- **Native**: `stream_detect/*`, new `platform/rockchip/*`, `platform/android/*`, `CMakeLists.txt`
- **Build**: optional `ENABLE_ROCKCHIP_MPP` + `ROCKCHIP_MPP_ROOT` for device/BSP builds
- **Java**: unchanged (control plane + `StreamDetectResultBus` only)
- **OpenSpec**: `native-stream-detect-pipeline` delta; aligns `docs/MPP.md` with normative spec
