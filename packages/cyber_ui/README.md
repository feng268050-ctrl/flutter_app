# cyber_ui

Reusable **CyberUI** chrome for LWS HMI (Frosted Glass). Path package under
`packages/cyber_ui` (same pattern as `cyber_hal`).

Prefer **Flutter / Material** structure (`Card`, `Material`/`InkWell`,
`BackdropFilter`) with Frost tokens for color, size, and sampling policy.

## Module map

| Area | API |
|------|-----|
| Tokens / border | `CyberColors`, `CyberDimens`, `CyberTone`, `CyberPanelBorder`, `CyberPanelOutline`, `CyberOutlinedPanel`, `CyberGlassTheme` |
| Blur | `CyberBackdropBlur`, `CyberBlurSampleMode`, intensity/tint, scope/target |
| Chrome | `CyberCard`, `CyberStatusIndicator`, `CyberButton` |
| Controls | `CyberSwitch`, `CyberCheckbox`, `CyberSlider`, `CyberScaledSlider`, `CyberSegmentedControl`, `CyberNumericStepper`, `CyberCapsuleSlider`, `CyberHoldConfirm`, `CyberPressRipple` |
| Audio chrome | `CyberVolumeSlider`, `CyberIconFlankedSlider`, `CyberAudioPlayerCard` |
| Dialog | `showCyberDialog`, `CyberModal`, `CyberOverlayHost`, `CyberPromptContent`, `showCyberUsbOtgModeDialog` / `CyberUsbOtgModeCopy`, `CyberKeyboardAvoidingLift` / `CyberKeyboardInsets` (IME card lift), `CyberLiftedPanel` (raw) |
| Status icons | `CyberCloudStatusIcon` (+ `CyberCloudLinkStatus`), `CyberWifiStatusIcon`, `CyberBluetoothStatusIcon`, `CyberCameraStatusIcon` |
| Clock | `CyberClockAppearance`, `CyberClockNotes` (glyph-clip limits) |
| Sound | `CyberClickSound` + `CyberClickSoundRegistry` |

## Two Gaussian blur schemes

| Scheme | Modes | Engine | Typical use |
|--------|--------|--------|-------------|
| **Realtime Gaussian (default chrome)** | `CyberBlurSampleMode.realtime` | Material `BackdropFilter` + `ImageFilter.blur` | `CyberCard` on Home / live panels |
| **Static sampling (FrostUI)** | `firstFrame`, `onChange`, `followLayout` | Capture via `CyberBlurBackdropScope`; `followLayout` offsets a shared blurred snapshot while scrolling | Dialogs (`firstFrame`); scrollable Settings panels (`followLayout`) |

`CyberBlurIntensity.transparent` = border-only (no blur, no tint overlay) — settings Frost `TRANSPARENT` cards.

Product features must **not** use bare `BackdropFilter` — go through Cyber\* widgets.

## CyberButton variants (Frost `FrostButton`)

| Variant | Frost | Fill | Label |
|---------|-------|------|-------|
| `standard` (**default**) | `DEFAULT` | Dark glass gradient | White |
| `primary` | `PRIMARY` | Solid `#F37535` | White |
| `secondary` | `SECONDARY` | Same as `standard` | `#FF5A52` |
| `light` | `LIGHT` | Light glass gradient | White |

### Size tiers (height fixed; width customizable)

Selecting a tier locks **height** (and default horizontal padding / label size).
Width is not locked — wrap with `SizedBox(width: …)`, use `stretch: true`, or
`expand: true` (IME). Shape: `rectangle` → radius **14**; `rounded` → pill
(`height / 2`). Prefer `CyberButtonSize.small` over deprecated `regular`.

| Size | Height | Rectangle r | Capsule r | Default pad H | Label |
|------|--------|-------------|-----------|---------------|-------|
| `mini` | **38** | 14 | 19 | 20 | **14** |
| `small` (**default**) | **56** | 14 | 28 | 20 | **14** |
| `medium` | **66** | 14 | 33 | 24 | **18** |
| `large` | **80** | 14 | 40 | 28 | **22** |

Stroke remains **1**. Escape hatch: `height:` overrides the tier height for
non-standard chrome (e.g. 36dp chips).

## Sample-mode defaults

- **Chrome** (`CyberCard`, live panels): default **`realtime`**.
- **Dialogs** (`showCyberDialog` / `CyberModal` / overlay host): default **`firstFrame`**.
- Outline: `CyberPanelOutlineStyle.frostGradient` by default (Frost bidirectional); `uniform` for flat `BorderSide`.
- Gradient placement: `CyberBorderGradientCenter` — axis modes use symmetric **H–S–H** `LinearGradient`; diagonal modes use shadow baseline + dual corner `RadialGradient` (radius **0.5 × short side**). Settings lists MUST vary adjacent cards (`settingsCardAt` / lws-ui `app:borderGradientCenter`).

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
tint, tone, border, and corner radius (card corner **28**).

## Consumption

```dart
import 'package:cyber_ui/cyber_ui.dart';
```
