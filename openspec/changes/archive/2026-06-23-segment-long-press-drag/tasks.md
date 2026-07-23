## 1. Helpers and constants

- [x] 1.1 Add pure functions in `FrostControlLogic.kt`: selected-segment hit rect, preview index/offset from drag X, nearest index on release
- [x] 1.2 Add unit tests for index mapping, clamping, and touchSlop-cancel eligibility

## 2. Long-press drag gesture module

- [x] 2.1 Implement `FrostSegmentLongPressDragGesture.kt` with `isPillExpanded` / `isSelectionArmed` state (mirror slider gesture phases)
- [x] 2.2 Wire 400 ms long-press threshold from `FrostControlDimens.sliderLongPressThresholdMs` and ~150 ms expand before arm
- [x] 2.3 Cancel gesture when pre-long-press horizontal move exceeds `touchSlop`; consume events during armed drag

## 3. FrostSegmentedControl integration

- [x] 3.1 Replace selected-segment-only press handling: keep tap on unselected segments; add long-press drag on selected pill
- [x] 3.2 Animate pill scale (~1.3×) during expand/drag; use unclipped draw so pill is not clipped
- [x] 3.3 Drive label colors from preview index during drag; commit index and animate pill on release only
- [x] 3.4 Play arm/release sounds via `FrostUiClickSoundRegistry` when `clickSoundEnabled` is true

## 4. FrostSegmentedControlView interop

- [x] 4.1 Defer `radioGroup.check` and external listener until selection commits (tap or drag release)
- [x] 4.2 Set `clipChildren=false` on view wrapper if needed for enlarged pill overflow
- [x] 4.3 Verify programmatic `check()` / `applySelectedIndex()` bypass gesture and update immediately

## 5. Verification

- [x] 5.1 Manual QA on `CommonSettingsFragment`: language (2), unit (2), screen-off (4), sound effect (3) — all acceptance criteria
- [x] 5.2 Run unit tests and `make sync` on emulator
