## 1. WarnDialog dual-button foundation

- [x] 1.1 Add `jumpButtonText` and `onJump` to `WarnDialogVo`
- [x] 1.2 Update `dialog_warn.xml` footer: horizontal row with left `btn_confirm`, divider, right `btn_jump` (jump default `gone`)
- [x] 1.3 Extend `WarnDialogUtil.initDialog` / `openDialog` to bind dual-button mode when `jumpButtonText` is set; preserve single-button layout for existing alarms

## 2. Zero-point offset alert migration

- [x] 2.1 Refactor `ZeroPointOffsetWarnAlarm.tryShowDialog` to build `WarnDialogVo` (security alert title, offset body, no progress chart) and show via `WarnDialogUtil` instead of `AlertDialog`
- [x] 2.2 Wire left confirm to `onDialogDismissed` (same pending clear + deferred queue as today)
- [x] 2.3 Wire right jump to exit weld work (disable laser, finish mode) then open `DeviceSettingActivity` with `EXTRA_INITIAL_TAB_INDEX = TAB_INDEX_ADVANCED_SETTINGS`; preserve `ZeroPointPendingCorrectionStore` on jump
- [x] 2.4 Remove obsolete `AlertDialog` field/handling; keep `dismissDialog` / laser-ON gating / `resetForStop` behavior

## 3. Verification

- [ ] 3.1 Manual: laser stop in Quick/Engineer continuous weld shows WarnDialog-style popup; left confirm closes without re-show until next fault cycle
- [ ] 3.2 Manual: right jump exits Quick/Engineer mode, laser off, opens Settings → Advanced Settings tab; pending zero-point Auto still available
- [ ] 3.3 Regression: camera communication C002 popup still single-button confirm only
