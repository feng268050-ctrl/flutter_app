# Abandoned — 2026-08-13

**Status:** FAILED / ABANDONED (do not implement further; do not sync delta specs to `openspec/specs/`).

## Why

On-device smoke with ephemeral aarch64 `ffmpeg` + `kmsgrab` (Weston/DRM) produced **unacceptable** screen recordings for this product:

- Flutter UI is **VFR** (~30Hz home-page motion); inventing CFR from DRM flips / queue drain caused **sped-up openings**, uneven pacing, then “stabilize” artifacts.
- Board encode path (MJPEG @ 1280×800) could not sustain true realtime 30fps without competing with Flutter/Weston for DRM/bandwidth → **choppy** playback even after wall-clock / warmup fixes.
- Soft-stop / Ctrl+C and ALSA exclusivity added operational friction; host remux stretch masked duration bugs without fixing motion quality.

Screenshot-only via the same ffmpeg path is also **superseded**: operators should use a **single** capture route (native Flutter surface readback + GStreamer/MPP/RGA), not a parallel Debug ffmpeg toolchain.

## Successor

See active change: **`flutter-native-screen-capture`** (`cyber_capture` + C/Rust + GStreamer/MPP/RGA; host Make pulls artifacts).

**Cleanup:** that change **deletes** unused ffmpeg-device scripts (`build-ffmpeg-device`, `ffmpeg-device-common`, screenshot/record-screen ffmpeg bodies, `ffmpeg.version` if unused) at cutover, or earlier with Make stubs — do not keep a runnable fork of this failed path.

## Archive note

Archived with `--skip-specs` so `host-device-screen-capture` is **not** promoted into main `openspec/specs/`.
