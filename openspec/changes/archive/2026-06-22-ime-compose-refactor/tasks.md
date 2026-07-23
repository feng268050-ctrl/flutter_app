## 1. ime core and engine

- [x] 1.1 Create `app/src/main/kotlin/com/lasercyber/lws/ime/` skeleton (`core/`, `engine/`, `keyboard/`, `compose/`, `interop/`)
- [x] 1.2 Implement `ImeConfig`, `ImeEnterKeyConfig`, `ImeEnterKeyDisplay` (Text / Icon / TextAndIcon / Default), `ImeHostPolicy`, `ImeAnchor`, `ImeInsets.computeCardTranslationY`
- [x] 1.3 Implement `ImeInputConnection` adapter for `EditText` (commit, delete, performEditorAction)
- [x] 1.4 Implement `ImeSession` with Activity refcount, softInputMode save/restore, custom panel height lift
- [x] 1.5 Implement `ImeController` (attach, detach, showCustomKeyboard, hideCustomKeyboard, hideSystemIme)
- [x] 1.6 Add `ImeAction`, `ImeRegistry` (`languageProvider`, `onKeyboardShown`, `onAnchorLiftApplied`)
- [x] 1.7 Add `app/src/test/.../ime/ImeInsetsTest.kt`
- [x] 1.8 Convert `FrostedGlassImeCoordinator` to `@Deprecated` facade delegating to `ImeController`

## 2. keyboard layout data layer

- [x] 2.1 Define `KeyboardKind`, `KeyboardMode`, `KeyDef`, `KeyId` models
- [x] 2.2 Implement `GlobalQwertyLayout` upper rows (Q–P, A–L, Shift+Z–M+Backspace) with secondaries per device reference (figure 1)
- [x] 2.3 Implement global bottom row: `123`/`abc`, Space, comma/period, `@`, Enter placeholder (5 keys, figure 3)
- [x] 2.4 Implement `NumericLayout` (0–9 + Backspace + Enter) per device numeric reference
- [x] 2.5 Implement language selection: `ChineseGlobal` vs `EnglishGlobal` from `ImeRegistry.languageProvider`
- [x] 2.6 Wire `123`/`abc` mode switch between global and numeric keyboard kinds

## 3. Compose keyboard UI (FrostButton key caps)

- [x] 3.1 Implement `ImeKeyboardPanel` Composable hosting row layout from `KeyDef`
- [x] 3.2 Render letter/symbol keys with `FrostButtonVariant.DEFAULT` and secondary corner hints
- [x] 3.3 Implement `ImeEnterKey` Composable (always PRIMARY; render text-only, icon-only, or text+icon from `ImeEnterKeyDisplay`)
- [x] 3.4 Implement Shift state and Backspace on global keyboard
- [x] 3.5 Add `@dimen/ime_keyboard_height` and stable panel sizing for overlay lift
- [x] 3.6 Register `languageProvider` in app bootstrap (`SystemSettingUtils.getLanguage()`)

## 4. Long-press letter popup

- [x] 4.1 Implement `ImeLetterPopup` (uppercase | secondary | lowercase) anchored above key (figure 2)
- [x] 4.2 Wire long-press detection on all letter keys; short tap commits primary without popup
- [x] 4.3 Support slide-to-highlight and release-to-commit; dismiss on cancel
- [x] 4.4 Add unit tests for popup selection → `ImeInputConnection.commitText`

## 5. frostui dialog integration and wrappers

- [x] 5.1 Register `ImeRegistry` frost hooks in `FrostUiDialogBridge`
- [x] 5.2 Add `imeConfig: ImeConfig?` (with `enterKey`) to `FrostPromptConfig`
- [x] 5.3 Wire `FrostOverlayHost` / `ImeHost` to show `ImeKeyboardPanel` and attach/detach `ImeController`
- [x] 5.4 Update `FrostedGlassTextInputDialog` (custom keyboard, Done enter)
- [x] 5.5 Update `FrostedGlassNumericInputDialog` (Numeric keyboard, stepper `onEditTextReady`)
- [x] 5.6 Update `FrostedGlassWifiPasswordDialog` (Connect enter label, no on-screen Connect)
- [x] 5.7 Refactor `FrostNumericStepper` ± to `FrostButton` DEFAULT

## 6. Verification and cleanup

- [x] 6.1 Manual test: English global keyboard — bottom 5 keys, shift, secondaries, long-press popup on all letters
- [x] 6.2 Manual test: Chinese global keyboard — language switch selects ChineseGlobal layout
- [x] 6.3 Manual test: Numeric keyboard — 0–9, engineer decimal/integer dialogs
- [x] 6.4 Manual test: WiFi password — primary orange Enter shows Connect, submit works, no duplicate button
- [x] 6.5 Manual test: overlay background not compressed; dismiss clears panel and insets
- [x] 6.6 Delete `FrostedGlassImeCoordinator.java` and remove system `showSoftInput` from migrated paths
- [x] 6.7 Run `make sync` on emulator for visual acceptance
