## 1. Assets and binding infrastructure

- [x] 1.1 Add neutral (gray) comm-status icon drawable (`check_neutral` or equivalent) sized to match existing `check_succeed` / `check_none` (36dp)
- [x] 1.2 Add `CommStatusDisplay` enum or helper and `@BindingAdapter` that maps `{emulator, statusReady, commAlarm}` to green / red / gray button drawable
- [x] 1.3 Add unit tests for display-state mapping (emulator vs device × ready × alarm)

## 2. Fragment and layout wiring

- [x] 2.1 Expose `emulator` binding variable in `fragment_warn_info.xml` (`AndroidEmulatorUtils.isLikelyEmulator()` from `WarnInfoFragment`)
- [x] 2.2 Apply binding adapter to Pump, Gun, and Feeder Comm Status `CheckBox` views; remove legacy `checked` ternary for those three tiles only
- [x] 2.3 Confirm temperature and other tiles still use `statusReady` / `dataReady` gating unchanged

## 3. Verification

- [x] 3.1 AVD: launch Alarm Information without Modbus/device — Comm Status icons gray, not red
- [x] 3.2 Device or non-emulator build: same offline state — Comm Status icons red
- [x] 3.3 Connected healthy comm on both platforms — Comm Status icons green; comm alarm on device — red; comm alarm on emulator — gray
