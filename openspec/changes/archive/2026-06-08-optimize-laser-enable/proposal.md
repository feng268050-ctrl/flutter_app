## Why

The **Laser Enable** flow blocks emulator development because it enforces a physical **key switch** check that emulators cannot satisfy. The **Important Reminder** dialog also shows a single generic second-card message regardless of weld/cut/clean mode, and most of its copy is hard-coded English in layout/Java rather than localized string resources—making it wrong for non-weld modes and untranslated in zh-CN.

## What Changes

- **Skip key-switch preflight on emulator**: When the app runs on an Android emulator (`AndroidEmulatorUtils.isLikelyEmulator()` / `ModbusConfig.isMock()`), `EngineerModeCheck.checkWorkStatus` SHALL NOT block laser enable on key-switch-off. Production hardware behavior is unchanged.
- **Mode-specific second reminder card**: In the Important Reminder dialog (`ReminderExactDialog`), card 2 text SHALL depend on the active process model (`ModelConstant`):
  - **Continuous Weld / Spot Weld** → "Confirm that you have installed the welding copper nozzle"
  - **Cut / CNC Cut** → "Confirm that you have installed the cutting copper nozzle"
  - **Weld Path Clean / Ultra-wide Clean** → "Confirm that you have removed the laser tube and the copper nozzle"
- **Localize all Important Reminder copy**: Move dialog title, cards 1–3 tips, and confirm button text from hard-coded strings in `dialog_reminder.xml` / `ReminderExactDialog` into `strings.xml` with **values** (default English), **values-en**, and **values-zh** entries.

## Capabilities

### New Capabilities

- `laser-enable-emulator-preflight`: Emulator-specific relaxation of laser-enable preflight checks (key switch).

### Modified Capabilities

- `laser-enable-reminder-dialog`: Mode-specific second-card copy and full i18n for Important Reminder dialog strings (cards 1–3, title, confirm button).

## Impact

- **App**: `EngineerModeCheck`, `ReminderExactDialog`, `ReminderExactBuilder`, `dialog_reminder.xml`, call sites in `GeneralOperationsFragment` and `EngineerModeActivity` (pass active model to dialog).
- **Resources**: New string keys in `values/strings.xml`, `values-en/strings.xml`, `values-zh/strings.xml`.
- **Tests**: Unit test for emulator key-switch bypass; optional manual verification per mode on emulator.
