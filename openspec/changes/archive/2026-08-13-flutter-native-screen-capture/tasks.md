## 1. Spike (gate)

- [x] 1.1 On ynh960: `gst-inspect-1.0` inventory for `mppjpegenc`, Rockchip H.264 enc name(s), RGA-related elements; record chosen still + video pipelines in `design.md` Open Questions / spike notes
- [x] 1.2 Spike Flutter/eLinux async (or lowest-jank) surface readback from **C or Rust** (FFI/MethodChannel) for one frame and for ≥5s continuous submit; measure UI jank vs idle; document hook + language choice (default C like `extract-video-frame`, or Rust if justified)
- [x] 1.3 Spike end-to-end: home ~30Hz motion → **C/Rust** + GStreamer encode → pull file; verify playback duration ≈ wall time and no sped-up opening (accept/reject FPS/SCALE defaults)

## 2. Package + on-device capture

- [x] 2.1 Create `packages/cyber_capture` (Dart public API: screenshot / record-start / record-stop / status; FFI stubs; README for other `_hmi` Apps)
- [x] 2.2 Implement native still+record in **C or Rust** (shared rootfs libexec/`.so`); wire package FFI; build via `make build-libexec-binaries` or documented package native target
- [x] 2.3 Add package-owned command watcher helper for `/run/hmi/capture.cmd` (`screenshot`, `record-start`, `record-stop`) with status/error surfacing
- [x] 2.4 Still path: one Flutter-paced frame → GStreamer `mppjpegenc` (or locked still pipeline) → stamped file + `summary.txt` fields
- [x] 2.5 Record path: Flutter-paced frames → appsrc/GStreamer video encode + optional ALSA soft-fallback; stop on command; write container + summary
- [x] 2.6 Apply ynh960 landscape orientation policy (and `ROTATE=` override) consistently for still and video
- [x] 2.7 Ensure remote staging cleanup API/hook for host after pull
- [x] 2.8 Integrate package in `app/lws_hmi` only as thin bootstrap; document copy-paste dependency steps for a second `_hmi` App

## 3. Host Make / scripts

- [x] 3.1 Replace `scripts/screenshot.sh` to trigger HMI capture + pull to `output/screenshot/` (keep `shot-<stamp>` / `shot-latest`)
- [x] 3.2 Replace `scripts/record-screen.sh` / `record-screen-host.sh` for start/stop, live timer, Ctrl+C → exit 0, pull to `output/record-screen/`
- [x] 3.3 **Delete** failed-path scripts (`scripts/build-ffmpeg-device.sh`, `scripts/ffmpeg-device-common.sh`, and any leftover ffmpeg bodies); remove `overlay/third-party/ffmpeg.version` if unused; drop `make build-ffmpeg-device`. Allowed **early** (stub Make to error → point at this change) or **at cutover** when §3.1–3.2 work — do not leave a runnable ffmpeg/`kmsgrab` capture fork
- [x] 3.4 Update Makefile Debug help, `README.md` Make-commands, `docs/make-commands.md`, `AGENTS.md` (rebuild row for `packages/cyber_capture` + native helper; remove ffmpeg-device capture rows)

## 4. Ship / verify

- [x] 4.1 Build native helper + `APP=lws_hmi make build-app` / `push-app` (and rootfs if new libexec); confirm watcher present on board
- [x] 4.2 Smoke `make screenshot` and `make record-screen` (home motion); confirm artifacts, cleanup, and no ffmpeg-device dependency
- [x] 4.3 Mark this change ready to archive when acceptance scenarios in `specs/hmi-screen-capture/spec.md` pass
