# StreamDetectPipeline Acceptance (Task 2.8)

Device / relay validation for C++ PR1 pull, hard decode, NV12→BGR, and MediaMTX multi-reader.

## Prerequisites

| Item | Requirement |
|------|-------------|
| Device | RK3566 tablet or arm64 emulator with relay |
| MediaMTX | Relay ready; `rtsp://127.0.0.1:8554/camera/pr1` playing |
| Flag | `CameraConfig.isNativeWeldStreamDetectEnabled() = true` (weld path smoke) |
| Build | `make sync` after flag change |

## S1 — Stable RTSP pull

1. Open Quick or Engineer mode; turn laser **ON**.
2. Logcat: `adb logcat -v time -s StreamDetect:I NativeStreamDetect:I`

**Pass**

- `session_start` / `StreamDetect: connected` within ~5 s
- No crash loop; reconnect backoff logs if camera briefly offline
- `sampled frame_id=` lines appear at ~500 ms (laser ON)

## S2 — Hardware decode

**Pass**

- Sustained `sampled` lines with `decode_ms` present
- No permanent `pipeline_state error` while relay healthy

## S3 — NV12 → BGR / detect

**Pass**

- `detect_result module=lens_det` or `module=zero_point` with plausible JSON
- `detect_ms` and `e2e_ms` logged on sampled frames
- OpenCV stain session active → overlay or coordinator logs on weld path

## S4 — MediaMTX multi-reader

1. Enable **both** `isNativeWeldStreamDetectEnabled()` and `isNativeAiVisionStreamDetectEnabled()`.
2. Open AI Vision live (no process video) **while** weld detect runs (laser ON in background mode if product allows, or sequential: AI Vision + native ai_vision holder).

**Pass**

- Java `VIDEO_DISPLAYED decodeType=1` on AI Vision
- `duplicate_rtsp=ai_vision_preview` logged
- Both playback and native detect receive frames (no single-reader stall)
- MediaMTX fanout stable 5+ min

## S5 — Sign-off

| Check | Pass? | Notes |
|-------|-------|-------|
| S1 RTSP stable | | |
| S2 Hard decode | | |
| S3 NV12→BGR + detect | | |
| S4 Multi-reader | | |

Tester / date: ___________

When all pass, mark task **2.8** complete in `tasks.md`.
