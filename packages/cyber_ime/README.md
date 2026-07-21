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
| Layouts | Keyboard A (QWERTY + `123` + `#+=`), Keyboard B (dedicated numeric) |
| Overlay | `CyberImeOverlay`, `CyberImeKeyboardPanel` |
| Field chrome | `CyberImeTextField` |

## Path wiring

```yaml
# app/hmi/pubspec.yaml
dependencies:
  cyber_ime:
    path: ../../packages/cyber_ime
```

```dart
import 'package:cyber_ime/cyber_ime.dart';
```

Register a language provider at App bootstrap (optional; defaults to English):

```dart
CyberImeLanguageRegistry.register(
  const CyberImeFixedLanguageProvider(CyberImeGlobalKind.english),
);
```

## Keyboard kinds

- **Keyboard A:** QWERTY → primary symbols (`123`) → extended (`#+=`) → `ABC`.
- **Keyboard B:** dedicated pad `1–9 ⌫ / C / - / . 0 00 ⏎` (no `abc` switch).

## ChineseGlobal (deferred)

v1 ships **EnglishGlobal** letter caps only. When the language provider reports
Chinese, EnglishGlobal is still shown until ChineseGlobal assets/layout are
ported from lws-ui (OpenSpec task 3.6). Do not claim Chinese parity in product
docs until that task is done.

## Fonts / assets

v1 uses Material / system fonts for key caps. No bundled IME font yet; add
under `packages/cyber_ime/assets/` when ChineseGlobal lands.

## Hit-testing

The overlay touch host is **panel-sized only** (keyboard chrome height). Do not
wrap with a full-screen absorber — see lws-ui `docs/IME.md`.

## Composition with CyberUI

`cyber_ime` depends on `cyber_ui` for frost chrome:
- Panel backdrop: `CyberBackdropBlur` (realtime Gaussian)
- Keycaps: `CyberButton` (`expand: true`) — LIGHT glass letters; PRIMARY Enter;
  LIGHT + accent label for Backspace/Clear (lws-ui `FrostButton` / `ImeKeyCap`)
