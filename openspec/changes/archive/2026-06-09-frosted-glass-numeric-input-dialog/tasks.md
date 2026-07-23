## 1. Shared infrastructure

- [x] 1.1 Add `frosted_glass_body_numeric_input.xml` (desc TextView, ± buttons, numeric EditText) using frosted-glass color/drawable tokens
- [x] 1.2 Implement `FrostedGlassImeCoordinator` — save/restore host `softInputMode`, apply IME inset translation to overlay card, cleanup on dismiss (refcount-safe for overlay stack)
- [x] 1.3 Implement `FrostedGlassNumericInputDialog` with config object (input type, stepper, desc, min/max, default, title unit), confirm/cancel wiring, and auto-focus + show keyboard on open
- [x] 1.4 Extract numeric step/clamp/format helpers from `InputDialogFragment` into reusable package-private helper used by the new wrapper

## 2. Engineer mode migration

- [x] 2.1 Refactor `InputDialogBuilder` numeric builders (~22 methods) to call `FrostedGlassNumericInputDialog.show(...)` directly (return `void`; preserve all `EngineerDataCheck` lambdas)
- [x] 2.2 Update engineer-mode fragments (`EngineerCuttingFragment`, `EngineerWashFragment`, `EngineerSpotWeldingFragment`, etc.) — remove `.show(getSupportFragmentManager(), tag)` from numeric builder call sites

## 3. Advanced settings migration

- [x] 3.1 Refactor `SettingInputDialogBuilder` (~10 methods) to call `FrostedGlassNumericInputDialog.show(...)` directly
- [x] 3.2 Update `AdvancedSettingFragment` — remove `FragmentManager.show()` from numeric input call sites

## 4. Legacy cleanup

- [x] 4.1 Delete `InputDialogFragment.java` and `DialogInputBinding` / `dialog_input` layout and related drawables once no references remain
- [x] 4.2 Remove unused imports, LogTAG entries, and any dead keyboard/blur utilities only used by `InputDialogFragment`

## 5. Verification

- [x] 5.1 Manual test: engineer-mode integer field (e.g. laser power) — validation, ± stepper, scrim tap to cancel, IME Done/Send to submit
- [x] 5.2 Manual test: engineer-mode decimal field with unit title (e.g. thickness) — ±0.1 stepper, desc text
- [x] 5.3 Manual test: advanced-settings signed integer (e.g. zero point correction)
- [x] 5.4 Manual test: open keyboard → verify background page is NOT compressed; dismiss → verify no residual inset/blank area
- [x] 5.5 Build app module and fix any compile errors from removed `InputDialogFragment`
