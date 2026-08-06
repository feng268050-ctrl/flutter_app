## Why

Product surfaces still mix CyberUI controls with Material stand-ins (raw `Checkbox`, `SwitchListTile`, `FilledButton`/`AlertDialog`, bare `TextField`). Operators see inconsistent checkbox sizes (boot self-check 38 vs tips/settings 28) and divergent chrome for the same roles. Closing this gap aligns HMI with CyberUI/HmiButton/CyberIME adoption already required by Settings and CyberUI specs.

## What Changes

- **Checkbox:** All product “don’t show again” / settings / process toggles use `CyberCheckbox` at `CyberDimens.checkboxLargeSize` (**28**). Remove boot self-check hard-coded `size: 38`. Replace Material `Checkbox` in Engineer Mode entry tip and Laser Enable reminder with `CyberCheckbox` (cream light prompts keep host chrome; control widget unifies).
- **Switch:** Engineer/Quick `device_control_bar` manual-gas control migrates from Material `SwitchListTile` to `CyberSwitch` (or Settings-equivalent Cyber switch row pattern).
- **Buttons / dialogs:** Process Library edit/confirm flows, IP Camera Settings primary actions, and shared Wi‑Fi network list actions migrate off Material `FilledButton`/`OutlinedButton`/`TextButton`/`AlertDialog` to `HmiButton` + `TipDialogHost` / existing product dialog patterns (no new toast system in this change).
- **Text input:** Process Library edit forms migrate bare `TextField` to CyberIME (`showCyberImeInputDialog` / `CyberImeTextField` as appropriate).

Out of scope: Demo (`lib/ui/demo/**`); intentional process-mode outline side keys (`ProcessModeOutlineButton`); cream `showLightPrompt` barrier chrome for Engineer tip / Laser Enable (host stays light; only the checkbox widget unifies); SnackBar → tip toast redesign.

## Capabilities

### New Capabilities

- `product-control-chrome`: Product HMI control parity — checkbox/switch/button-dialog/IME must use CyberUI/Hmi/CyberIME on listed product surfaces with checkbox face **28**.

### Modified Capabilities

- `product-boot-self-check`: Footer “don’t show again” must use `CyberCheckbox` @ 28 (not ad-hoc 38).
- `cyber-ui-controls`: Product adoption MUST use only `checkboxSmallSize` / `checkboxLargeSize` tiers for face size (no one-off sizes on product call sites).
- `settings-ui`: Reinforce that product Settings already on Cyber controls stay on Cyber; no regression to Material Switch/Checkbox for those rows.
- `ip-camera`: Settings page primary CTAs use `HmiButton` (not Material filled buttons).
- `wifi-network-list`: Shared Wi‑Fi list actions use `HmiButton` (not Material filled/text buttons).

## Impact

- App: `boot_self_check_dialog`, `engineer_mode_entry_tips_dialog`, `laser_enable_reminder_dialog`, `device_control_bar`, `process_library_page`, `ip_camera_settings_page`, `wifi_network_views` (+ any thin wrappers).
- Packages: `cyber_ui` dimens/docs only if needed to document tiers; no new control types required.
- Tests: widget tests asserting checkbox widget type/size and migrated dialogs/buttons.
- Rebuild: `make build-app` / `make push-app` (or board path per AGENTS.md).
