## Why

Ephemeral `ffmpeg` + `kmsgrab` Debug capture (`on-demand-ffmpeg-screen-capture`, archived **failed**) cannot faithfully record Flutter’s VFR ~30Hz UI on ynh960: DRM queue drain, soft-encode contention with Weston/Flutter, and invented CFR timelines produced sped-up openings and choppy motion. Operators still need reliable **screenshot** and **screen-record** (optional ALSA) for bugs/demos. The product already ships GStreamer + Rockchip MPP/RGA; capture should use **one** path: Flutter/eLinux surface readback paced by the UI, encoded with GStreamer (VPU/RGA where available), with host Make only triggering and pulling artifacts.

## What Changes

- Add a reusable **`packages/cyber_capture`** (name may be finalized in design) shared by **all product HMI apps** (`*_hmi`, not only `lws_hmi`): Dart API + FFI to **native C or Rust** async readback + GStreamer/MPP/RGA encode; Apps only wire a thin command watcher / lifecycle.
- Native capture+encode lives with the package (or `native/` + package FFI), installable once on rootfs (e.g. `/usr/libexec/hmi/` or `/usr/lib/`) so every HMI that depends on `cyber_capture` reuses the same binary — **no per-app fork** of capture logic.
- Encode stills and video with **rootfs GStreamer** (`mppjpegenc` / MPP H.264 or documented fallback), using RGA for format/scale when available — same multimedia stack as preview and `extract-video-frame`.
- Host **`make screenshot`** / **`make record-screen`** (and docs) **redirect** to this path: SSH command file or socket to the **running** HMI (whichever App owns `/opt/hmi`), then pull from a known on-device dir — same operator UX, new backend.
- **BREAKING (Debug tooling):** **delete** the ephemeral aarch64 ffmpeg / `kmsgrab` implementation when this change lands (or earlier with Make stubs). Do not leave a parallel runnable ffmpeg capture route. Files include `scripts/build-ffmpeg-device.sh`, `scripts/ffmpeg-device-common.sh`, `scripts/screenshot.sh`, `scripts/record-screen.sh`, `scripts/record-screen-host.sh`, and `overlay/third-party/ffmpeg.version` if unused elsewhere.
- Keep product policy: **do not** ship `/opt/hmi/bin/ffmpeg` for capture; do not re-enable Weston demo screenshooter solely for this.

## Capabilities

### New Capabilities

- `hmi-screen-capture`: Board + host contracts for HMI-driven screenshot and screen recording via shared **`cyber_capture`** (Flutter-paced frames, C/Rust + GStreamer/MPP/RGA, host Make trigger/pull, reusable across product HMI apps).

### Modified Capabilities

- (none in main `openspec/specs/` — prior ffmpeg host-capture delta was archived with `--skip-specs` and must not be promoted)

## Impact

- **Package:** new `packages/cyber_capture/` (Dart public API + FFI; host `dart test` / `flutter test` as applicable) — peer to `cyber_hal` / `cyber_pm`; every `_hmi` App may depend on it.
- **App:** thin integration only (command watcher under `/run/hmi/`, package init); first consumer `app/lws_hmi`, pattern copyable to `cnc_hmi` / future products without reimplementing capture.
- **Native / overlay:** prefer **C** (match `native/extract_video_frame`) or **Rust** for readback + GStreamer `appsrc`; ship shared libexec/`.so` once via overlay/`make build-libexec-binaries` (or package-owned native build), not duplicated per App bundle.
- **Rootfs:** already requires GStreamer + `rockchipmpp` / RGA; may need encode elements verified — Buildroot only if spike shows missing plugins.
- **Host:** Makefile Debug targets, docs, AGENTS; remove ffmpeg-device scripts.
- **Audio:** ALSA optional soft-fallback.
- **Predecessor:** `openspec/changes/archive/2026-08-13-on-demand-ffmpeg-screen-capture/` (`ABANDONED.md`).
- **Note:** Rust here is a **capture helper library**, not a return of Rust `hald` Platform API (still out of scope).
