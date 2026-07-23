## 1. Emulator key-switch bypass

- [x] 1.1 In `EngineerModeCheck.checkWorkStatus`, skip the `isKeySwitchOn()` gate when `ModbusConfig.isMock()` (emulator) is true
- [x] 1.2 Add unit test: emulator path returns true when key switch off and other checks pass
- [x] 1.3 Add unit test: non-emulator path still blocks when key switch off

## 2. String resources (i18n)

- [x] 2.1 Add string keys to `values/strings.xml`: dialog title, card 1 tip, three card 2 variants, card 3 focus-scale tip, confirm button
- [x] 2.2 Add matching entries to `values-en/strings.xml`
- [x] 2.3 Add Simplified Chinese translations to `values-zh/strings.xml`

## 3. Important Reminder dialog — mode-specific card 2

- [x] 3.1 Add `LaserEnableReminderCopy` (or equivalent) mapping `ModelConstant` → card 2 `@string` resource id
- [x] 3.2 Extend `ReminderExactBuilder.openReminderExactDialog` and `ReminderExactDialog` constructor to accept `processModel`
- [x] 3.3 Update `GeneralOperationsFragment` and `EngineerModeActivity` call sites to pass `deviceControlData.getModel()`
- [x] 3.4 Update `dialog_reminder.xml`: replace hard-coded title, card 1, confirm button with `@string/` references; add `android:id` on card 2 `TextView`
- [x] 3.5 In `ReminderExactDialog`, bind card 2 text from model mapping and card 3 text from string resource (remove Java literal)

## 4. Verification

- [ ] 4.1 Manual: on emulator, laser enable proceeds without key-switch error
- [ ] 4.2 Manual: open Important Reminder in each model group (weld / cut / clean) and confirm card 2 copy
- [ ] 4.3 Manual: switch locale to zh-CN and confirm dialog strings are translated
