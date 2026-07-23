# Camera stream capability inventory

## Tested setup (lws-ui field + repo scripts)

| Item | Value |
|------|--------|
| RTSP main path (recording) | `CameraConfig.CAMERA_RTSP_MAIN_PATH` → `/PR0` (fixed) |
| RTSP sub path (live / AI Vision) | `CameraConfig.CAMERA_RTSP_SUB_PATH` → `/PR1` (fixed) |
| Camera IP | `CameraConfig.CAMERA_IP` → `192.168.1.100` (fixed) |
| Reachability probe | `scripts/device-network/probe-dual-stream.sh <adb_serial> <camera_ip>` — `DESCRIBE` on both paths |
| IPC Web sub-stream reference | See `docs/dual-stream-workflow.md` — current camera fixes sub at **1920×1080** (same as main) |

## Resolution

Effective width/height are **not** hard-coded in the app: they come from the decoder (`RESULT_VIDEO_SIZE` / `LIVE_VIDEO_SIZE` logs). **Current IPC:** main and sub are both **1920×1080** (may report as 1920×1088 coded height).

## Models / firmware

Record the camera model and firmware version used during validation here when locking a release:

- Model: _TBD_
- Firmware: _TBD_
