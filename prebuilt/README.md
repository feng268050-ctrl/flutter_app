# prebuilt/

Runtime artifacts tracked in git (or produced by `make build-runtime-deps`). `make check-prebuilt` verifies these plus OpenCV sources under `.cache/opencv/`.

## Runtime (`make build-runtime-deps`)

| Path | Board role | Regenerate |
|------|------------|------------|
| `flutter-engine/<ver>/arm64-release/` | HMI `libflutter_engine.so` | `make build-flutter-engine` |
| `flutter-pi/<commit>/` | `/usr/bin/flutter-pi` | `make build-flutter-pi` |
| `mediamtx/linux-arm64/` | RTSP relay + fs-overlay `usr/bin/` | `make build-mediamtx` |
| `rknn-rt/` | aarch64 `librknnrt.so` for `libai.so` | `make fetch-rknn-rt` |

OpenCV: `.cache/opencv/` (sources, not under `prebuilt/`) — `make fetch-opencv` + `fetch-opencv-ximgproc`.

Rootfs also installs SDK `external/rknpu2` via Buildroot (`BR2_PACKAGE_RKNPU2`).

## Dev host only (not in `check-prebuilt`)

| Path | Role | Command |
|------|------|---------|
| *(external)* `FLUTTER_SDK/install/` | Cross-build Flutter app | `make fetch-flutter-sdk` |
| `.cache/rknn-toolkit/` | ONNX→RKNN on x86 | `make fetch-rknn-toolkit` |

Git LFS: see `.gitattributes`. Version bump → `make rebuild-deps`.

| `gstreamer/` | MPP + GStreamer RTSP build stamp | `make build-gstreamer` |
