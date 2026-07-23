## 1. Overlay path layout and migration

- [x] 1.1 Add `VAR_HAL=/var/lib/hal` and `USERDATA_HAL=/userdata/hal` to `paths.sh`
- [x] 1.2 Extend `bind-prefs.sh` to bind `/var/lib/hal` → `/userdata/hal` and mkdir when userdata is missing
- [x] 1.3 Implement idempotent fold of known HAL basenames from `/userdata/hmi` into `/userdata/hal`; fold legacy `display-orientation` into `display.conf` key `orientation`; then remove migrated sources
- [x] 1.4 Update `diagnose-hmi.sh` (and similar) to include `/var/lib/hal` in path checks

## 2. Shell helpers and restore/launch

- [x] 2.1 Point `apply-mouse-settings.sh`, volume/backlight helpers (if still writing prefs) at `VAR_HAL`
- [x] 2.2 Update `change-orientation.sh` to upsert `orientation=` in `/var/lib/hal/display.conf` (not a standalone `display-orientation` file)
- [x] 2.3 Update `hmi-launch.sh` to read `orientation` from `display.conf`; keep flutter-pi `-o` **and** Weston `transform` mapping; read/write display-stack at `/etc/display-stack` + `/run/display-stack` (not `/etc/hmi` / `/run/hmi`); update `weston-hmi-config.sh` mouse.conf path to `VAR_HAL`
- [x] 2.4 Update `post-build.sh` to bake `/etc/display-stack` (remove `/etc/hmi/display-stack`)
- [x] 2.5 Update `usb-otg-mode.sh`, `usb-plug-ssh-vbus-check.sh`, and related USB diag scripts to use `/var/lib/hal/usb-debug`
- [x] 2.6 Update `read-device-serial.sh`, `render-mediamtx-config.sh`, and any other `product.ini` readers to `/var/lib/hal/product.ini`
- [x] 2.7 Update `restore-settings.sh` (and HAL restore call sites) to read platform prefs from `VAR_HAL` — N/A overlay script; HAL `BoardBindings.restorePersistedSettings` uses `OutputPrefs` under `/var/lib/hal`
- [x] 2.8 Grep overlay/scripts for remaining `/var/lib/hmi/{display,sound,mouse,…}` and `/etc/hmi/display-stack` / `/run/hmi/display-stack` hardcodes and fix

## 3. cyber_hal Orientation API and path defaults

- [x] 3.1 Add portable `Orientation` API under `output/display` (`orientation.dart` + barrel export); modes landscape/portrait; default landscape
- [x] 3.2 Implement Linux backend: warm-read `display.conf` `orientation` (legacy file import); set via `change-orientation`; apply via `hmi.service` restart; no `DisplayStack` branch in Dart
- [x] 3.3 Add `StubOrientation`; wire `BoardBindings` / capability as needed; unit tests for get/set + path defaults
- [x] 3.4 Change other HAL default preference paths to `/var/lib/hal/…`; change `DisplayStackProbe` defaults to `/run/display-stack` + `/etc/display-stack` (optional legacy `/…/hmi/display-stack` fallback); update unit tests
- [x] 3.5 Update `packages/cyber_hal/README.md` + `docs/hal-portability.md` (+ README stamp mentions) for `/var/lib/hal`, display-stack OS paths, `orientation` key, and Orientation API

## 4. App OsPaths, façade cutover, host tooling

- [x] 4.1 Add `OsPaths.varHal`; keep App stores on `OsPaths.varHmi`
- [x] 4.2 Migrate App off `lib/platform/display/display_orientation.dart` / `linux_flutter_pi_orientation.dart` to `cyber_hal` Orientation (delete or thin re-export)
- [x] 4.3 Update App tests / platform façades that hardcode HAL paths (datetime, orientation, …)
- [x] 4.4 Update `scripts/set-product-prop.sh` / `del-product-prop.sh` (and Makefile help / README / AGENTS mentions) to `/var/lib/hal/product.ini`
- [x] 4.5 Confirm App-owned paths remain under `/var/lib/hmi` (misc, advanced, alarm-logs, debug/push staging)

## 5. Verification

- [x] 5.1 Run `cyber_hal` / `app/hmi` unit tests for Orientation + path defaults
- [x] 5.2 Extend `verify-rootfs-overlay.sh` for `/etc/display-stack` (not `/etc/hmi/display-stack`) and HAL prefs under `/var/lib/hal` expectations where applicable
- [x] 5.3 On device after rootfs upgrade: confirm five userdata binds, `/etc/display-stack` + `/run/display-stack`, migrated prefs under `/userdata/hal`, and orientation honored on both stacks
