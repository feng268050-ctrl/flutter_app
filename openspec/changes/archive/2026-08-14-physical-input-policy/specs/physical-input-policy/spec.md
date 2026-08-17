## ADDED Requirements

### Requirement: Pack-level input defaults

OEM packs MAY ship `input_defaults.json` beside `manifest.json` with boolean keys `physical_keyboard_enabled` and `physical_mouse_enabled`. `oem-compose` SHALL seed `/var/lib/hal/input.conf` from the active pack file when runtime `input.conf` is absent. When the pack file is absent, both keys SHALL default to enabled. When runtime `input.conf` already exists, compose MUST NOT overwrite it.

#### Scenario: ynh960-p800 first boot

- **WHEN** OEM pack `ynh960_panel-800x1280` includes both keys false and `/var/lib/hal/input.conf` is missing
- **THEN** compose SHALL write `physical_keyboard_enabled=0` and `physical_mouse_enabled=0`

#### Scenario: Operator override preserved

- **WHEN** `/var/lib/hal/input.conf` exists on userdata
- **THEN** compose SHALL NOT modify it regardless of pack defaults

### Requirement: Runtime input policy file

The system SHALL persist enable flags in `/var/lib/hal/input.conf` as key=value lines `physical_keyboard_enabled` and `physical_mouse_enabled` with values `0` or `1`. Missing keys SHALL be treated as enabled (`1`).

#### Scenario: Missing file defaults enabled

- **WHEN** `input.conf` does not exist and no pack seed ran
- **THEN** HAL policy SHALL report both keyboard and mouse as enabled

### Requirement: Dynamic udev libinput ignore

`apply-physical-input-policy.sh` SHALL read `/var/lib/hal/input.conf` and write or remove `/etc/udev/rules.d/99-lws-physical-input.rules` so disabled device classes receive `ENV{LIBINPUT_IGNORE_DEVICE}="1"`. Keyboard ignore rules MUST exclude board power/button devices (`gpio-keys`, pwrkey, adc-keys, and documented Rockchip pwrkey name patterns). The helper SHALL reload udev rules and trigger the input subsystem.

#### Scenario: Mouse disabled generates ignore rule

- **WHEN** `physical_mouse_enabled=0` and the helper runs
- **THEN** udev rules SHALL set `LIBINPUT_IGNORE_DEVICE` for `ID_INPUT_MOUSE` devices

#### Scenario: Both enabled removes rules file

- **WHEN** both enable keys are `1` and the helper runs
- **THEN** the generated udev rules file SHALL be absent or empty and libinput SHALL not ignore HID mice/keyboards

### Requirement: Weston cursor when mouse disabled

When `physical_mouse_enabled=0`, runtime `weston.ini` written by `weston_write_hmi_ini` SHALL set `cursor-size=0`.

#### Scenario: No pointer cursor on touch SKU

- **WHEN** mouse policy is off and Weston starts
- **THEN** the compositor cursor size SHALL be zero

### Requirement: HAL physical input policy API

`package:cyber_hal` SHALL expose `PhysicalInputPolicy` under `hal/input` with async read/write of enable flags and `isPhysicalKeyboardEnabled` / `isPhysicalMouseEnabled` defaulting to true when unset.

#### Scenario: Policy off skips presence probe

- **WHEN** `physical_keyboard_enabled=0`
- **THEN** `Keyboard.isPresent()` SHALL return false without requiring a USB keyboard

### Requirement: OS Settings enable toggles

OS Settings Keyboard and Mouse pages SHALL provide enable switches that persist policy, invoke `apply-physical-input-policy`, and restart the active Flutter seat without a confirmation dialog. When the switch is off, each page SHALL show policy help text below the switch. Soft keyboard layout controls SHALL remain available when physical keyboard is disabled.

#### Scenario: Enable mouse from OS Settings

- **WHEN** the operator enables physical mouse
- **THEN** policy SHALL persist as enabled, udev ignore for mice SHALL be cleared, and a USB mouse SHALL work after seat restart

### Requirement: apply-mouse-settings respects policy

When `physical_mouse_enabled=0`, `apply-mouse-settings` SHALL exit successfully without rewriting `mouse.conf` or restarting the seat for mouse pref changes.

#### Scenario: Mouse settings blocked when disabled

- **WHEN** mouse policy is off and Settings attempts `setSettings`
- **THEN** the helper SHALL not apply mouse prefs until policy is enabled
