## 1. Spec constants and helpers

- [x] 1.1 Add `sliderLongPressThresholdMs` (default 400) and `sliderThumbDragScale` (default 1.3) to `frostui_control_dimens.xml`
- [x] 1.2 Add pure functions for thumb center X and hit-rect from fraction (linear + capsule inset variants) in `FrostControlLogic.kt` with unit tests

## 2. Shared long-press drag gesture

- [x] 2.1 Implement `FrostSliderLongPressDragGesture` modifier: thumb hit test, 400 ms long-press timer, `draggingEnabled` state, no tap-to-seek
- [x] 2.2 Wire thumb scale animation (`animateFloatAsState`, ~1.3×) and arm/release `FrostUiClickSoundRegistry` calls
- [x] 2.3 Map `onStartTracking` to arm (post long-press) and `onStopTracking` to release; preserve multi-touch cancel via `SinglePointerTracker`

## 3. FrostSlider integration

- [x] 3.1 Replace `FrostSlider` full-width `pointerInput` with shared gesture; draw scaled thumb circle when armed/dragging
- [x] 3.2 Verify `FrostSliderView` / `AdvancedSettingFragment` bindings unchanged (live value box + persist on release)

## 4. FrostCapsuleSlider integration

- [x] 4.1 Replace `FrostCapsuleSlider` gesture with shared module; thumb hit at fill edge
- [x] 4.2 Show visible logical thumb at fill edge during arm/drag (capsule was invisible before)
- [x] 4.3 Verify `CommonSettingsFragment` brightness row and overlay color interpolation

## 5. Verification

- [x] 5.1 Unit tests: hit rect acceptance, early release no-op, fraction mapping unchanged during drag
- [x] 5.2 Manual QA on emulator: track tap (no jump), short thumb tap, long-press enlarge + drag, release shrink, two sliders same screen
- [x] 5.3 Run `make sync` and exercise advanced settings + common settings brightness sliders
