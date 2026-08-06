## 1. Checkbox → CyberCheckbox @ 28

- [x] 1.1 Boot self-check footer: replace `CyberCheckbox(size: 38)` with `size: CyberDimens.checkboxLargeSize` (28)
- [x] 1.2 Engineer Mode entry tip: replace Material `Checkbox` + FittedBox with `CyberCheckbox` @ large (28); keep cream `showLightPrompt`
- [x] 1.3 Laser Enable reminder: same Material → `CyberCheckbox` @ large (28)
- [x] 1.4 Grep product `lib/features` for remaining Material `Checkbox(` / ad-hoc checkbox sizes; fix any stragglers
- [x] 1.5 Update widget tests for boot self-check / tip dialogs (assert CyberCheckbox / size where practical)

## 2. Switch → CyberSwitch

- [x] 2.1 `device_control_bar` manual gas: replace `SwitchListTile` with row + `CyberSwitch` (preserve labels/behavior)
- [x] 2.2 Adjust/add tests for device control bar gas toggle if present

## 3. Process Library buttons, dialogs, CyberIME

- [x] 3.1 Migrate Process Library `AlertDialog` confirms to `TipDialogHost` + `HmiButton` actions
- [x] 3.2 Replace Process Library Material `FilledButton` / `OutlinedButton` / `TextButton` CTAs with `HmiButton` (sizes match nearby product chrome)
- [x] 3.3 Replace Process Library edit `TextField`s with CyberIME (`showCyberImeInputDialog` and/or `CyberImeTextField`)
- [x] 3.4 Update Process Library widget tests

## 4. IP Camera Settings + Wi‑Fi list buttons

- [x] 4.1 IP Camera Settings: Material `FilledButton` CTAs → `HmiButton`
- [x] 4.2 `wifi_network_views`: Material filled/text actions → `HmiButton`
- [x] 4.3 Smoke/widget coverage for Wi‑Fi list / IP Camera settings actions as existing tests allow

## 5. Verify

- [x] 5.1 `flutter analyze` on touched packages/files
- [x] 5.2 Run targeted widget tests for changed surfaces
- [x] 5.3 Device/emulator visual QA: boot self-check, Engineer tip, Laser Enable, Process Library edit, IP Camera Settings, Wi‑Fi list
