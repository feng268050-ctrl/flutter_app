## 1. Resources and tokens

- [x] 1.1 Extend `frostui_control_colors.xml`, `frostui_control_dimens.xml`, `frostui_control_attrs.xml` with capsule segmented and capsule slider tokens (from `control_capsule`, `radiobutton_*`, `capsule_seekbar_*`)
- [x] 1.2 Add `FrostSegmentedAppearance` and `FrostCapsuleSliderAppearance` data classes + default resolvers in `FrostControlAppearance.kt`

## 2. FrostSegmentedControl

- [x] 2.1 Implement `FrostSegmentedControl` Compose (capsule chrome, equal-width segments, tap selection, click sound)
- [x] 2.2 Implement `FrostSegmentedControlView` interop (`setOptions`, `get/setSelectedIndex`, `setOnSegmentSelectedListener`, suppress listener flag)
- [x] 2.3 Add `FrostControlAttrs.readSegmented` and XML style `FrostSegmentedControl`
- [x] 2.4 Unit tests: selection index, listener suppress, segment count edge cases

## 3. FrostCapsuleSlider

- [x] 3.1 Port `overlayDarkFraction` / `blendOverlayColor` to `frostui.control` helpers with unit tests
- [x] 3.2 Implement `FrostCapsuleSlider` Compose (filled capsule track, transparent thumb, drag gestures, built-in value label + trailing icon overlay colors)
- [x] 3.3 Implement `FrostCapsuleSliderView` interop (SeekBar-compatible API, trailing icon, value formatter)
- [x] 3.4 Add `FrostControlAttrs.readCapsuleSlider` and XML style `FrostCapsuleSlider`

## 4. Layout migration (fragment_common_settings)

- [x] 4.1 Replace language row: `ControlCapsule` + `RadioGroup` → `FrostSegmentedControlView`
- [x] 4.2 Replace unit row → `FrostSegmentedControlView`
- [x] 4.3 Replace screen-off time row (4 options) → `FrostSegmentedControlView`
- [x] 4.4 Replace sound effect row (3 options) → `FrostSegmentedControlView`
- [x] 4.5 Replace brightness row: `ControlCapsule` + `SeekBar` + overlays → `FrostCapsuleSliderView`

## 5. Java bindings and cleanup

- [x] 5.1 Update `CommonSettingsFragment`: **保持** `check(R.id.*)` / `OnCheckedChangeListener` 调用方式；亮度改用 `FrostCapsuleSliderView`；删除 `updateBrightnessOverlayColors` 及 layout listeners
- [x] 5.2 Delete `ControlCapsule.java`; grep verify zero production references
- [x] 5.3 Confirm `ScreenDisplayFragment` + `fragment_screen_display.xml` unused → delete or document as dead code

## 6. Verification

- [x] 6.1 Run `:app:testDebugUnitTest` for `frostui.control.*`
- [x] 6.2 `ADB_SERIAL=emulator-5554 SKIP_BUNDLED_FETCH=1 make sync`; manually verify common settings segmented + brightness interactions
