## 1. Device spike (cursor + libinput)

- [x] 1.1 On ynh960, plug USB mouse (1 mm host and/or OTG host); capture `lsusb`, `/dev/input/by-id`, `libinput list-devices`, and flutter-pi stderr for `drmModeMoveCursor` / cursor buffer errors
- [x] 1.2 Record which libinput config APIs are available on the device (natural scroll, accel, left-handed) and note any flutter-pi hardcodes for wheel scale
- [x] 1.3 Decide cursor strategy from spike evidence: fix DRM HW cursor vs software cursor fallback in flutter-pi (document in `notes.md`)

## 2. Visible pointer (flutter-pi)

- [x] 2.1 Implement chosen cursor fix as `overlay/buildroot/package/flutter-pi/0004-…` (and further patches if needed); keep existing 0001–0003 keyboard patches intact
- [x] 2.2 Rebuild flutter-pi prebuilt (`make rebuild-flutter-pi` or project equivalent) and verify package patches apply under `FLUTTER_PI_APPLY_PACKAGE_PATCHES`
- [x] 2.3 Smoke on device: plug mouse → visible pointer tracks motion; unplug → pointer hidden; scroll/click still work

## 3. Mouse settings apply path (flutter-pi + prefs)

- [x] 3.1 Define `/var/lib/hmi/` mouse preference file format (document keys/defaults for natural scroll, scroll speed, pointer speed, primary button)
- [x] 3.2 Patch flutter-pi to read prefs at start and on pointer device-add; apply libinput natural scroll / accel / left-handed when available; replace hardcoded wheel scale with scroll-speed multiplier from prefs
- [x] 3.3 Prefer live re-apply (e.g. SIGHUP or file re-read) so Demo can change settings without full process restart; fall back to documented restart only if required
- [x] 3.4 Rebuild flutter-pi prebuilt and bake into rootfs path used by the image

## 4. Dart OS abstraction

- [x] 4.1 Add `MouseSettings` model + abstract `MouseSettingsController` under `app/hmi/lib/platform/` (input or mouse), matching backlight/orientation style
- [x] 4.2 Implement `LinuxMouseSettingsController`: read/write prefs, trigger apply, map 0–100% ↔ libinput/flutter-pi scales
- [x] 4.3 Add `UsbHidMouseProbe` for best-effort presence status (by-id mouse links)
- [x] 4.4 Unit tests for percent/token mapping and default settings when files are absent

## 5. Demo UI

- [x] 5.1 Add `MouseDemoSection`: presence line, short host-path note, natural scroll switch, scroll/pointer speed sliders, primary-button toggle
- [x] 5.2 Wire section on `p2_demo_page.dart` immediately after `KeyboardDemoSection` and before Date & Time; non-blocking init
- [x] 5.3 Widget/controller tests as needed so Demo failures stay non-fatal

## 6. Image / docs / verify

- [x] 6.1 Update `linux-settings-persist` docs / ledger comments for mouse prefs; adjust `verify-rootfs-overlay.sh` only if overlay stages required defaults
- [x] 6.2 Update `docs/flutter-pi-hmi-plan.md` §12, `docs/ynh960-io-pinmux-ledger.md`, and `app/hmi/README.md` smoke steps for mouse pointer + settings
- [x] 6.3 Operator acceptance: enum → visible pointer → click/scroll → each setting visibly changes behavior → restart HMI prefs stick
