## Why

P2.1 already ships USB HID **keyboard** on the 1 mm host (and OTG host when Debug over USB is off). A USB **mouse** enumerates on the same path and can scroll in Flutter, but **no on-screen pointer** appears — operators cannot see where the cursor is. Product-grade HMI also needs **OS-style mouse settings** (natural scroll, scroll speed, pointer speed, primary button) behind a reusable Dart abstraction, not ad-hoc Demo knobs.

## What Changes

- Prove wired **USB HID mouse** on the existing USB host paths (1 mm expansion; Micro-USB when Debug over USB is off): enum, pointer motion/buttons/wheel reach flutter-pi / Flutter.
- Make the **mouse pointer visible** under flutter-pi on ynh960 (fix or replace the broken DRM hardware cursor path with a reliable software/fallback path as needed).
- Add OS-shaped **`MouseSettingsController`** (Linux backend now; Android later) for common mouse prefs that the stack can actually apply — at minimum scroll direction / scroll speed / pointer speed (accel) / primary button, gated by what libinput + flutter-pi support after a short capability spike.
- Extend P2.1 Demo with a **Mouse** section: presence/status, pointer smoke, and setting controls wired to the controller (persist under `/var/lib/lws-hmi/` like other P2.1 prefs).
- Update plan §12 / I/O ledger / smoke notes when device validation lands.
- **Non-goals:** touchpad gestures / multi-touch pointer; Bluetooth mice; product Settings pages (P5.2); custom cursor themes beyond a default arrow; changing keyboard or OTG role design.

## Capabilities

### New Capabilities

- `linux-usb-hid-mouse`: USB HID mouse enumeration and pointer delivery into flutter-pi/libinput, including a **visible** on-screen pointer when a mouse is attached.
- `linux-mouse-settings`: OS-level mouse preference API (get/set + persist) for scroll direction, scroll speed, pointer speed, and primary button; Linux apply path via libinput / flutter-pi (whatever the spike proves works).

### Modified Capabilities

- `p2-device-demo-ui`: Demo home gains a USB mouse smoke + settings section (near keyboard).
- `buildroot-lws-hmi-image`: flutter-pi patches / prebuilt rebuild and any rootfs bits required for cursor + mouse pref apply.
- `linux-settings-persist`: Document mouse preference files under `/var/lib/lws-hmi/`; prefs MUST be re-applied when `hmi` / flutter-pi starts (no separate radio stack).

## Impact

- **flutter-pi / compositor**: Hardware DRM cursor (`drmModeMoveCursor` / cursor plane) is the current path and often fails on Rockchip (“cursor move Bad address” / silent no-cursor). Expect spike → patch or Flutter software-cursor fallback + `make rebuild-flutter-pi`.
- **App**: `lib/platform/input/` (or `mouse/`) abstract controller + Linux impl; Demo section; unit tests for mapping / persist tokens.
- **Rootfs**: Pref files; optional apply helper or flutter-pi launch hook; `verify-rootfs` if overlay scripts added.
- **Docs**: `docs/flutter-pi-hmi-plan.md` §12; `docs/ynh960-io-pinmux-ledger.md` (mouse on same host as keyboard); `app/hmi/README.md` smoke.
- **Bench**: USB mouse on 1 mm host and/or OTG host adapter.
