## 1. HAL output layout

- [x] 1.1 Create `output/display/` and `output/sound/` public barrels (`display.dart`, `sound.dart`, nested `backlight` / `auto_sleep` / `volume` / `button_feedback`)
- [x] 1.2 Move existing `Backlight` / `Volume` / `MediaAudioController` Linux backends + stubs into `src/output/display` and `src/output/sound`; update `output.dart` barrel
- [x] 1.3 Remove flat `output/backlight.dart` / `output/volume.dart`; fix all in-tree imports (package tests, App façades, warn-alarm)
- [x] 1.4 Move `DisplayStack` into `sys_info`; delete top-level `display.dart`; update README module map

## 2. AutoSleep

- [x] 2.1 Add portable `AutoSleep` API + policy enum (10 / 30 / 60 min / Never) under `output/display`
- [x] 2.2 Persist policy in `/var/lib/hmi/display.conf` (`auto_sleep`); stub + unit tests
- [x] 2.3 Blank with **absolute** sysfs brightness 0; double-tap wake restores prior logical brightness without writing blank into conf
- [x] 2.4 Wire `AppServices` / board bindings + root activity / double-tap listener

## 3. ButtonFeedback

- [x] 3.1 Add portable `ButtonFeedback` API under `output/sound`: asset key get/set + `play()` via injected media audio
- [x] 3.2 Persist asset key in `/var/lib/hmi/sound.conf` (`button_feedback`); stub + unit tests (sibling keys preserved)
- [x] 3.3 Migrate App `SoundEffectStore` to catalog façade over HAL; click bootstrap calls `ButtonFeedback.play()`
- [x] 3.4 Point Sound Effect settings at `setAssetKey` + preview `play()`

## 4. Common Settings UI

- [x] 4.1 Reorder Display & Sound main group: Language, Unit, Brightness, Screen-off, Volume, Sound Effect
- [x] 4.2 Move RGB LED to a following group after the main Display & Sound card
- [x] 4.3 Wire Screen-off settings page to `AutoSleep` (persist + labels)
- [x] 4.4 Smoke-check Settings navigation still opens LED / brightness / volume / sound-effect pages

## 5. Prefs + verification

- [x] 5.1 Use mouse.conf-style `/var/lib/hmi/display.conf` + `/var/lib/hmi/sound.conf` (keys `backlight` / `auto_sleep` / `volume` / `button_feedback`)
- [x] 5.2 Run `cyber_hal` package tests for backlight/volume/auto-sleep/button-feedback
- [x] 5.3 Run App tests touched by sound-effect / backlight / settings; analyze changed packages
