## Why

`p3-0-cyber-ui` shipped a single click sample and a registry stub, but Settings still has a placeholder Sound Effect page (`Default`/`Soft`/`Off`, not persisted) and Material volume/player chrome instead of lws-ui Frost volume + audio-player cards. Product parity needs Effect 1/2/3 selection with persistence, Cyber volume chrome wired to `cyber_hal` media volume, and a reusable audio-player card for Demo/Settings preview — without bloating CyberUI with ALSA.

## What Changes

- Bundle all three lws-ui click assets (`click_mp3_2` / `click_mp3` / `click_mp3_1` → Effect 1/2/3) and play the **active index** from the App click backend registered into `CyberClickSoundRegistry`.
- Persist sound-effect index (0–2) in a product prefs store aligned with lws-ui `SoundEffectSettings` / `CommonSettings.soundEffect`; Settings UI shows segmented Effect 1/2/3, preview on change via `openEffect`-equivalent.
- Add CyberUI **volume chrome**: icon-flanked slider (Frost `FrostIconFlankedSlider` / `FrostVolumeControl` stand-in) for Settings Volume page; keep level apply/persist in `cyber_hal` `MediaAudioController`.
- Add CyberUI **`CyberAudioPlayerCard`** (Frost `FrostAudioPlayerCard` stand-in: transport + seek + time labels); **Settings Volume** (preview / play-test) consumes it with App-owned `MediaAudioController` — package stays presentation-only. (Product Demo MUST NOT re-own volume/play per `p2-device-demo-ui`.)
- Extend App click backend so active effect index selects among three assets (registry still only calls `playClick()`; index lives in App/settings store).

## Capabilities

### New Capabilities

- `cyber-audio-chrome`: CyberUI volume slider chrome + audio player card widgets (presentation); App wires HAL audio on Settings Volume.
- `settings-sound-effect`: Settings Sound Effect index 0–2 (Effect 1/2/3), persistence, preview playback, and App click backend selection of the three assets.

### Modified Capabilities

- `settings-ui`: Sound-effect row MUST be real (not stub); Volume page SHALL use Cyber volume chrome (+ optional player card for play-test); Display & Sound no longer treats sound-effect as optional stub.
- `cyber-ui`: Document that App click backends honor persisted effect index; registry API unchanged (`playClick` only).
- `linux-settings-persist`: Document sound-effect index preference under `/var/lib/hmi/`.

## Impact

- **App:** `assets/audio/click_*.mp3` (three files); prefs for sound-effect index; rewrite `SoundEffectSettingsPage` + `VolumeSettingsPage`; bootstrap click backend reads active index.
- **Package:** `packages/cyber_ui` gains volume/player widgets; possibly thin `CyberSlider` primitive if needed for both.
- **HAL:** unchanged volume API; click SFX remains App asset playback (may use dedicated short-clip path to avoid interrupting media).
- **Out of scope:** Warn/alarm looping sound (`warn_mp3`); full Frost slider gesture parity (long-press drag MAY be deferred); CyberIME; Effect “Off” as fourth option unless product asks (lws-ui Common Settings is three effects only).
- **Reference:** lws-ui `FrostUiClickSoundRegistry` ← `FrostUiDialogBridge.register(GlobalSoundManager::playClickSound)`; `SoundEffectSettings` + `GlobalSoundManager.openEffect` / `playClickSound`.
