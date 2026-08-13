# hmi-screen-capture Specification

## Purpose

Board + host contracts for Flutter-seat screenshot and screen recording via shared `packages/cyber_capture` (Flutter-paced frames, eLinux present-hook + C encode library + GStreamer/MPP/RGA, host Make trigger/pull), reusable across product `*_hmi` Apps and the OS Settings seat.

## Requirements

### Requirement: Single HMI capture route for still and video

The project SHALL provide one on-device capture implementation for both screenshot and screen recording that obtains pixels from the Flutter/eLinux HMI surface (Flutter-paced), encodes with rootfs GStreamer using Rockchip MPP and RGA when available, and SHALL NOT rely on ephemeral host-built `ffmpeg` or DRM `kmsgrab` for these operator workflows. Continuous capture and encode logic SHALL be implemented in native code: eLinux present-hook glue in **C++** (matching `flutter-wayland-client`) and encode/control in **C** (or Rust if justified); Dart is limited to control/watchers and FFI. A Dart-only `toImage` loop MUST NOT be the record path.

The implementation SHALL be packaged for reuse: a Dart package under `packages/` (canonical name **`cyber_capture`**) plus shared native artifacts on rootfs (`libhmi_capture.so`), such that any product HMI app (`*_hmi`) can depend on the package without reimplementing capture or bundling a private ffmpeg/kmsgrab path.

#### Scenario: No parallel ffmpeg capture path

- **WHEN** an operator uses the supported Make screenshot or record-screen entrypoints after this change is implemented
- **THEN** the workflow SHALL NOT stage `.cache/ffmpeg-device/ffmpeg` or invoke `kmsgrab` for capture

#### Scenario: Native language for capture encode path

- **WHEN** implementers land the on-device capture helper for record (and the preferred still path)
- **THEN** the pixel readback and GStreamer pipeline SHALL be native (C++ present-hook + C encode library, or documented Rust), not a continuous Dart `RepaintBoundary.toImage` encoder

#### Scenario: Failed ffmpeg path removed

- **WHEN** this capability is shipped
- **THEN** the repository SHALL NOT ship a runnable ephemeral-ffmpeg/`kmsgrab` screenshot or record-screen implementation; unused scripts from the abandoned path SHALL be deleted (not kept as a second toolchain)

### Requirement: Flutter-paced frame timing

Screen recording SHALL timestamp and accept frames according to Flutter/eLinux presentation timing (present-hook or equivalent). The system MUST NOT invent a capture timeline solely from DRM page-flip cadence or by draining a multi-second framebuffer queue into a compressed CFR timeline.

#### Scenario: Home motion plays realtime

- **WHEN** the operator records the home screen while ~30Hz Flutter motion is visible and stops after a known wall duration N seconds
- **THEN** the pulled video SHALL play for approximately N seconds (±10%) without a sped-up opening segment followed by a later “stable” pace

### Requirement: make screenshot via HMI capture

`make screenshot` SHALL trigger on-device HMI capture of a single frame, apply the product landscape orientation policy for ynh960 (overridable by documented env), pull the image plus `summary.txt` under `output/screenshot/shot-<stamp>/`, and update `output/screenshot/shot-latest`.

#### Scenario: Successful screenshot pull

- **WHEN** the operator runs `make screenshot` against a reachable board with HMI running the capture watcher
- **THEN** the host prints the output path and `shot-latest` points at a directory containing the image and `summary.txt`

### Requirement: make record-screen via HMI capture

`make record-screen` SHALL trigger on-device HMI screen recording until Ctrl+C or optional `DURATION=N`, optionally include ALSA audio with soft fallback to video-only when capture is busy, show a live host elapsed timer, pull the container plus `summary.txt` under `output/record-screen/rec-<stamp>/`, and update `rec-latest`. Ctrl+C after a successful save SHALL exit 0 from the host entrypoint.

#### Scenario: Record until interrupt

- **WHEN** the operator runs `make record-screen`, waits, then presses Ctrl+C
- **THEN** remote recording stops, the artifact is pulled to `output/record-screen/`, and the host command exits 0

#### Scenario: ALSA busy soft-fallback

- **WHEN** ALSA capture cannot be opened and `AUDIO_STRICT` is not enabled
- **THEN** recording SHALL continue video-only and note the fallback in `summary.txt` or host logs

### Requirement: GStreamer MPP/RGA encode

Stills SHALL be encoded with rootfs GStreamer using `mppjpegenc` when present (fixqp or documented equivalent). Video SHALL prefer Rockchip MPP H.264 encode when the tip provides a working encoder element; otherwise a documented MJPEG/MPP still-sequence container MAY be used. RGA SHALL be used for format convert/scale when the rockchip GStreamer plugin is built with RGA enabled.

#### Scenario: Encode elements present

- **WHEN** the on-device capture path is configured for the product GStreamer tip
- **THEN** encode elements SHALL be the locked product choice (`mppjpegenc`, `mpph264enc`+`mp4mux`, RGA via rockchipmpp) as documented in design/spike notes

### Requirement: Host control plane and cleanup

The host workflow SHALL trigger capture over the existing SSH/device-selection path (command file under `/run/hmi/` or an equivalent documented watcher), pull artifacts from a documented on-device directory, and remove remote staging after a successful pull (or on failure after a documented best-effort cleanup).

#### Scenario: Remote staging cleaned

- **WHEN** screenshot or record-screen completes successfully
- **THEN** the ephemeral remote capture staging directory used for that run is absent or empty afterward

### Requirement: Debug docs and single toolchain

`make screenshot` and `make record-screen` SHALL remain listed under the Makefile Debug help group. Documentation (`README` Make-commands material, `docs/make-commands.md`, AGENTS rebuild guidance) SHALL describe the HMI+GStreamer path and SHALL NOT instruct operators to run `make build-ffmpeg-device` for capture.

#### Scenario: Help text points at HMI capture

- **WHEN** an operator runs `make help` and reads the Debug capture lines
- **THEN** the descriptions match HMI/GStreamer capture (not ephemeral ffmpeg build)

### Requirement: OS Settings seat honors host capture

When the OS Settings App is the active Flutter seat (owns the running `flutter-wayland-client` with the present-hook), it SHALL initialize `cyber_capture` and honor the same host command dialect as product HMI Apps (`/run/hmi/capture.cmd`: `screenshot`, `record-start`, `record-stop`, `cleanup`). Host `make screenshot` / `make record-screen` SHALL work without a separate cmd path or Make target for the Settings seat.

#### Scenario: Screenshot while on OS Settings seat

- **WHEN** `os-settings.service` is running the Settings App and the operator runs `make screenshot`
- **THEN** a still is produced via present-hook encode and pulled to `output/screenshot/` as for the HMI seat

#### Scenario: Record while on OS Settings seat

- **WHEN** `os-settings.service` is running the Settings App and the operator runs `make record-screen` then stops
- **THEN** recording finalizes and the artifact is pulled to `output/record-screen/` with host exit 0 on Ctrl+C after a successful save
