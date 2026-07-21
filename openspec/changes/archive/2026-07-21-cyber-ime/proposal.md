## Why

CyberUI (Frost parity) is in tree, but **CyberIME was explicitly deferred**. On flutter-pi there is no OEM soft keyboard suitable for HMI overlays; Settings (Wi‑Fi password, HTTP proxy, numeric fields) and future Cyber dialogs still lack an in-app keyboard. Closing P3.0’s remaining half requires a reusable **`packages/cyber_ime`** aligned with lws-ui’s custom overlay IME (not a system `InputMethodService`).

## What Changes

- Introduce **`packages/cyber_ime`** (path package first, same pattern as `cyber_ui` / `cyber_hal`; remote submodule later if needed) as the shared Flutter soft-keyboard kit: public **`CyberIme*`** APIs.
- Port lws-ui IME **behavior and layouts** (field-type registry, Keyboard A global QWERTY + symbol layers, Keyboard B dedicated numeric pad, overlay show/hide, dialog/card lift) — Flutter idioms, not a line-by-line Kotlin/Compose port.
- Integrate with **CyberUI dialog/overlay host**: keyboard height drives vertical lift of the focused dialog/input card; optional hooks to refresh glass backdrop when the keyboard opens (avoid frozen-capture misalignment).
- Wire **`app/hmi`**: depend on `cyber_ime`; suppress / ignore system soft input on Linux HMI; adopt CyberIME on priority Settings surfaces (Wi‑Fi password, proxy host/port, and at least one numeric entry).
- Document fonts/assets required for key caps; keep Chinese vs English global layout selection behind an App-registered language provider (v1 MAY ship EnglishGlobal + Numeric first if Chinese glyph assets are not ready — must be called out in tasks).

## Capabilities

### New Capabilities

- `cyber-ime`: Shared Flutter CyberIME package — field-type profiles, overlay keyboard panel, session attach/detach, commit/backspace/enter actions, language provider hook; App consumes via path dependency.

### Modified Capabilities

- `cyber-ui-dialog-host`: Dialog/overlay host MUST support IME-driven card lift and MUST allow live or refresh blur while the CyberIME panel is visible (no permanent mis-sampled freeze under a raised keyboard).
- `settings-ui`: Text / password / numeric Settings fields that currently rely on system or Material-only input SHALL use CyberIME sessions where CyberIME is available.
- `cyber-ui`: Update the “Frost parity excluding IME” stance — CyberIME is delivered by this change as the paired P3.0 follow-on (CyberUI package itself does not absorb keyboard rendering).

## Impact

- **New:** `packages/cyber_ime/` (pubspec, lib, tests, README, key fonts/assets as needed).
- **App:** `app/hmi/pubspec.yaml` path dep; bootstrap register language provider; Settings Wi‑Fi / HTTP proxy / numeric pages; possibly Demo text fields.
- **CyberUI:** Small host/lift API or documented composition with `CyberOverlayHost` / `showCyberDialog` — no merge of keyboard widgets into `cyber_ui`.
- **Reference:** lws-ui `com.lasercyber.lws.ime` + `openspec/specs/ime-custom-keyboard` + `ime-overlay-input` + `.cursor/rules/ime-keyboard-baseline.mdc` + `docs/IME.md` (overlay pitfalls).
- **Out of scope:** Full Pinyin engine / candidate bar parity beyond what lws-ui ships for ChineseGlobal in the baseline; OEM system IME; Android APK CyberIME backend; rewriting all Settings Material fields in one PR; media/click audio changes.
- **Risks:** Touch hit-testing on flutter-pi (full-screen absorbers); sticky focus vs Cyber dialog dismiss; Chinese layout font size on 1280×800; keyboard + sticky mpg123 unrelated — keep IME off the media audio path.
