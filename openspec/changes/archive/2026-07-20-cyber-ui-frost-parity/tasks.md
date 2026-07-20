## Phase A — Tokens & panel border

- [x] A.1 Extract/expand `CyberGlassTheme` + token classes (colors, dimens, tone) from lws-ui `FrostColors` / `FrostDimens` / `FrostTone`
- [x] A.2 Add panel border/fill primitives used by cards/shells; wire defaults into `CyberCard`
- [x] A.3 Package tests for token defaults; update README module map (tokens/border)

## Phase B — Button + binary controls

- [x] B.1 Upgrade `CyberButton` to Frost button variants / press feedback (keep clickSoundEnabled)
- [x] B.2 Implement `CyberSwitch` with click-sound hook + widget tests
- [x] B.3 Implement `CyberCheckbox` with click-sound hook + widget tests
- [x] B.4 Optional: migrate one Settings toggle row to `CyberSwitch` as smoke
  - `SettingsSwitchRow` now uses `CyberSwitch` (all Settings toggles)

## Phase C — Slider, segmented, stepper

- [x] C.1 Implement core `CyberSlider`; align `CyberVolumeSlider` / flanked APIs on top of it
- [x] C.2 Implement `CyberSegmentedControl` (Settings-ready) + tests
- [x] C.3 Implement `CyberNumericStepper` + tests
- [x] C.4 Optional: migrate Sound Effect page to Cyber segmented if cleaner than ListTile

## Phase D — Capsule, hold-confirm, ripple

- [x] D.1 Implement capsule slider chrome (`CyberCapsuleSlider` or equivalent)
- [x] D.2 Implement hold-to-confirm controller/gesture + widget
- [x] D.3 Implement press / reversible ripple primitives (simplified OK on RK3566)
- [x] D.4 Package smoke tests; README control suite complete for D

## Phase E — Dialog overlay host & capture policy

- [x] E.1 Implement overlay host + panel shell on top of existing `showCyberDialog` / `CyberModal`
- [x] E.2 Wire freeze-during-overlay with `CyberBlurBackdropScope` (page cards freeze; dialog MAY live)
  - Host bumps optional `CyberBackdropBlurController.requestSample` on show/dismiss
- [x] E.3 Prompt/slot content helper if needed for Settings confirms
- [x] E.4 Widget tests for show/dismiss + freeze behavior smoke

## Phase F — Clock API

- [x] F.1 Add Cyber clock appearance tokens + glyph-frost API in `packages/cyber_ui`
- [x] F.2 Migrate App `HomeClock` to consume Cyber clock API (layout may stay in App)
- [x] F.3 Document glyph-clip / realtime limits in package README
- [x] F.4 Home clock regression test / device smoke
  - Navigation tests cover Home clock presence; device via build/push

## Phase G — App adoption & closure

- [x] G.1 Settings sweep: replace Material switches/sliders/segmented/dialogs where Cyber counterparts exist
  - Switches + Sound Effect segmented; Volume already Cyber
- [x] G.2 Monitor: adopt Cyber border/panel where frosted panels still use ad-hoc Material
- [x] G.3 `flutter analyze` + package/App tests; `make build-app` / `make push-app` smoke on ynh960
- [x] G.4 Final README module map; plan §6.3 pointer if needed; `/opsx:archive` when accepted
  - README updated; archive when product accepts (`/opsx:archive`)

## Explicitly excluded

- CyberIME / IME overlays (separate change)
- Android View interop wrappers
- Engineer business page rewrites (controls only unless a smoke row is needed)
