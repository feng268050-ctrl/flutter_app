## Why

`FrostSegmentedControl` in common settings (language, unit, screen-off time, sound effect) only supports tap-to-select. On a factory touch panel, operators need the same deliberate interaction model as `FrostSliderView`: long-press the active segment pill, enlarge, then drag to the target option—reducing accidental switches when brushing across the control.

## What Changes

- Keep **tap** on an unselected segment for immediate selection (with existing click sound when enabled).
- Add **long-press drag** on the **currently selected** segment pill: ~400 ms hold → pill scale up (~1.3×) → horizontal drag moves the pill preview → release snaps to nearest segment and commits selection.
- Pointer down on the selected segment MUST NOT change selection until release after a successful drag session.
- Horizontal movement before enlarge completes MUST NOT change selection; movement beyond `touchSlop` before long-press succeeds MUST cancel the gesture.
- Split gesture state (`isPillExpanded` / `isSelectionArmed`) mirroring `FrostSliderLongPressDragState`; selection commits only while armed and on release (or via tap on another segment).
- Reuse `FrostUiClickSoundRegistry` for arm and release feedback; reuse existing long-press threshold dimen (`frost_slider_long_press_threshold_ms`, 400 ms default).
- **Non-breaking (tap preserved)**: Unselected segment taps behave as today.

## Capabilities

### New Capabilities

- `segment-long-press-drag`: Long-press-to-arm drag on the selected segment pill, preview follow, nearest-segment commit on release, touchSlop cancel, and sound cues for `FrostSegmentedControl`.

### Modified Capabilities

- `frostui-capsule-controls`: `FrostSegmentedControl` / `FrostSegmentedControlView` interaction requirements extend from tap-only to tap + long-press drag on the selected pill.
- `frostui-framework`: Click-sound policy covers segment long-press arm and drag-release when `frostClickSoundEnabled` is true.

## Impact

- **Compose**: `FrostSegmentedControl.kt`, new `FrostSegmentLongPressDragGesture.kt` (or shared patterns from slider gesture module).
- **Interop**: `FrostSegmentedControlView` — no public API break; `check(R.id.*)` and `OnCheckedChangeListener` fire only on committed selection (tap or drag release).
- **Call sites**: `fragment_common_settings.xml` (4 controls) — verify language, unit, screen-off, sound-effect rows.
- **Tests**: Pure functions for segment index from drag X, hit rect on selected pill, early-cancel rules; manual QA on emulator.
- **Resources**: Optional dimen for segment pill drag scale (may reuse `frost_slider_thumb_drag_scale_tenths`).
