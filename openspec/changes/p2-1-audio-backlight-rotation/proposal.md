## Why

P2 closed Modbus/GPIO on Linux, but **speaker, backlight, and display orientation** are still unverified on ynh960. Those peripherals were deferred to later phases; P2 hardware bring-up showed I/O mismatches early, so **P2.1** pulls platform I/O forward. This change delivers the first P2.1 slice — **喇叭 / 背光 / 旋转** — with reusable Dart modules and a demo UI that exercises them before Wi‑Fi / BT / IPC work.

## What Changes

- Add reusable **platform audio** module (play / stop / volume percent) with a Linux ALSA-backed implementation; ship `shanghai_tan.mp3` (from lws-ui `res/raw/shanghai_tan.mp3`) as a Flutter asset for speaker smoke.
- Add reusable **platform backlight** module (get / set brightness percent) via Linux backlight sysfs (later Android can plug settings API behind the same interface).
- Add reusable **platform display orientation** module (portrait / landscape) that persists preference and drives flutter-pi `-o` (and App/Material layout) so P5 product orientation can reuse the same contract.
- Extend the **P2 demo** with: Play/Stop music button (shanghai tan), volume slider, brightness slider, and Portrait / Landscape mutual-exclusive controls.
- Enable **minimal ALSA / audio userland** in Buildroot/rootfs as needed for decode + volume on device (not full GStreamer product stack).
- Update plan §12 P2.1 checklist items for audio / backlight / orientation as this change lands (Wi‑Fi / BT / IPC remain out of scope here).

## Capabilities

### New Capabilities

- `linux-media-audio`: Linux media playback + 0–100% volume control (ALSA path); abstract Dart API for later product sounds / settings.
- `linux-backlight`: Linux backlight brightness get/set as 0–100% over sysfs; abstract Dart API for later Settings UI.
- `linux-display-orientation`: Persist and apply portrait vs landscape for flutter-pi on ynh960; abstract Dart API for later product orientation.

### Modified Capabilities

- `p2-device-demo-ui`: Home demo gains audio play control, volume slider, brightness slider, and portrait/landscape button group wired to the new platform modules.
- `flutter-hello-world-app`: Bundle includes the shanghai tan audio asset; default boot orientation remains landscape, but orientation may be changed via the platform module (persisted across `hmi` restarts).
- `buildroot-lws-hmi-image`: Rootfs includes minimal ALSA tooling / libraries required for Linux media playback and mixer volume on ynh960.

## Impact

- **App** (`app/hmi/`): new `lib/platform/{audio,backlight,display}/` (or equivalent) modules; demo UI sections; `pubspec` assets + any Linux-capable audio dependency; unit tests for percent mapping / orientation enum.
- **Asset**: copy `shanghai_tan.mp3` (~7.7 MB) from lws-ui into `app/hmi/assets/audio/` (product can trim later; P2.1 uses as-is for parity with the Android test track).
- **Rootfs / Buildroot**: ALSA utils / libs; `hmi.service` / `hmi-launch.sh` read persisted orientation for flutter-pi `-o`; backlight sysfs permissions for HMI process.
- **Docs**: P2.1 checklist progress in `docs/flutter-pi-hmi-plan.md` for the three items this change covers.
- **Non-goals**: Wi‑Fi / BT / IPC eth0; MediaMTX / Flutter video; FrostUI settings pages; Android dual-target (P2.5 plugs alternate backends behind the same abstractions).
