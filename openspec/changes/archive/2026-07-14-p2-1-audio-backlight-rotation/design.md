## Context

P2 delivered Modbus + GPIO demo on ynh960 (`app/hmi`, `/opt/hmi`, `hmi.service` → `flutter-pi --release -o landscape_left`). Plan **P2.1** now fronts board I/O; this change is the first slice: **喇叭 / 背光 / 屏幕旋转**.

lws-ui already has:

- Test track `app/src/main/res/raw/shanghai_tan.mp3` (~7.7 MB) used by `DevMusicRhythmPlayer`
- Volume percent via `MusicPlaybackVolume` (`STREAM_MUSIC`, 0–100)
- Brightness via `SystemSettingUtils` (Android 0–255)
- Settings UI sliders in Common Settings

Linux has no Android `AudioManager` / `Settings.System`. flutter-pi orientation is a **launch** flag (`-o`), not a Flutter `SystemChrome` guarantee. Modules must be **abstracted** so P5 Settings and P2.5 Android can swap backends without rewriting UI.

## Goals / Non-Goals

**Goals:**

- Reusable Dart platform APIs for media audio + volume, backlight brightness, and display orientation.
- Demo controls on the existing P2 home page that prove each path on hardware.
- Minimal rootfs ALSA (and decode helper) so the speaker path works without pulling the full P5 GStreamer product stack.
- Persist orientation across HMI restarts via `hmi-launch.sh` / flutter-pi `-o`.

**Non-Goals:**

- Wi‑Fi / BT / IPC camera (later P2.1 slices).
- Full product Settings pages, FrostUI, status bar.
- MediaMTX / RTSP preview.
- Android backends (interfaces only; P2.5 implements).
- Replacing LCD panel physical `lcd0_rotation` in boot params (App/flutter-pi orientation only).
- Perfect audio DSP / equalizer; smoke-level play + volume is enough.

## Decisions

### D1 — Package layout: `lib/platform/{audio,backlight,display}/`

**Choice:** New platform packages parallel to existing `lib/modbus/` and `lib/gpio/`:

```text
lib/platform/audio/
  media_audio_controller.dart      # abstract API
  linux_media_audio_controller.dart
lib/platform/backlight/
  backlight_controller.dart        # abstract API
  linux_sysfs_backlight.dart
lib/platform/display/
  display_orientation.dart         # enum + abstract API
  linux_flutter_pi_orientation.dart
```

Demo depends only on abstract types; inject Linux impls in `main` / page constructors (same pattern as `ModbusRtuClient` / `GpioLedController`).

**Why:** Clear reuse for P5 Settings; testable with fakes; matches P2 style.

**Alternatives:** Stuff logic into demo widgets (rejected); MethodChannel-only from day one (unnecessary on pure Linux).

### D2 — Audio: abstract controller + Linux ALSA-first backend

**API (normative for specs):**

- `Future<void> playAsset(String assetKey)` — demo uses `assets/audio/shanghai_tan.mp3`
- `Future<void> stop()`
- `Future<void> setVolumePercent(int percent)` — clamp 0–100
- `Future<int> getVolumePercent()`
- `Stream<MediaPlaybackState>` or simple `isPlaying` for button label (Play ↔ Stop)

**Linux implementation preference (apply-time spike, pick first that works on device):**

1. **Preferred:** Flutter audio plugin that runs on flutter-pi ARM64 Linux and plays Flutter assets (e.g. `audioplayers` / equivalent).
2. **Fallback:** Extract asset to a cache file under `/var/lib/hmi/audio/` (or adjacent to bundle) and play with rootfs tools (`mpg123` or `ffplay`/`gst-play-1.0` if already present), control volume via `amixer` Softvol / PCM when available, else player gain.

**Why:** UI and product code stay on `MediaAudioController`; hardware bring-up can swap ALSA details without API churn.

**Asset:** Copy lws-ui track as `app/hmi/assets/audio/shanghai_tan.mp3` (keep filename; note `shanghai_tan` not “shanghaitan”). Declare under `pubspec.yaml` `flutter: assets:`.

### D3 — Volume percent contract (align lws-ui)

**Choice:** Public API is **0–100%**, matching `MusicPlaybackVolume`. Linux maps to ALSA mixer integers or player gain internally.

**Why:** Demo slider and future Settings share one contract; Android STREAM_MUSIC percent already uses 0–100.

### D4 — Backlight: sysfs + 0–100% API

**Choice:** `BacklightController` with `getBrightnessPercent` / `setBrightnessPercent` (0–100).

Linux: discover first usable `/sys/class/backlight/*/brightness` (+ `max_brightness`). Map percent linearly to `[1, max_brightness]` (or board min if documented — LCD param `lcd0_backlight_min=10` may apply to vendor param path; prefer **sysfs max** as source of truth, optionally floor so 0% leaves a dim but non-black panel if hardware disappears at 0 — document chosen floor in code).

**Why:** Direct, matches Rockchip HMI practice; Android later maps Settings 0–255 ↔ same percent API.

**Alternatives:** Only write vendor `/system/etc` LCD param (rejected — not live); drm property (more complex, defer).

### D5 — Orientation: persist + relaunch flutter-pi `-o`

**Choice:**

| App concept | flutter-pi `-o` (ynh960 default today) |
|-------------|----------------------------------------|
| `landscape` | `landscape_left` (current production default) |
| `portrait`  | `portrait_up` |

1. Persist choice under **`/var/lib/hmi/display-orientation`** (single line: `landscape` \| `portrait`; default `landscape` if missing).
2. `hmi-launch.sh` reads the file and passes the mapped `-o` (replace hardcoded `landscape_left`).
3. Demo Portrait / Landscape buttons: write preference → request HMI restart (`systemctl restart hmi` via a small privileged helper or existing restart script pattern used by push-app).

**Why:** flutter-pi orientation is a process launch concern; only relaunch tests the real graphics/input stack. Fake `Transform.rotate` would not catch DRM/input issues.

**Alternatives considered:**

- Flutter `SystemChrome.setPreferredOrientations` only — unreliable on flutter-pi.
- Change `lcd0_rotation` in LCD params — boot/display firmware concern, not App demo.

**UX note:** Restart drops App state (Modbus session, LED modes). Acceptable for bring-up demo; document in UI with a short “Applying…” / toast if feasible.

### D6 — Demo UI: additive sections on P2 page

**Choice:** Keep existing Device Info / Alarm temps / LED rows. Append:

1. **Audio** — Play/Stop (or Play while idle / Stop while playing) for `shanghai_tan.mp3`; Volume slider 0–100
2. **Backlight** — Brightness slider 0–100 (initialize from current sysfs)
3. **Orientation** — exclusive Portrait / Landscape button group (same exclusivity pattern as LED modes)

Do not block first frame on audio engine / backlight open (post-frame init, same as Modbus).

### D7 — Buildroot / permissions

**Choice:** Add a small P2.1 audio fragment (or uncomment minimal ALSA packages) so rootfs has:

- ALSA libs + `amixer` / `aplay` (and decode player chosen in D2)
- HMI process access to backlight sysfs and audio devices (udev/group or root `hmi.service` as today)

Do **not** enable full `lws_hmi_gst_rtsp` solely for this smoke unless the spike proves it is the lightest path already staged.

### D8 — First-frame / KPI

Audio decode, ALSA open, and backlight sysfs reads run **after first frame**. Failures show degraded UI (slider still visible; play no-ops with log) without crashing — same resilience as Modbus `-`.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Flutter audio plugins fail on flutter-pi Linux | Fallback Process + mpg123/ffplay path behind same controller |
| Speaker amp GPIO muted until enabled | Spike on device; document / wire amp enable in Linux controller if needed |
| Orientation restart kills demo state | Accept for P2.1; product may later apply orientation only at boot |
| 7.7 MB mp3 bloats `/opt/hmi` | Accept for parity; later replace with short clip or stream from `/oem` |
| Backlight path name unknown until device | Auto-discover first backlight device; log chosen path |
| ALSA control name differs per codec | Probe common controls (`Master`, `PCM`, `Speaker`); document on device |

## Migration Plan

1. Land platform modules + demo UI + asset; unit-test percent clamps and orientation mapping on host.
2. Enable ALSA fragment; `apply-overlay` → rebuild rootfs/img as needed; update `hmi-launch.sh`.
3. Device smoke: play shanghai tan, sweep volume, sweep brightness, toggle portrait/landscape (verify after restart).
4. Mark plan §12 P2.1 checklist items for audio / backlight / orientation when smoke passes.

Rollback: revert App to P2-only demo; restore hardcoded `-o landscape_left`; leave ALSA packages installed (harmless) or revert defconfig fragment.

## Open Questions

1. Exact `/sys/class/backlight/<name>` on ynh960 — resolve during apply smoke.
2. Exact ALSA card/control + whether amp GPIO is required — resolve during apply smoke.
3. Preferred decode binary if plugin path fails (`mpg123` vs `gst-play-1.0` already in deps) — decide in D2 spike and record in tasks notes.
