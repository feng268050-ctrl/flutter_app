## Why

`cyber_hal`’s `hal/output` domain today is a flat `{backlight, volume}` pair, while Common Settings already mixes display, sound, locale stubs, and RGB LED in one card. Nesting **display** (Backlight + AutoSleep) and **sound** (Volume + ButtonFeedback) under `output` aligns the HAL with how operators think about the UI, makes screen-off and click-feedback first-class portable APIs (today: Screen-off stub; sound-effect App-only store), and lets RGB LED sit outside that grouped card without implying it is a HAL output level.

## What Changes

- **BREAKING (import layout):** Restructure `package:cyber_hal/output` into two submodules:
  - **display** — `Backlight`, `AutoSleep`
  - **sound** — `Volume`, `ButtonFeedback`
- **BREAKING:** Move **DisplayStack** / `DisplayStackProbe` into `package:cyber_hal/sys_info.dart` and **remove** top-level `display.dart` (eliminates clash with `output/display`).
- Add portable **`AutoSleep`** API; blank writes **absolute sysfs brightness 0** (panel off); **double-tap** wakes and restores prior logical brightness; persist in `/var/lib/hmi/display.conf` (key `auto_sleep`).
- Promote click SFX into portable **`ButtonFeedback`** under `output/sound`: persist **selected asset key**, and **`play()` via injected media/audio HAL**. App UI selects among product assets; CyberUI registry only forwards to `ButtonFeedback.play()`.
- Relocate existing `Backlight` / `Volume` (+ Linux backends / stubs) under the new submodule paths; provide short-lived re-exports or App façade updates so product code imports the nested layout.
- **Common Settings:** Reorder Display & Sound rows to match display-then-sound (brightness + screen-off, then volume + sound/button feedback); **move RGB LED to after the Display & Sound `SettingsGroup`** (still under that section header, not inside the inset card with brightness/volume).
- Relocate output preference files as `/var/lib/hmi/display.conf` and `/var/lib/hmi/sound.conf` (no legacy basename aliases).
- Update package README / module map and `dart-hal` grouping vocabulary accordingly.

## Capabilities

### New Capabilities

- `hal-auto-sleep`: Portable `AutoSleep` — policy persist; absolute-0 blank; double-tap wake; Settings Screen-off Time.
- `hal-button-feedback`: Portable `ButtonFeedback` — selected asset key persist + `play()` through media audio HAL; App UI catalogs assets.

### Modified Capabilities

- `dart-hal`: `hal/output` grouping becomes `{display: backlight, auto-sleep}` + `{sound: volume, button-feedback}`; DisplayStack vocabulary moves under `hal/sys_info` (no top-level `hal/display`).
- `settings-ui`: Display & Sound card contents follow display/sound HAL mapping; RGB LED entry MUST appear **after** the Display & Sound settings group (not as a mid-card row among brightness/volume).
- `settings-sound-effect`: Settings catalog stays Effect 1/2/3; persistence is HAL `ButtonFeedback` **asset key** in `sound.conf` (no integer index file; no legacy alias).
- `linux-settings-persist`: Document AutoSleep + ButtonFeedback as `/var/lib/hmi/display.conf` and `/var/lib/hmi/sound.conf`.
- `linux-backlight` / `linux-media-audio` / `shell-hw-persist` / `os-path-layout`: Preference files are `/var/lib/hmi/display.conf` and `/var/lib/hmi/sound.conf`.

## Impact

- **Package `packages/cyber_hal`:** New `src/output/display/*` and `src/output/sound/*` (or equivalent); barrel `output.dart` + `output/display.dart` + `output/sound.dart`; move `LinuxSysfsBacklight` / `LinuxMediaAudioController` / stubs; tests + README.
- **App `app/hmi`:** Import / façade updates; `CommonSettingsTab` reorder + RGB LED placement; Screen-off page ↔ `AutoSleep`; Sound Effect / click bootstrap ↔ `ButtonFeedback` (retire or wrap `SoundEffectStore`).
- **Specs:** `dart-hal`, `settings-ui`, `settings-sound-effect`, `linux-settings-persist` deltas; new `hal-auto-sleep` / `hal-button-feedback`.
- **Out of scope:** Changing RGB LED GPIO API; warn/alarm looping audio; language/unit platform stores; Android backends; bundling click MP3s inside `cyber_hal`.
