## 1. On-demand ffmpeg (host compile + cache)

- [ ] 1.1 Add `overlay/third-party/ffmpeg.version` (pinned upstream tag/URL) and gitignore `.cache/ffmpeg-device/` if not already covered by `.cache/`
- [ ] 1.2 Implement `scripts/build-ffmpeg-device.sh`: cross-compile aarch64 ffmpeg (Docker/SDK toolchain on macOS) with `kmsgrab`/libdrm + ALSA + needed encoders/filters; install to `.cache/ffmpeg-device/ffmpeg`; honor `FORCE=1`
- [ ] 1.3 Add Makefile target `build-ffmpeg-device` wiring the script

## 2. Shared SSH staging helpers

- [ ] 2.1 Add `scripts/ffmpeg-device-common.sh`: `ensure_ffmpeg_device` (build if missing; `FFMPEG_HOST=` override), USB-SSH session prepare, SCP stage to `/tmp/lws-screen-capture/`, remote run helper, EXIT cleanup of remote staging
- [ ] 2.2 Write stamped `summary.txt` helper (SN/IP/stamp/ffmpeg version/DRM/`AUDIO_DEV`/duration)

## 3. Screenshot + record-screen scripts

- [ ] 3.1 Implement `scripts/screenshot.sh`: single-frame `kmsgrab` (+ orientation filter / `ROTATE=`), pull image to `output/screenshot/shot-<stamp>/`, update `shot-latest`, print path
- [ ] 3.2 Implement `scripts/record-screen.sh`: A/V record with `DURATION=` (default 30; `0` = until Ctrl+C), `AUDIO_DEV=` / `AUDIO=0`, pull to `output/record-screen/rec-<stamp>/`, update `rec-latest`
- [ ] 3.3 Fail fast with clear errors when DRM grab or (when audio enabled) ALSA open fails

## 4. Makefile Debug wiring + docs

- [ ] 4.1 Add `screenshot` and `record-screen` Make targets; list them under the Debug help group (plus optional `build-ffmpeg-device` near Dependencies or Debug)
- [ ] 4.2 Document in README Make-commands section and `docs/make-commands.md` (怎么用 / 参数 / 输出目录 / 不进 rootfs)
- [ ] 4.3 Update AGENTS.md rebuild table: host-only exercise targets; confirm no firmware rebuild path

## 5. Board smoke validation

- [ ] 5.1 On ynh960: run `make build-ffmpeg-device` then `make screenshot`; confirm upright landscape still and remote `/tmp` cleaned
- [ ] 5.2 Run `make record-screen` with audio; confirm pulled file has video + audio (or document `AUDIO_DEV=` / `AUDIO=0` for the board PCM layout)
- [ ] 5.3 Confirm `scripts/verify-rootfs-overlay.sh` still passes the no-`/opt/hmi/bin/ffmpeg` check (no product regression)
