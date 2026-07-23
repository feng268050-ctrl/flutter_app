## Why

Industrial HMI sliders are used for safety-critical parameters (temperature thresholds, offsets, brightness). The current `FrostSlider` and `FrostCapsuleSlider` treat any tap on the track as tap-to-seek, which causes accidental value jumps on a touch panel. Operators need deliberate, thumb-only interaction: long-press to arm drag, then move to change value.

## What Changes

- Remove tap-to-seek on all frostui linear and capsule sliders: track clicks do not change `value`.
- Require pointer down on the thumb hit region; short tap on thumb does nothing.
- After long-press (~400 ms) on thumb, play arm sound, animate thumb scale to ~1.3×, set `draggingEnabled = true`.
- Only while `draggingEnabled`, horizontal move updates progress; release restores thumb scale, plays release sound, clears `draggingEnabled`.
- Release before long-press threshold leaves value unchanged.
- Pointer down outside thumb hit region is ignored (no drag, no value change).
- Per-slider gesture state so multiple sliders on one screen do not interfere.
- **BREAKING (interaction)**: Users can no longer jump to a value by tapping the track; they must long-press the thumb and drag.

## Capabilities

### New Capabilities

- `slider-long-press-drag`: Long-press-to-arm thumb drag interaction, hit testing, scale animation, and sound cues for frostui sliders.

### Modified Capabilities

- `frostui-control-primitives`: `FrostSlider` gesture and acceptance criteria change from immediate track seek to long-press thumb drag only.
- `frostui-capsule-controls`: `FrostCapsuleSlider` gesture rules align with the same long-press thumb drag model (capsule has no visible thumb but uses equivalent thumb hit region).
- `frostui-framework`: Click/arm sound policy extended to slider long-press arm and drag-release feedback via `FrostUiClickSoundRegistry`.

## Impact

- **Compose**: `FrostSlider.kt`, `FrostCapsuleSlider.kt`, shared gesture helper (new or extracted).
- **Interop**: `FrostSliderView`, `FrostCapsuleSliderView` — no public API break; behavior change only.
- **Tests**: `FrostControlLogicTest.kt` plus new gesture/state unit tests for hit region and fraction mapping during drag.
- **Call sites**: Advanced settings (`AdvancedSettingFragment`), common settings brightness (`FrostCapsuleSliderView`) — `onStartTracking` / `onStopTracking` semantics unchanged (still fire when drag session starts/ends after long-press arms).
- **Resources**: Optional dimens for `longPressThresholdMs`, thumb scale factor, expanded touch target.
