## 1. OS-agnostic contracts

- [x] 1.1 Add `decoded_frame.h`, `ivideo_decoder.h`, `iframe_converter.h` under `stream_detect/`
- [x] 1.2 Add `PortableBgrConverter` wrapping `nv12ToBgr` with stride support
- [x] 1.3 Add `video_decoder_factory` (MPP preferred, Ndk transitional fallback)

## 2. Platform backends

- [x] 2.1 Add `platform/android/ndk_media_codec_video_decoder.*` (implements `IVideoDecoder`)
- [x] 2.2 Add `platform/rockchip/mpp_video_decoder.*` behind `ENABLE_ROCKCHIP_MPP`
- [x] 2.3 Wire BSP `librkmpp` paths on RK3566 device build and validate on hardware

## 3. Pipeline integration

- [x] 3.1 Refactor `RtspDemux` to use `IVideoDecoder` + `IFrameConverter` (remove direct `MediaCodecDecoder` include)
- [x] 3.2 Update `CMakeLists.txt` options and source lists
- [x] 3.3 Remove legacy `media_codec_decoder.*` after Ndk adapter verified

## 4. Spec & docs

- [x] 4.1 OpenSpec delta `native-stream-detect-pipeline` (MPP-first decode)
- [x] 4.2 Archive change and merge spec; update `docs/MPP.md` implementation status table

## 5. Verification

- [x] 5.1 `make build` with MPP OFF (Ndk fallback + OpenCV path)
- [x] 5.2 Device build with `ENABLE_ROCKCHIP_MPP=ON`; log `backendName()=mpp`
- [x] 5.3 `make sync` emulator smoke (pipeline start/stop, no regression)
