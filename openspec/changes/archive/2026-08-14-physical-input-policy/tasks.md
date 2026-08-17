## 1. OpenSpec artifacts

- [x] 1.1 proposal.md, design.md, spec deltas, tasks.md

## 2. OEM pack defaults

- [x] 2.1 Add `oem/packs/ynh960_panel-800x1280/input_defaults.json` (both false)
- [x] 2.2 Add `oem/packs/sim_virt/input_defaults.json` (both false)
- [x] 2.3 Extend `oem-compose.sh` to seed `/var/lib/hal/input.conf` from pack file when absent

## 3. Rootfs / overlay

- [x] 3.1 Add `apply-physical-input-policy.sh` under `usr/libexec/board/`
- [x] 3.2 Add `input_conf_get` helpers; wire `weston-hmi-config.sh` cursor-size from policy
- [x] 3.3 Call policy helper from `hmi-launch.sh` before `weston_write_hmi_ini`
- [x] 3.4 Gate `apply-mouse-settings.sh` when mouse disabled
- [x] 3.5 Add `input.conf` to `bind-prefs.sh` migration list
- [x] 3.6 Update `post-build.sh` / `verify-rootfs-overlay.sh` as needed

## 4. cyber_hal

- [x] 4.1 Implement `PhysicalInputPolicy` + export from `hal/input.dart`
- [x] 4.2 Gate `LinuxKeyboard.isPresent` / `LinuxMouse.isPresent`
- [x] 4.3 Wire `board_bindings.physicalInputPolicy()`; optional helper in board_profile
- [x] 4.4 Unit tests for policy parse/default/gating

## 5. OS Settings

- [x] 5.1 Keyboard/Mouse enable toggles + restart confirm
- [x] 5.2 Shell summary strings
- [x] 5.3 l10n strings (en + zh if pattern exists)

## 6. HMI

- [x] 6.1 Skip `_bootstrapKeyboardProfile` when keyboard policy off

## 7. Docs

- [x] 7.1 Update `docs/settings-apps-roles.md`
- [x] 7.2 Update `AGENTS.md` rebuild table

## 8. Verify

- [x] 8.1 `dart test` in cyber_hal; `flutter analyze` os_settings + lws_hmi touched files
