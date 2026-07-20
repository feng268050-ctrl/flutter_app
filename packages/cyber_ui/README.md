# cyber_ui

Reusable **CyberUI** chrome for LWS HMI (Frosted Glass). Path package under
`packages/cyber_ui` (same pattern as `cyber_hal`).

## Module map

| Area | API |
|------|-----|
| Blur | `CyberBackdropBlur`, `CyberBlurSampleMode`, intensity/tint, scope/target |
| Chrome | `CyberCard`, `CyberStatusIndicator`, `CyberButton` |
| Audio chrome | `CyberVolumeSlider`, `CyberIconFlankedSlider`, `CyberAudioPlayerCard` |
| Modal | `showCyberDialog` / `CyberModal` |
| Sound | `CyberClickSound` + `CyberClickSoundRegistry` |
| Theme | `CyberGlassTheme` (`ThemeExtension`) |

## Sample-mode defaults

- **Chrome** (`CyberCard`, live panels): default **`CyberBlurSampleMode.realtime`**.
- **Dialogs** (`showCyberDialog` / `CyberModal`): default **`firstFrame`** (MAY stay frozen while open).
- Product features must **not** use bare `BackdropFilter` — go through Cyber\* widgets.

See plan §6.3 and OpenSpec `p3-0-cyber-ui` (chrome realtime override vs older “frozen default” wording).

## Click SFX

1. App registers a `CyberClickSound` backend at bootstrap (Linux/asset clip).
2. `CyberCard` / `CyberButton` call `CyberClickSoundRegistry.playClick()` when
   `clickSoundEnabled` is true (default).
3. Unregistered → no-op. **Media volume** remains `cyber_hal` / Settings.
4. Product Apps MAY select among multiple click samples via App prefs
   (lws-hmi: `/var/lib/hmi/sound-effect`, index `0..2`). Registry stays
   index-free — sample choice lives in the App backend.

## Theme seam

Optional `ThemeData.extensions: [CyberGlassTheme(...)]` for default intensity,
tint, border, and corner radius. Widgets fall back to package defaults.

## Consumption

```dart
import 'package:cyber_ui/cyber_ui.dart';
```

Glyph-clipped clock frost stays an **App** composition concern until a stable
Cyber clock API exists.
