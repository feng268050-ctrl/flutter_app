## 1. KeySwitchOffPrompt chrome and paths

- [x] 1.1 Add a chrome selector (WARN vs INFO) to `KeySwitchOffPrompt._show` via `WarnDialogBody.infoStyle` / `WarnChromeStyle`
- [x] 1.2 Split edge vs Laser Enable: `maybeShow` for key-off edge chooses WARN when Misc is on, INFO when off (ignore Laser Enable session)
- [x] 1.3 `presentLaserEnableKeyOffBlock` always INFO; if a WARN frost is showing, dismiss it first then show INFO; drop Operation-failed fallback
- [x] 1.4 Keep Confirm + `reset()` on key restore stopping SFX; latch edge once per key-off

## 2. Work-screen routing

- [x] 2.1 Quick / Engineer `keySwitchOff` safety event always calls `KeySwitchOffPrompt.maybeShow` with current Misc toggle (no silent edge)
- [x] 2.2 Enable Laser key-off in `quick_mode_page`, `device_control_bar`, `engineer_device_panel` always uses `presentLaserEnableKeyOffBlock` (no Operation-failed tip)
- [x] 2.3 Confirm `EmergencyStopPrompt` stays INFO-only for edge and Enable Laser; no Misc gate; no WARN; Confirm / E-stop clear dismisses

## 3. Tests

- [x] 3.1 Cover Misc on → edge WARN; Misc off → edge INFO; Enable Laser key-off → INFO even when Misc on
- [x] 3.2 Cover E-stop edge and Enable Laser stay INFO; restore/confirm dismiss
- [x] 3.3 Run targeted `flutter test` under `app/lws_hmi/` for the prompt / device-control tests
