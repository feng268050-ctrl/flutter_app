## ADDED Requirements

### Requirement: On-demand device ffmpeg is compiled and cached on the host

The project SHALL provide a host path to produce an aarch64 `ffmpeg` binary suitable for DRM screen capture and ALSA audio capture on the appliance, cached under `.cache/ffmpeg-device/` (or an equivalent documented cache path), without installing ffmpeg into the product rootfs or HMI bundle. First use of screenshot/record-screen SHALL ensure the binary exists (build if missing unless `FFMPEG_HOST=` points at an override). An explicit `make build-ffmpeg-device` (or equivalent) SHALL support forced rebuild via `FORCE=1`.

#### Scenario: First ensure builds when cache empty

- **WHEN** the cached device ffmpeg binary is absent and the operator runs `make screenshot` or `make record-screen` without `FFMPEG_HOST=`
- **THEN** the host builds (or otherwise produces) the aarch64 ffmpeg into the cache and proceeds with device staging

#### Scenario: Product image stays free of ffmpeg

- **WHEN** operators use screenshot or record-screen workflows
- **THEN** the product rootfs MUST NOT gain a packaged ffmpeg (no defconfig enablement; `/opt/hmi/bin/ffmpeg` remains absent per existing verify rules)

### Requirement: Ephemeral on-device staging over SSH

Screenshot and record-screen workflows SHALL select a device via the same `SN=` / `IP=` / USB-SSH mechanisms as other Debug SSH tools, upload the ffmpeg binary to a temporary directory under `/tmp`, run capture as root, pull artifacts to the host, and remove the remote staging tree afterward (including on failure via cleanup trap where practical).

#### Scenario: Stage run and cleanup

- **WHEN** `make screenshot` or `make record-screen` completes successfully against a reachable board
- **THEN** capture artifacts exist on the host under the documented `output/` folders and the remote `/tmp` staging directory for this tool is removed

#### Scenario: No device selected

- **WHEN** no reachable device can be selected
- **THEN** the command fails fast with an actionable error (same class as `make audit` / `make push-app`)

### Requirement: make screenshot captures one still

`make screenshot` SHALL capture a single frame of the live device display via the staged ffmpeg (DRM/`kmsgrab` by default), apply the documented orientation correction for ynh960 landscape (overridable by env), and write the image plus a short `summary.txt` under a stamped directory `output/screenshot/shot-<stamp>/`, updating `output/screenshot/shot-latest`.

#### Scenario: Successful screenshot pull

- **WHEN** the operator runs `make screenshot` on a board with an active DRM display
- **THEN** the host prints the output path and `output/screenshot/shot-latest` points at a directory containing the image file and `summary.txt`

### Requirement: make record-screen captures video with audio

`make record-screen` SHALL record device display video and ALSA audio via the staged ffmpeg until the operator stops with Ctrl+C by default (`DURATION=0`), or for `DURATION` seconds when a positive limit is set, then pull the media file plus `summary.txt` under `output/record-screen/rec-<stamp>/`, updating `output/record-screen/rec-latest`. The pulled container MUST be playable after a clean stop (including Ctrl+C finalize). Operators SHALL be able to override the ALSA device with `AUDIO_DEV=` and disable audio with `AUDIO=0`.

#### Scenario: Timed recording with audio

- **WHEN** the operator runs `DURATION=30 make record-screen` with audio enabled
- **THEN** the pulled media file contains a video track from the display capture path and an audio track from the selected ALSA input (unless the board has no usable capture PCM, in which case the command fails with a clear error or documents a forced `AUDIO=0` escape)

#### Scenario: Default unlimited until Ctrl+C

- **WHEN** the operator runs `make record-screen` without `DURATION=`
- **THEN** recording continues until Ctrl+C (or equivalent interrupt) and the host pulls a playable artifact under `output/record-screen/`

#### Scenario: Audio disabled

- **WHEN** the operator runs `AUDIO=0 make record-screen`
- **THEN** the workflow records video only and still pulls the file under `output/record-screen/`

### Requirement: record-screen shows live elapsed duration

While `make record-screen` is actively recording, the host SHALL update a single console status line at least once per second with the elapsed recording time. When `DURATION` is a positive limit, the status line SHALL also show the configured total (and/or remaining). When `DURATION=0`, the status line SHALL show elapsed time and indicate that Ctrl+C stops recording. The live timer MUST be driven primarily by the host wall clock (not solely by buffered remote ffmpeg progress lines).

#### Scenario: Timed run shows elapsed over total

- **WHEN** the operator runs `DURATION=30 make record-screen` on a TTY
- **THEN** during the capture the console shows updating elapsed time against 30 seconds (e.g. `00:12 / 00:30`) until the recording finishes

#### Scenario: Open-ended run shows elapsed until stop

- **WHEN** the operator runs `DURATION=0 make record-screen` on a TTY
- **THEN** during the capture the console shows updating elapsed time until the operator interrupts, after which the host finalizes and pulls the recording

### Requirement: Debug Make help and docs

`make screenshot` and `make record-screen` SHALL appear in the Makefile **Debug** help group, and operator usage (env vars, output paths, ffmpeg ensure/build) SHALL be documented in README Make-commands material and `docs/make-commands.md`. AGENTS rebuild guidance SHALL mark these as host-only (no firmware rebuild).

#### Scenario: help lists Debug capture targets

- **WHEN** the operator runs `make help`
- **THEN** the Debug section lists `make screenshot` and `make record-screen` with brief descriptions
