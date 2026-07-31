# cyber_ime

Reusable **CyberIME** in-app overlay soft keyboard for LWS HMI. Path package
under `packages/cyber_ime` (same pattern as `cyber_ui` / `cyber_hal`).

Not a system / OEM IME. Product Apps depend on this package for HMI text entry
instead of forking keyboard widgets under feature folders.

## Module map

| Area | API |
|------|-----|
| Field types | `CyberImeFieldType`, `CyberImeFieldProfile`, `CyberImeFieldProfileRegistry` |
| Policy | `CyberImeNumericPolicy`, `CyberImeBottomRowProfile` |
| Session | `CyberImeSession`, `CyberImeAction`, `CyberImeCommitTarget` |
| Language | `CyberImeLanguageProvider`, `CyberImeLanguageRegistry` |
| Regional layout | `CyberImeRegionalProfile`, `CyberImeRegionalLayoutRegistry`, `CyberImeKeyCode`, `CyberImeKeyMaps` |
| Layouts | Keyboard A (regional letters + `123` + `#+=`), Keyboard B (dedicated numeric) |
| Overlay | `CyberImeOverlay`, `CyberImeKeyboardPanel` |
| Layout preview | `CyberImeLayoutPreview` (keycap strip only) |
| Layout chooser | `CyberImeLayoutChooser` (Segment + caption + preview — product Settings drop-in) |
| Field chrome | `CyberImeTextField` |
| Physical keyboard | `CyberImePhysicalKeyboard` — **App injects** HAL `Keyboard.isPresent` (no `/dev` in IME) |

## Path wiring

```yaml
# app/lws_hmi/pubspec.yaml
dependencies:
  cyber_ime:
    path: ../../packages/cyber_ime
```

```dart
import 'package:cyber_ime/cyber_ime.dart';
```

Register providers at App bootstrap:

```dart
CyberImeLanguageRegistry.register(
  const CyberImeFixedLanguageProvider(CyberImeGlobalKind.english),
);
CyberImeRegionalLayoutRegistry.register(
  CyberImeMutableRegionalLayoutProvider(), // or fixed ansiUs
);
```

## Keyboard kinds

- **Keyboard A:** regional letter layer → primary symbols (`123`) → extended (`#+=`) → `ABC`.
- **Keyboard B:** dedicated pad `1–9 ⌫ / C / - / . 0 00 ⏎` (no `abc` switch).

## Regional soft layouts

Keyboard A letter arrangements are **phone soft pads** (QWERTY / QWERTZ /
AZERTY) from `CyberImeSoftLayouts`, shared by the live panel and Settings
preview:

- Three letter rows + bottom (`123` / Space / confirm).
- No number row, F-keys, Tab/Caps, Ctrl/Alt/AltGr, or NumPad on Keyboard A.
- Digits/symbols only via `123` / `#+=` layers.
- QWERTZ/AZERTY accents via long-press.

`CyberImeKeyMaps` remains for XKB-aligned character tables (physical/reference).
Physical USB/BT typing continues via XKB using the matching layout id
(`us` / `de` / `fr` / `jp`); product Settings keeps soft profile and XKB
preference on the same selection. **Do not** remap HID scancodes in Dart.

`CyberImeTextField` stays **editable** (`readOnly: false`) and hides any system
soft keyboard via `TextInput.hide`, so physical keys are not blocked. Soft
CyberIME is skipped when the App-registered
[`CyberImePhysicalKeyboard`](lib/src/input/cyber_ime_physical_keyboard.dart)
detector reports present (product wiring: `Keyboard.isPresent` from
`cyber_hal`). CyberIME never opens `/dev/input` itself. Soft overlay teardown on a hardware
key (HAL miss / race) is deferred to a **post-frame** callback so key-repeat
is not interrupted mid-dispatch.

Hold-to-repeat: Wayland advertises rate/delay via `wl_keyboard.repeat_info`, but
flutter-elinux currently ignores it. Until the embedder synthesizes
`KeyRepeatEvent`, [`CyberImePhysicalKeyRepeat`](lib/src/input/cyber_ime_physical_key_repeat.dart)
inserts into the focused field’s controller after a short delay while a
printable key, Backspace, Delete, or arrow key stays down (cancels if a real
`KeyRepeatEvent` arrives).

### Soft vs physical simplifications

| Topic | Soft CyberIME | Physical XKB |
|-------|---------------|--------------|
| F-keys / NumPad | Not drawn | Hardware / eLinux |
| ANSI modifiers | Ctrl / Alt / Space bottom; Enter on home row | Full ANSI via XKB `us` |
| ANSI Shift layer | KeyMap `base`/`shift` + long-press slide popup | Shift via XKB |
| QWERTZ ISO | Short left Shift + `<`; ü ö ä #; Ctrl/Alt/Space/AltGr; Y/Z via KeyMap | XKB `de` |
| AZERTY AltGr | Long-press secondaries + AltGr layer approximate third level | Full AltGr via XKB |
| Preview | `CyberImeLayoutChooser` / `CyberImeLayoutPreview` | Same KeyMap labels |

## ChineseGlobal (deferred)

v1 ships **EnglishGlobal** letter caps only. When the language provider reports
Chinese, EnglishGlobal is still shown until ChineseGlobal assets/layout are
ported from lws-ui (OpenSpec task 3.6). Do not claim Chinese parity in product
docs until that task is done. Regional profiles (ANSI/QWERTZ/…) are orthogonal
to chinese/english language selection.

## Fonts / assets

v1 uses Material / system fonts for key caps. No bundled IME font yet; add
under `packages/cyber_ime/assets/` when ChineseGlobal lands.

## Hit-testing

The overlay touch host is **panel-sized only** (keyboard chrome height). Do not
wrap with a full-screen absorber — see lws-ui `docs/IME.md`.

## Composition with CyberUI

`cyber_ime` depends on `cyber_ui` for frost chrome:
- Panel backdrop: `CyberImeKeyboardBackdrop` → `CyberBackdropBlur`
  - In-page preview: Flutter `BackdropFilter` (realtime)
  - Root Overlay (Weston): `firstFrame` capture via page `CyberBlurBackdropScope`
- Keycaps: translucent `CyberButtonVariant.light` only — **no** per-key blur
- Keycaps: `CyberButton` (`expand: true`) — LIGHT glass letters; PRIMARY Enter;
  LIGHT + accent label for Backspace/Clear (lws-ui `FrostButton` / `ImeKeyCap`)
