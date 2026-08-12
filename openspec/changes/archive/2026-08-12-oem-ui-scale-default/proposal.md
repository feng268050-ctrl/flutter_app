## Why

UI Scale is panel-specific tuning (ynh960 800×1280 typically needs ~113% for comfortable readability after the physical 1:1 baseline). Today factory and field service must set it manually in OS Settings on every device. OEM already carries per-screen defaults such as `default_orientation` and LCD params; baking the initial `ui_scale` into the screen pack removes repetitive setup while preserving operator override via `display.conf`.

## What Changes

- Add optional `default_ui_scale` to OEM `screen.json` (parallel naming to `default_orientation`).
- Extend `oem-compose` to export `SCREEN_DEFAULT_UI_SCALE` in `/run/hmi/screen.env`.
- On boot, when `/var/lib/hal/display.conf` has no `ui_scale` key, seed it from the OEM screen default (factory reset and fresh flash included).
- Set `default_ui_scale` for the ynh960 800×1280 panel pack (`1.13`) and the virt emulator screen pack (`1.28`).
- Correct `docs/p32-emulator.md` and related docs that wrongly told operators to set QEMU UI scale to ~113% (`1.13`, the ynh960 default).
- Document the field in OEM / HAL portability docs; no App UI changes (OS Settings slider unchanged).

## Capabilities

### New Capabilities

<!-- None — extends existing OEM pack + settings persist contracts -->

### Modified Capabilities

- `oem-pack`: `screen.json` schema, `screen.env` export, and first-boot seed contract for panel UI scale defaults.
- `linux-settings-persist`: clarify that absent `ui_scale` MAY be initialized from OEM before Apps read `display.conf`; operator writes still win.

## Impact

- `oem/screens/*/screen.json` — new optional key per screen pack.
- `overlay/.../usr/libexec/oem/oem-compose.sh` — parse and export `SCREEN_DEFAULT_UI_SCALE`.
- `overlay/.../usr/libexec/hmi/hmi-launch.sh` (or shared display helper) — seed `display.conf` when `ui_scale` is missing.
- `docs/hal-portability.md`, `docs/p32-emulator.md` — OEM default vs manual override.
- `scripts/env-verify.sh` — optional gate for ynh960 / virt packs.
- No Dart / `cyber_hal` API changes required if seeding happens before `warmRead()`.
