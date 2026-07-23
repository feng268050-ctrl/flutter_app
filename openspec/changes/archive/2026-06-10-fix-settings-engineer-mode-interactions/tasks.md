## 1. Advanced Settings Numeric Ranges

- [x] 1.1 Add explicit min/max configuration to `SettingInputDialogBuilder` for each Advanced Settings numeric dialog, using the same supported range as its validation method.
- [x] 1.2 Change Minimum Gas Pressure Threshold (`blowPressureThreshold`) validation maximum from 500 to 400 and update its user-facing max error text.
- [x] 1.3 Ensure Advanced Settings numeric steppers clamp at the configured minimum and maximum while typed input continues to use `AdvancedSettingDataCheck`.

## 2. Engineer Mode Dialog Labels

- [x] 2.1 Audit Engineer Mode numeric builder call sites and identify any dialog titles that do not match the visible row label.
- [x] 2.2 Update `InputDialogBuilder` call sites or helper signatures so numeric dialog titles use the visible row label and still append the existing unit text.
- [x] 2.3 Verify validation callbacks and ViewModel updates remain unchanged for edited Engineer Mode numeric fields.

## 3. Engineer Mode Popup and Localization

- [x] 3.1 Fix Material Type popup vertical placement so welding, cleaning, and cutting selectors open aligned directly under their field anchors.
- [x] 3.2 Preserve Material Type list content, selected item highlighting, dismiss handling, and material conversion behavior.
- [x] 3.3 Update the Simplified Chinese Cut tab or mode label string to `切割` without changing English resources or process type values.

## 4. Verification

- [x] 4.1 Run the relevant unit or instrumentation tests available for dialog/range behavior, or add focused tests if existing coverage is insufficient.
- [x] 4.2 Build and install for emulator inspection with `ADB_SERIAL=emulator-5554 SKIP_BUNDLED_FETCH=1 make sync`.
- [x] 4.3 Manually verify Advanced Settings ranges, Minimum Gas Pressure Threshold max 400, Engineer Mode Material Type popup placement, Engineer Mode dialog titles with units, and Chinese Cut label.
