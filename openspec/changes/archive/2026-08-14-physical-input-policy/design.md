## Context

One rootfs/kernel image serves multiple factory SKUs. Input enablement is a **product policy** carried by OEM pack defaults and operator overrides in `/var/lib/hal/input.conf` (userdata bind). Board `capabilities: keyboard/mouse` remain for HAL API availability.

## Decisions

### D1 — Pack-level OEM defaults

- File: `oem/packs/<pack_id>/input_defaults.json`
- Seed: `oem-compose` writes `/var/lib/hal/input.conf` only when the file is missing.
- `ynh960-p800` → pack `ynh960_panel-800x1280` → both disabled.
- `sim_virt` → both disabled (emulator parity).
- Missing pack file → keys default to enabled (`1`).

### D2 — Runtime udev (LIBINPUT_IGNORE_DEVICE)

- Generated file: `/etc/udev/rules.d/99-lws-physical-input.rules` (not baked in rootfs).
- Helper: `/usr/libexec/board/apply-physical-input-policy.sh`
- Mouse disabled: `ENV{ID_INPUT_MOUSE}=="1"` → `LIBINPUT_IGNORE_DEVICE=1`
- Keyboard disabled: `ENV{ID_INPUT_KEYBOARD}=="1"` with ATTR exclusions for board buttons (`gpio-keys`, `pwrkey`, `adc-keys`, `rk*pwr*` patterns).
- After write: `udevadm control --reload-rules`; `udevadm trigger -s input`
- Seat restart when Weston ini changes (debounced like mouse apply).

### D3 — Weston

- `weston-hmi-config.sh` reads `input.conf` via shared `input_conf_get`.
- Mouse disabled → `cursor-size=0` (emulator touch-only pattern).
- Keyboard disabled → no change to `[keyboard]` repeat (pwrkey path unaffected).

### D4 — Boot order

`bind-prefs` → `oem-compose` (seed) → `hmi-launch`: `apply-physical-input-policy.sh` → `weston_write_hmi_ini` → weston → flutter.

### D5 — HAL / Apps

- `PhysicalInputPolicy` owns read/write of `input.conf` enable keys.
- `LinuxKeyboard.isPresent` / `LinuxMouse.isPresent` return false when policy off (skip probe).
- `apply-mouse-settings.sh` exits 0 without writing when mouse disabled.
- OS Settings: toggles persist policy, invoke helper, confirm seat restart.
- HMI: skip `_bootstrapKeyboardProfile` when keyboard policy off.

## Risks

- BT HID covered by same udev `ID_INPUT_*` tags — acceptable for “physical input off” product policy.
- Re-enable may require seat restart; document in OS Settings confirm dialog.
- Existing boards with no `input.conf` get pack seed on next boot after OEM upgrade only if file still missing.

## Rollback

Remove udev rules file and set both keys to `1` in `input.conf`; run helper; restart seat.
