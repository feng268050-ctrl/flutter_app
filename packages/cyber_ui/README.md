# cyber_ui

Reusable **CyberUI** chrome for LWS HMI (Frosted Glass). Path package under
`packages/cyber_ui` (same pattern as `cyber_hal`).

## Module map

| Area | API |
|------|-----|
| Tokens / border | `CyberColors`, `CyberDimens`, `CyberTone`, `CyberPanelBorder`, `CyberGlassTheme` |
| Blur | `CyberBackdropBlur`, `CyberBlurSampleMode`, intensity/tint, scope/target |
| Chrome | `CyberCard`, `CyberStatusIndicator`, `CyberButton` |
| Controls | `CyberSwitch`, `CyberCheckbox`, `CyberSlider`, `CyberSegmentedControl`, `CyberNumericStepper`, `CyberCapsuleSlider`, `CyberHoldConfirm`, `CyberPressRipple` |
| Audio chrome | `CyberVolumeSlider`, `CyberIconFlankedSlider`, `CyberAudioPlayerCard` |
| Dialog | `showCyberDialog`, `CyberModal`, `CyberOverlayHost`, `CyberPromptContent`, `CyberKeyboardAvoidingLift` / `CyberKeyboardInsets` (IME card lift), `CyberLiftedPanel` (raw) |
| Clock | `CyberClockAppearance`, `CyberClockNotes` (glyph-clip limits) |
| Sound | `CyberClickSound` + `CyberClickSoundRegistry` |

## Sample-mode defaults

- **Chrome** (`CyberCard`, live panels): default **`CyberBlurSampleMode.realtime`**.
- **Dialogs** (`showCyberDialog` / `CyberModal` / overlay host): default **`firstFrame`**.
- Product features must **not** use bare `BackdropFilter` — go through Cyber\* widgets.

See plan §6.3 and OpenSpec `p3-0-cyber-ui` / `cyber-ui-frost-parity`.

## Click SFX

1. App registers a `CyberClickSound` backend at bootstrap (Linux/asset clip).
2. Interactive Cyber controls call `CyberClickSoundRegistry.playClick()` when
   `clickSoundEnabled` is true (default).
3. Unregistered → no-op. **Media volume** remains `cyber_hal` / Settings.
4. Product Apps MAY select among multiple click samples via App prefs
   (lws-hmi: `/var/lib/hmi/sound-effect`, index `0..2`).

## Clock / glyph frost

`CyberClockAppearance` holds Home clock tokens. **True glyph-clipped live blur
is not fully supported on RK3566** (`CyberClockNotes.glyphClipLiveBlurSupported
== false`); Apps approximate with rectangular blur + fill overlays.

## Theme seam

Optional `ThemeData.extensions: [CyberGlassTheme(...)]` for default intensity,
tint, tone, border, and corner radius.

## Consumption

```dart
import 'package:cyber_ui/cyber_ui.dart';
```
