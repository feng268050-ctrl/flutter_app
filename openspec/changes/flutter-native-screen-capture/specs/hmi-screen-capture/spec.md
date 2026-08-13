## ADDED Requirements

### Requirement: Single HMI capture route for still and video

The project SHALL provide one on-device capture implementation for both screenshot and screen recording that obtains pixels from the Flutter/eLinux HMI surface (Flutter-paced), encodes with rootfs GStreamer using Rockchip MPP and RGA when available, and SHALL NOT rely on ephemeral host-built `ffmpeg` or DRM `kmsgrab` for these operator workflows. Continuous capture and encode logic SHALL be implemented in **native C or Rust** (Dart limited to control/watchers and FFI); a Dart-only `toImage` loop MUST NOT be the record path.

The implementation SHALL be packaged for reuse: a Dart package under `packages/` (canonical name **`cyber_capture`** unless spike renames it) plus shared native artifacts on rootfs, such that any product HMI app (`*_hmi`) can depend on the package without reimplementing capture or bundling a private ffmpeg/kmsgrab path.

#### Scenario: No parallel ffmpeg capture path

- **WHEN** an operator uses the supported Make screenshot or record-screen entrypoints after this change is implemented
- **THEN** the workflow SHALL NOT stage `.cache/ffmpeg-device/ffmpeg` or invoke `kmsgrab` for capture

#### Scenario: Native language for capture encode path

- **WHEN** implementers land the on-device capture helper or plugin for record (and the preferred still path)
- **THEN** the pixel readback and GStreamer pipeline SHALL be C or Rust (documented in tasks/spike notes), not a continuous Dart `RepaintBoundary.toImage` encoder

#### Scenario: Failed ffmpeg path removed

- **WHEN** this change is fully implemented (or earlier if Make targets are stubbed)
- **THEN** the repository SHALL NOT ship a runnable ephemeral-ffmpeg/`kmsgrab` screenshot or record-screen implementation; unused scripts from the abandoned path SHALL be deleted (not kept as a second toolchain)

### Requirement: Flutter-paced frame timing

Screen recording SHALL timestamp and accept frames according to Flutter/eLinux presentation timing (frame callback or equivalent). The system MUST NOT invent a capture timeline solely from DRM page-flip cadence or by draining a multi-second framebuffer queue into a compressed CFR timeline.

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

- **WHEN** implementers complete the on-device spike on the product GStreamer tip
- **THEN** they SHALL record in the change tasks or notes which encode elements were selected (`mppjpegenc`, H.264 enc name, or fallback) and that RGA convert/scale is available or explicitly waived

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
