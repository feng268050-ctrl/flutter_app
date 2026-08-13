## Context

ynh960 runs Weston (DRM) + Flutter eLinux (`flutter-wayland-client`) at logical **1280×800** (panel 800×1280 + `rotate-270`). UI motion (e.g. home WebP) is **Flutter-paced VFR**, often ~30Hz when animating.

The Debug path in archived `2026-08-13-on-demand-ffmpeg-screen-capture` staged ephemeral aarch64 `ffmpeg` and used **`kmsgrab`**. Field results were poor: backlog drain → fast-forward openings, soft MJPEG unable to hold smooth 30Hz beside live HMI, Ctrl+C/ALSA friction. That change is **abandoned** (`ABANDONED.md`); its delta spec must not land in main specs.

Product already has **GStreamer ≥ 1.28.5**, **rockchipmpp**, **RGA-enabled** `gstreamer1-rockchip`, and `mppjpegenc` (used by `extract-video-frame`). Policy forbids shipping App-bundled ffmpeg for media; capture should reuse this stack.

Operators still want `make screenshot` / `make record-screen` pulling into `output/screenshot/` and `output/record-screen/`.

## Goals / Non-Goals

**Goals:**

- **Single capture route** for still + video, shipped as reusable **`packages/cyber_capture`** (Dart + C/Rust FFI) for **all** product HMI apps (`*_hmi`), not `lws_hmi`-only.
- Flutter/eLinux surface → async readback → GStreamer encode (MPP JPEG / H.264 + RGA when available).
- Frame **timing follows Flutter** (vsync / frame callback), not DRM page-flip invention.
- Host Make remains the operator entry (trigger + pull + clean remote staging); artifacts stay under `output/…`.
- Soft-fallback for busy ALSA; video-only still succeeds.
- Retire ffmpeg-device Debug toolchain so there is not a second “almost works” path.

**Non-Goals:**

- Product Settings UI “screen recorder” for end customers (Debug/host-triggered is enough for this change).
- Re-enabling Weston screenshooter demos.
- Shipping `/opt/hmi/bin/ffmpeg` again.
- Bit-perfect capture of non-Flutter surfaces (other Wayland clients, system cursor chrome outside the Flutter surface) — HMI content is the acceptance surface.
- Guaranteeing full-res 30fps with zero UI impact on RK3566 under all load; acceptance allows documented scale/FPS caps with smooth realtime playback.
- Reviving Rust **`hald`** / Platform API — optional Rust is only for the **capture** native library if chosen over C.

## Decisions

### D0 — Abstract as `packages/cyber_capture` (multi-app)

- New Dart package **`cyber_capture`** under `packages/` (peer to `cyber_hal` / `cyber_pm`): public API for screenshot / record-start / record-stop / status; FFI to shared native.
- **Native once:** C (default) or Rust library/helper installed to rootfs (`/usr/libexec/hmi/` and/or `/usr/lib/`); Apps do **not** each vendor a copy of encode logic.
- **App role:** depend on `cyber_capture`, call `CyberCapture.ensureStarted()` (name TBD) from main / debug bootstrap, optionally customize output dir / rotate; first integration `app/lws_hmi`, same pattern for `cnc_hmi` / future `_hmi`.
- Host Make talks to **whichever App is at `/opt/hmi`** via `/run/hmi/capture.cmd` — package owns the watcher helper so Apps share one command dialect.

**Alternatives:**

| Option | Verdict |
|--------|---------|
| Logic only inside `app/lws_hmi` | Rejected — other HMIs would reimplement |
| Put capture inside `cyber_hal` | Rejected — HAL is platform I/O; capture is multimedia/debug UX; keep packages focused |
| Per-App bundled `.so` in `/opt/hmi` | Rejected — duplicates native + gst linkage; prefer rootfs libexec shared |

### D1 — One pipeline for screenshot and record

Screenshot = one Flutter-paced frame → `mppjpegenc` (or equivalent) → PNG/JPEG file.  
Record = continuous frames + optional ALSA → Matroska/MP4 via MPP H.264 (preferred) or MJPEG if H.264 enc missing → same staging dir layout.

**Alternative:** keep ffmpeg for stills only — **rejected** (two toolchains; stills also suffer DRM/orientation duplication).

### D2 — Flutter-paced producer, GStreamer consumer (native = C++ hook + C encode)

- Dart registers control only (command watcher / FFI); pixel path lives in native.
- **Embedder patch in C++** (`SurfaceGl` present-hook) — matches `flutter-wayland-client` / eLinux tree language.
- **Encode library in C** (`libhmi_capture.so`, like `extract-video-frame`): async readback ring, `appsrc`, GStreamer/MPP. Optional Rust only if packaging clearly wins (not chosen).
- Do **not** implement continuous record as a Dart `RepaintBoundary.toImage` loop.
- C++ only as thin glue to the embedder present path; new encode logic stays C where practical.

**Alternatives:**

| Option | Verdict |
|--------|---------|
| Pure Dart `toImage` @30fps full-res | Rejected for record — stalls raster; OK only as last-resort still at reduced `pixelRatio` during spike |
| New capture daemon in C++ | Discouraged — prefer C/Rust; C++ only as thin glue to embedder |
| `kmsgrab` + GStreamer | Rejected — same DRM timing failure mode as ffmpeg |
| Host-only capture | Rejected — cannot see Flutter frame clock |

### D3 — Control plane: command file (parity with other host helpers)

Host writes e.g. `/run/hmi/capture.cmd` (`screenshot`, `record-start`, `record-stop`). The **`cyber_capture`** package registers the watcher so any HMI that initializes the package honors the same protocol. Artifacts under `/var/lib/hmi/capture/<stamp>/` (or `/tmp/…`); host `scp`s out and deletes remote tree.

**Alternative:** long-lived TCP debug port — deferred (more attack surface; SSH already exists).

### D4 — Encode defaults

- Still: landscape 1280×800 JPEG via `mppjpegenc` (`rc-mode=fixqp`), quality knob env.
- Video: target **30fps CFR output** with timestamps from Flutter frame time (or monotonic clock at submit); if encode cannot keep up, **drop frames** but **never compress wall timeline** (no “fast then stable”).
- Optional `SCALE=` / `FPS=` for constrained boards; document recommended defaults after spike.
- Orientation: apply the same logical landscape policy as today’s operators expect (compose in landscape or metadata + host note).

### D5 — Delete failed ffmpeg Debug toolchain (now or at cutover)

The abandoned `kmsgrab`/ephemeral-ffmpeg path MUST NOT remain as a usable operator route after this change lands. Implementers SHALL **delete** (not merely ignore) unused failed-path artifacts, either:

- **At cutover** (preferred default in tasks §3): when `cyber_capture` Make targets work; or
- **Earlier**: delete immediately and stub `make screenshot` / `make record-screen` / `make build-ffmpeg-device` to fail with a one-line pointer to `flutter-native-screen-capture` so nobody keeps using the bad path.

Remove at least:

- `scripts/build-ffmpeg-device.sh`, `scripts/ffmpeg-device-common.sh`
- `scripts/screenshot.sh`, `scripts/record-screen.sh`, `scripts/record-screen-host.sh` (replace with HMI/`cyber_capture` implementations, do not leave ffmpeg bodies)
- `overlay/third-party/ffmpeg.version` if nothing else references it
- Makefile help / `docs/make-commands.md` / README / `AGENTS.md` rows that instruct `make build-ffmpeg-device` for capture

Leave archive `ABANDONED.md` as the historical record; do not keep a “deprecated but runnable” ffmpeg capture fork in-tree.

### D6 — Spike gate before full App wiring

On-device spike must prove: (1) Flutter/eLinux can export a buffer per frame without multi-second UI freeze; (2) `gst-inspect` shows needed enc elements; (3) 10s record of home motion plays at realtime with no sped-up open. Only then implement Make + watcher.

## Risks / Trade-offs

- **[Risk] eLinux has no public “readback” API** → Mitigation: spike MethodChannel/FFI into embedder from **C or Rust**; fallback reduced-rate `toImage` for stills only; record may need embedder patch (track as explicit task).
- **[Risk] MPP H.264 encoder absent or flaky on RK3566 tip** → Mitigation: spike `gst-inspect`; fallback MJPEG/`mppjpegenc` sequence in MKV; accept larger files.
- **[Risk] Readback + encode steals GPU/CPU from HMI** → Mitigation: async readback, drop-when-behind, optional scale; Debug-only trigger so field units idle until used.
- **[Risk] ALSA exclusive capture (HMI)** → Mitigation: video-only fallback; document `AUDIO=0`.
- **[Risk] Operators cling to old ffmpeg Make flags** → Mitigation: Makefile prints migration one-liner; fail fast if old cache-only path invoked.

## Migration Plan

1. Archive note already landed for ffmpeg change (`2026-08-13-on-demand-ffmpeg-screen-capture`).
2. Spike readback + GStreamer on ynh960; lock pipeline strings and FPS/scale defaults.
3. Implement `packages/cyber_capture` + native helper; wire `app/lws_hmi`; document how other `_hmi` Apps depend on the package.
4. Point `make screenshot` / `record-screen` at new control plane; smoke still + 30Hz home motion record.
5. Delete ffmpeg-device scripts and doc references; update AGENTS rebuild table (include `packages/cyber_capture` row).

Rollback: restore previous host scripts from git if needed; board without new App simply cannot capture (no silent ffmpeg fallback).

## Open Questions

_(Resolved in Spike notes — embedder patch **C++**; encode lib **C**; `mpph264enc`+`mp4mux`; `/var/lib/hmi/capture/`.)_

## Spike notes (ynh960 / tip)

**Date:** 2026-08-13 · **SN:** L1SZ2026070001 · **GStreamer:** 1.28.5 · **rockchipmpp plugin:** 1.14.4

### 1.1 Encode inventory (`gst-inspect-1.0`)

| Element | Status | Role |
|---------|--------|------|
| `mppjpegenc` | PRESENT | Still JPEG (`rc-mode=fixqp`, `q-factor=80` default) |
| `mpph264enc` | PRESENT | Video H.264 (preferred) |
| `mpph265enc` | PRESENT | Not used for Debug v1 |
| `jpegenc` / `x264enc` | MISSING | Soft encoders absent (harden) — do not require |
| `rgaconvert` / `rgageometry` | MISSING | No standalone RGA elements |
| RGA inside `libgstrockchipmpp.so` | YES | `c_RkRgaBlit`, `gst_mpp_rga_do_convert`; disable via `GST_MPP_NO_RGA` |
| `videoconvert` / `videoscale` / `appsrc` / `appsink` | PRESENT | CPU convert path + appsrc feed |
| `mp4mux` / `qtmux` | PRESENT | Container |
| `matroskamux` | MISSING | Do **not** use Matroska on tip |
| `videoflip` | MISSING | Orientation via RGBA transpose in helper or `ROTATE=0` (Flutter already logical landscape) |
| `alsasrc` | PRESENT | Optional record audio; soft-fallback when busy |
| AAC/Opus enc | MISSING | Video-only or raw/PCM-in-MP4 if audio added later |

**Locked still pipeline:**

```text
appsrc name=src is-live=true format=time !
video/x-raw,format=RGBA,width=W,height=H,framerate=1/1 !
videoconvert ! video/x-raw,format=NV12 !
mppjpegenc rc-mode=fixqp q-factor=80 ! filesink location=screen.jpg
```

**Locked video pipeline (preferred):**

```text
appsrc name=src is-live=true format=time do-timestamp=false !
video/x-raw,format=RGBA,width=W,height=H,framerate=FPS/1 !
videoconvert ! video/x-raw,format=NV12 !
mpph264enc rc-mode=fixqp ! h264parse ! mp4mux name=mux ! filesink location=screen.mp4
# optional: alsasrc ! audioconvert ! audioresample ! queue ! mux.
```

(Timestamps set on each `GstBuffer` from Flutter/submit monotonic time — drop when behind; never invent a compressed wall timeline.)

**Defaults after spike intent:** `FPS=30`, full logical `1280×800`, `SCALE=1` (operator may set `SCALE=0.5` / `FPS=15` under load). Container = **MP4** (not MKV). Staging = **`/var/lib/hmi/capture/<stamp>/`**.

### 1.2 / 1.3 Readback + language (resolved — approach A)

- **Language (split for consistency):**
  - **Embedder present-hook patch:** **C++** — `flutter-wayland-client` / `surface_gl.cc` are C++; vendored overlay patch stays C++ (same style as upstream Sony/eLinux tree). Do **not** rewrite the hook as a `.c` file bolted onto the client.
  - **Encode + control library:** **C** — `native/hmi_capture/hmi_capture.c` → `libhmi_capture.so` (same class as `extract-video-frame`); C ABI + `extern "C"` for Dart FFI and `dlopen` from the C++ client.
- **eLinux public API:** none for screenshot. Continuous DRM/`kmsgrab` rejected.
- **Producer (locked):** patch `SurfaceGl::GLContextPresent*` (C++) to `dlopen`/`dlsym` `hmi_capture_on_present` **before** `eglSwapBuffers`; C lib does `glReadPixels` into a drop-when-behind ring; encode thread feeds GStreamer `appsrc` → `mppjpegenc` / `mpph264enc`. Dart is control/watcher/FFI only — **no** `toImage` record loop.
- **Orientation:** `flutter-wayland-client --fullscreen` + Weston `rotate-270`; buffer is logical landscape → default `ROTATE=0`.
- **Open Questions resolved:** hook = present-hook (C++ patch + C lib); video = `mpph264enc`+`mp4mux`; staging = `/var/lib/hmi/capture/<stamp>/`.
- **On-device smoke (2026-08-13):** still `1280×800` JPEG OK; continuous record with home motion ≈54s wall → **54.4s** playback (1632 frames @30, drops=0) — **accept FPS=30 / SCALE=100**. PTS use monotonic submit time (not frame-count CFR) so idle UI does not compress wall timeline.
