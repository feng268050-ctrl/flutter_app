## Why

Operators need a repeatable host path to grab device UI screenshots and short screen recordings (with audio) for bug reports and demos. Product rootfs deliberately does **not** ship ffmpeg (covers/AI samples use GStreamer), and Weston demo clients (including screenshooter) are disabled — so capture must be a **Debug host workflow**: on-demand aarch64 ffmpeg, ephemeral upload like `make audit`, artifacts pulled to `output/`.

## What Changes

- Add **on-demand aarch64 ffmpeg** for device screen capture: cross-compile (or rebuild when forced) a board-oriented ffmpeg binary cached under `.cache/` — **not** packaged into product rootfs / HMI bundle.
- Add **`make screenshot`**: SSH to the selected device, stage ffmpeg under `/tmp`, capture one still from the live Weston/DRM session, pull PNG/JPEG to `output/screenshot/`, then remove the staged binary (and remote temp frames).
- Add **`make record-screen`**: same staging model; record video **with audio** for a configurable duration (or until interrupt), show a **live elapsed-duration** status line on the host TTY while recording, pull the file to `output/record-screen/`, then clean up remote staging.
- Wire both targets into the Makefile **Debug** help group; document in README / `docs/make-commands.md` / AGENTS rebuild notes (host-only; no firmware rebuild).
- Reuse existing device selection (`SN=` / `IP=` / USB-SSH session helpers), same as `make audit` / `make push-app`.

## Capabilities

### New Capabilities

- `host-device-screen-capture`: Host Make workflows for live-board screenshot and screen recording with audio via on-demand (cached) aarch64 ffmpeg staged ephemerally over SSH; artifact layout under `output/screenshot/` and `output/record-screen/`; ffmpeg never installed in product rootfs.

### Modified Capabilities

- (none) — no product rootfs/kernel requirement changes; capture is host-driven against a reachable board.

## Impact

- **Makefile / docs:** `screenshot`, `record-screen` (+ optional `build-ffmpeg-device` / ensure helper); Debug help lines; README / `docs/make-commands.md` / AGENTS.md.
- **Scripts:** new host scripts under `scripts/` (ffmpeg ensure/build + screenshot + record-screen), patterned on `scripts/audit-lynis.sh` / USB-SSH session helpers.
- **Host deps:** cross toolchain via existing Docker/`linux-sdk` (or documented static build path); board must already expose DRM/KMS + ALSA usable by the staged ffmpeg.
- **Artifacts:** `output/screenshot/`, `output/record-screen/` only; `.cache/ffmpeg-device/` (gitignored).
- **Non-goals:** baking ffmpeg into rootfs or `/opt/hmi/bin`; product in-app screen recorder; restoring Weston demo clients solely for capture.
