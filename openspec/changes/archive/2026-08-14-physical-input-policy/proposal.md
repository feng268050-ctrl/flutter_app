## Why

Touch-first welding HMIs (`ynh960-p800`) rarely use USB/BT physical keyboard or mouse, yet the unified OS still enumerates HID devices, configures Weston libinput, and runs probe/apply paths on every boot. Per-SKU OEM defaults plus a runtime OS Settings toggle let integrators disable physical input without forking rootfs, while SKUs that need HID can enable it in the field.

## What Changes

- Add OEM **pack-level** `input_defaults.json` (not board-level) seeded into `/var/lib/hal/input.conf` on first boot.
- Add `apply-physical-input-policy.sh` to generate dynamic udev `LIBINPUT_IGNORE_DEVICE` rules and refresh Weston cursor/libinput prefs.
- Add `PhysicalInputPolicy` in `cyber_hal`; gate keyboard/mouse presence and `apply-mouse-settings` when disabled.
- Add OS Settings enable toggles on Keyboard and Mouse pages (with seat restart on change).
- Default **off** for packs `ynh960_panel-800x1280` (`ynh960-p800`) and `sim_virt`; packs without defaults remain enabled for backward compat.

## Capabilities

### New Capabilities

- `physical-input-policy`: Pack OEM defaults, runtime `input.conf`, dynamic udev, Weston integration, HAL policy, OS Settings toggles.

### Modified Capabilities

- `oem-pack`: Pack MAY ship `input_defaults.json`; `oem-compose` seeds `input.conf` when absent.
- `hal-board-profile`: `keyboard`/`mouse` capabilities mean HAL API exists, not that physical input is enabled.
- `linux-mouse-settings`: Policy off → `isPresent` false; `apply-mouse-settings` no-op.
- `linux-usb-hid-keyboard`: When policy off, libinput ignores external keyboards; enumeration unchanged at kernel level.
- `dart-hal`: Export `PhysicalInputPolicy` under `hal/input`.
- `shell-hw-persist`: Register `apply-physical-input-policy.sh` helper.

## Impact

- `oem/packs/**`, `oem-compose.sh`, overlay libexec (board/display/hmi), `packages/cyber_hal`, `app/os_settings`, minimal `app/lws_hmi` bootstrap gate, `docs/settings-apps-roles.md`, `AGENTS.md` rebuild table.
