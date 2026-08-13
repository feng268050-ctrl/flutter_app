## Context

ynh960 runs Weston (DRM) + Flutter eLinux; panel is physical portrait with `transform=rotate-270` for logical landscape. Product policy already forbids shipping `/opt/hmi/bin/ffmpeg` (GStreamer covers/AI samples). Weston demo clients (screenshooter) are **off** in `lws_hmi_wayland.config`. Operators still need Debug-only screenshot / screen-record-with-audio for bugs and demos.

Existing patterns to mirror:

- **Ephemeral tool upload:** `make audit` → `scripts/audit-lynis.sh` (stage under `/tmp`, pull `output/audit/`, delete remote).
- **Temp ffmpeg push (remux only):** `scripts/measure-ip-camera-rtsp-ssh.sh` uses a pre-downloaded static binary at `.cache/ffmpeg-android/ffmpeg` — **insufficient** alone for DRM grab + ALSA (johnvansickle builds vary; not a first-class Make Debug target).
- **Cross-compile host helpers:** `scripts/build-umtprd.sh` (SDK/Docker aarch64 gcc, pin via `overlay/third-party/*.version`).

## Goals / Non-Goals

**Goals:**

- On-demand **compile** (cached) an aarch64 ffmpeg suitable for device DRM stills + A/V recording; never bake into product rootfs.
- `make screenshot` and `make record-screen` in the **Debug** help group; device selection via `SN=` / `IP=` / USB-SSH helpers.
- Pull artifacts automatically to `output/screenshot/` and `output/record-screen/` (stamped dirs + `*-latest` symlinks, same spirit as `output/audit/`).
- Document usage in Makefile help, README Make commands, `docs/make-commands.md`, and AGENTS rebuild table (host-only → **none** for firmware).

**Non-Goals:**

- Product in-app recorder / Settings UI.
- Restoring `BR2_PACKAGE_WESTON_*_CLIENTS` solely for capture.
- Replacing GStreamer frame-extract or reintroducing HMI-bundled ffmpeg.
- Guaranteeing bit-perfect speaker “what you hear” loopback on every codec (ALSA monitor may be board-specific; mic/default capture is an allowed fallback with docs).
- Emulator (`sim_virt`) first-class support in v1 (nice-to-have if DRM/ALSA exist; not a gate).

## Decisions

### D1 — Ephemeral stage like `make audit` (not rootfs)

**Choice:** Host ensures a board ffmpeg binary, SCP to `/tmp/lws-screen-capture/ffmpeg` (or similar), run capture, SCP results back, `rm -rf` remote staging on EXIT trap. Product defconfig stays free of `BR2_PACKAGE_FFMPEG`.

**Alternatives:** (a) Bake ffmpeg into rootfs — rejected (size, CVE, contradicts GStreamer cutover). (b) Rely on host-side capture — impossible for physical panel content. (c) Enable weston-screenshooter only — no audio path for record-screen.

### D2 — On-demand **compile** ffmpeg (not only download static)

**Choice:** Add `scripts/build-ffmpeg-device.sh` (+ thin `make build-ffmpeg-device`) that cross-compiles a **mostly-static** aarch64 `ffmpeg` with at least:

- demux/devices: `kmsgrab` (libdrm), `alsa`
- encoders: PNG/MJPEG or libx264 (or mpeg4 if x264 static is painful), AAC or PCM-in-MP4
- filters: `transpose` / `rotate` / `format` / `hwdownload` as needed for DRM frames

Pin source via `overlay/third-party/ffmpeg.version`. Cache build tree under `.cache/ffmpeg-device/`; install binary to `.cache/ffmpeg-device/ffmpeg` (gitignored). `screenshot` / `record-screen` call an `ensure_ffmpeg_device` that builds if missing (`FORCE=1` rebuilds). macOS: build inside existing `docker-run` / builder image with SDK toolchain (same class as `build-umtprd`).

**Alternatives:** (a) Only johnvansickle static — rejected as primary (“按需编译”); may remain optional `FFMPEG_HOST=` override for emergency. (b) Buildroot package into staging and copy out — heavier lunch coupling; optional later if cross recipe is too fragile.

### D3 — Capture video from DRM via `kmsgrab`

**Choice:** Primary video input is ffmpeg `kmsgrab` against the active DRM device (default `/dev/dri/card0`, override `DRM_DEVICE=`). Run as root over existing SSH (already root). Apply a **post-rotate filter** so files match logical landscape UI (default derived from ynh960 `rotate-270`; override `ROTATE=` / `TRANSPOSE=`).

**Alternatives:** (a) `/dev/fb0` dump — unreliable under pure DRM. (b) Wayland screencopy protocol client — would require another staged binary + compositor support work. (c) GStreamer on-device pipelines — already on rootfs but user asked for on-demand ffmpeg Make path.

### D4 — Audio via ALSA (`AUDIO_DEV=`)

**Choice:** `record-screen` adds an ALSA input (`-f alsa -i "${AUDIO_DEV}"`). Default: try documented board default (e.g. `default` or first capture PCM); allow `AUDIO_DEV=` and `AUDIO=0` to disable. Prefer a monitor/loopback PCM when present; otherwise capture the best available input and document limitation.

**Alternatives:** Pulse/PipeWire monitor — not the appliance audio stack. BlueZ A2DP tap — out of scope for v1.

### D5 — Make targets live under **Debug**

**Choice:**

```text
make screenshot          # still → output/screenshot/
make record-screen       # A/V → output/record-screen/  (DURATION= / AUDIO_DEV=)
make build-ffmpeg-device # optional explicit compile (also auto from ensure)
```

Help text under existing `Debug (device / host …)` block (not a new Audit-like section).

**Alternatives:** Separate “Capture:” help group — rejected; user asked for Debug group.

### D6 — Artifact layout under `output/`

**Choice:**

```text
output/screenshot/
  shot-<stamp>/
    screen.png          # or .jpg
    summary.txt         # SN/IP/stamp/ffmpeg version/DRM device
  shot-latest → …

output/record-screen/
  rec-<stamp>/
    screen.mp4          # or .mkv
    summary.txt
  rec-latest → …
```

Print the host path on success. Do not commit `output/`.

**Alternatives:** Flat files only under `output/` — rejected (collides across runs; audit already uses stamped dirs).

### D7 — Recording duration / stop + live elapsed UI

**Choice:** Default `DURATION=30` (seconds) passed to ffmpeg `-t`. `DURATION=0` means “until host Ctrl+C”: remote ffmpeg runs until interrupt; trap forwards SIGINT, then finalize/pull. Always pull whatever was written if the file is non-empty.

While recording, the **host** SHALL refresh a single TTY status line with live elapsed time (and remaining/total when `DURATION>0`), e.g. `Recording 00:12 / 00:30` or `Recording 00:12 (Ctrl+C to stop)`. Prefer a host wall-clock ticker while waiting on the SSH/ffmpeg session — do **not** rely solely on parsing remote ffmpeg `time=` (SSH buffering makes that flaky). Optional: also pass ffmpeg `-stats` / `-progress` for diagnostics in the log file, but the operator-facing timer is host-driven.

**Alternatives:** Interactive Enter-to-stop only — worse for automation. Fixed max only — rejected. Only echo ffmpeg stderr — rejected as primary UX (buffering / noisy).

### D8 — Shared script structure

**Choice:**

| Script | Role |
|--------|------|
| `scripts/build-ffmpeg-device.sh` | Cross-compile / install cached binary |
| `scripts/ffmpeg-device-common.sh` | `ensure`, SCP stage, remote run helpers, cleanup trap |
| `scripts/screenshot.sh` | Still capture + pull |
| `scripts/record-screen.sh` | A/V capture + pull |

Reuse `usb-ssh-session.sh` / device-target like audit.

### D9 — Docs / AGENTS

**Choice:** Update Makefile help, README Make-commands snippet, `docs/make-commands.md` entries, AGENTS rebuild table: host-only → exercise `make screenshot` / `make record-screen` (and `make build-ffmpeg-device` when recipe changes); **no** `apply-overlay` / rootfs.

## Risks / Trade-offs

- **[Risk] `kmsgrab` needs CAP_SYS_ADMIN / master DRM and may conflict with Weston briefly** → Mitigation: root SSH; document short frame freezes; prefer single-frame for screenshot; if grab fails, clear error with DRM path hints.
- **[Risk] Physical vs logical orientation wrong by default** → Mitigation: `ROTATE=` env; smoke on ynh960; store transform in `summary.txt`.
- **[Risk] No true speaker loopback on codec** → Mitigation: `AUDIO_DEV=` docs; `AUDIO=0` mute path; accept mic/default as fallback.
- **[Risk] Cross-compile ffmpeg slow / large on first use** → Mitigation: cache binary; stamp version; optional `FFMPEG_HOST=` override; print “building once…” message.
- **[Risk] Static linking libx264/libdrm painful** → Mitigation: prefer dynamic against board libs **only if** we stage matching `.so` next to ffmpeg under `/tmp/...` **or** use codecs already easy to static-link (MJPEG + PCM/AAC); prefer self-contained binary when feasible so we do not depend on rootfs ffmpeg libs (none today).
- **[Risk] Operators confuse with product ffmpeg ban** → Mitigation: comments + verify-rootfs still asserts no `/opt/hmi/bin/ffmpeg`; docs say Debug-only `/tmp` stage.

## Migration Plan

1. Land scripts + Make + docs (no board image change).
2. Operator: first run may invoke `build-ffmpeg-device` (Docker on macOS); subsequent runs reuse cache.
3. Rollback: delete Make targets/scripts; boards unchanged (no residual package).

## Open Questions

- Exact transpose filter for ynh960 `rotate-270` vs CRTC buffer orientation — resolve during first board smoke; bake default after one good capture.
- Whether libx264 static is worth the build complexity vs MJPEG-in-MKV for Debug quality — prefer H.264 if build stays reliable; else MJPEG with documented trade-off.
- Share binary with `measure-ip-camera-rtsp-ssh.sh` later (`FFMPEG_HOST` default) — optional follow-up; not required for this change.
