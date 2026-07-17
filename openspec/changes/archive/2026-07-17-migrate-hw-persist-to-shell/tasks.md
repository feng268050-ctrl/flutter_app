## 1. Shell helpers (apply + persist)

- [x] 1.1 Confirm `change-backlight.sh` persists `/var/lib/lws-hmi/backlight-brightness`; finish if incomplete
- [x] 1.2 Add `change-volume.sh` (ALSA apply matching restore-settings + persist `media-volume`)
- [x] 1.3 Add `change-orientation.sh` (persist `display-orientation`; optional apply/restart flag per design)
- [x] 1.4 Add `apply-mouse-settings.sh` (write/update `mouse.conf` schema used by flutter-pi)
- [x] 1.5 Point `restore-settings.sh` volume path at `change-volume.sh` when present

## 2. PATH + verify

- [x] 2.1 Link `change-volume`, `change-orientation`, `apply-mouse-settings` in `lws-hmi-post-build.sh` (backlight already linked)
- [x] 2.2 Extend `verify-rootfs-overlay.sh` / `env-verify.sh` helper and `/usr/bin` assertions
- [x] 2.3 Clean retired dual-write-only paths in post-build if any

## 3. Flutter backends

- [x] 3.1 `LinuxSysfsBacklight`: set via `change-backlight`; remove Dart `_persistPercent` write
- [x] 3.2 `LinuxMediaAudioController`: set volume via `change-volume`; remove Dart volume file write
- [x] 3.3 `LinuxFlutterPiOrientation`: set via `change-orientation`; remove Dart pref write
- [x] 3.4 `LinuxMouseSettings`: set via `apply-mouse-settings`; remove Dart-only `mouse.conf` write
- [x] 3.5 Update/replace `backlight_persist_test.dart` / `media_volume_persist_test.dart` (and mouse/orientation tests) for helper-based persist

## 4. Docs + device check

- [x] 4.1 Update `app/hmi/README.md` (or platform notes) that shell owns these prefs
- [x] 4.2 On device after rootfs upgrade: SSH `change-backlight` / `change-volume`, confirm pref files, reboot, confirm restore
