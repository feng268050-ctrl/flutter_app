## 1. Layout and IME configuration

- [x] 1.1 Remove `btn_connect` from `app/src/main/res/layout/dialog_wifi_password.xml` and any margins/layout that only served that row; adjust `et_password` `imeOptions` to match the chosen IME action (per design, e.g. `actionGo`).
- [x] 1.2 Verify no other references to `R.id.btn_connect` remain after layout removal.

## 2. Activity logic

- [x] 2.1 In `WifiActivity.showPasswordDialog`, remove `btn_connect` click wiring; after inflating/binding `et_password`, set `imeActionLabel` to `getString(R.string.wifi_dialog_connect)` for the configured action (or equivalent XML + code) so the keyboard shows Connect in all active locales.
- [x] 2.2 Consolidate submit logic: one path for “validate password → `connectAndSaveWifi` → dismiss” used from `OnEditorActionListener` (IME action + hardware Enter as today).
- [x] 2.3 Manual test on device/emulator: encrypted network tap → dialog has no Connect button → keyboard action shows Connect → empty vs non-empty password behavior matches prior toasts and connect. (Note: on current target IME, action text is vendor-forced to `send`; treated as accepted platform limitation.)
