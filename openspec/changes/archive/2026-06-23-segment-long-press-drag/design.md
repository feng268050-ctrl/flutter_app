## Context

`FrostSegmentedControl` renders a sliding selected pill (`slideIndex` animation) and per-segment `frostSingleFingerClickable` on **unselected** cells only (`enabled = enabled && !selected`). Tapping an unselected option plays click sound (when enabled) and calls `onSelectedIndexChange`.

`FrostSliderView` already implements long-press thumb drag via `FrostSliderLongPressDragGesture.kt`: thumb hit test, 400 ms threshold, 150 ms expand animation, `isThumbExpanded` / `isValueArmed` split, delta-based value updates only after arm, `touchSlop` cancel before long-press, arm/release sounds.

Common settings uses four `FrostSegmentedControlView` instances (2–4 options). `FrostSegmentedControlView` keeps hidden `RadioButton` children for `check(R.id.*)` compatibility; listeners must fire only on committed selection.

## Goals / Non-Goals

**Goals:**

- Preserve tap-to-select on **unselected** segments (acceptance #1).
- Press on **selected** segment does not commit a new index on down (acceptance #2).
- Before pill enlarge: horizontal move does not change selection; move > `touchSlop` before long-press cancels gesture (acceptance #3, #7).
- Long-press ~400 ms on selected pill → scale ~1.3× (acceptance #4).
- After expand animation: drag moves pill preview with finger; text colors follow preview index (acceptance #5).
- Release commits nearest segment index; animate pill to final slot; notify listener once (acceptance #6).
- Reuse slider long-press threshold dimen and click-sound registry patterns.
- Per-control isolated gesture state.

**Non-Goals:**

- Long-press drag starting from an unselected segment (tap remains the path to select it first).
- Magnetic snapping mid-drag between segments (preview is continuous; commit on release only).
- Changes to `FrostSlider` / `FrostCapsuleSlider` behavior.
- Haptics or TalkBack-specific drag affordances (follow-up).

## Decisions

### 1. Gesture module: `FrostSegmentLongPressDragGesture`

New `Modifier.frostSegmentLongPressDragGesture(...)` parallel to the slider module.

| Phase | Condition | Action |
|-------|-----------|--------|
| Idle | — | `isPillExpanded=false`, `isSelectionArmed=false` |
| Selected pill down | down in selected-segment hit rect | start 400 ms timer; do not change `selectedIndex` |
| Early up | up before threshold, movement ≤ slop | no selection change; no sound |
| Slop cancel | move > `touchSlop` before threshold | cancel gesture; no selection change |
| Expanded | timer elapsed | `isPillExpanded=true`; play arm sound |
| Armed | expand animation complete (~150 ms) | `isSelectionArmed=true`; record `activationX` |
| Dragging | armed + move | update `dragPreviewIndex` from X (continuous pill offset); no listener yet |
| Release | up after armed | commit `nearestIndex(dragPreviewIndex)`; play release sound; `onSelectedIndexChange`; clear state |

**Rationale:** Matches proven slider state machine; avoids accidental selection during approach.

### 2. Hit region: selected segment cell only

Hit rect = selected segment bounds (full cell width × control height inside inset), not the outer capsule chrome.

**Rationale:** Aligns with “hold current selected segment”; unselected cells remain tap targets via separate clickable layer.

### 3. Layering: tap vs drag

- **Row layer**: unselected segments keep `frostSingleFingerClickable` for tap (unchanged).
- **Overlay gesture**: full-width `pointerInput` on selected pill `Box` (or parent) handles long-press drag; consumes events only after long-press arms to avoid stealing taps on neighbors.

Pointer down on selected segment MUST NOT route to unselected tap handlers.

### 4. Preview index math

`segmentWidth = trackWidth / optionCount`

During drag: `previewOffsetX = segmentWidth * selectedIndex + (currentX - activationX)` clamped to `[0, trackWidth - segmentWidth]`

`previewIndex = round(previewOffsetX / segmentWidth)` clamped to option indices.

On release: commit `previewIndex` if different from start, else no-op listener.

### 5. Visual: scale selected pill during expand/drag

Reuse `frost_slider_thumb_drag_scale_tenths` (1.3×) with `animateFloatAsState` (~150 ms). Apply scale on the sliding pill `Box` only during `isPillExpanded`. Use `frostSliderDrawUnclipped()` (or equivalent) on parent so scaled pill is not clipped.

Text color crossfade uses **preview** index during drag, committed index after release.

### 6. Sound

When `clickSoundEnabled`: arm sound at long-press threshold; release sound after committed drag. Tap on unselected keeps existing single click on select. No sound on slop-cancel or short press on selected pill.

### 7. Interop contract

`FrostSegmentedControlView.setSelectedIndexInternal(..., notify=true)` only when selection **commits** (tap or drag release). During drag preview, update Compose state only; defer `radioGroup.check` until commit.

`applySelectedIndex` / programmatic `check()` remain immediate without gesture.

## Risks / Trade-offs

- **[Risk] Gesture conflict between tap and long-press on adjacent segments** → Keep tap on unselected only; selected cell uses drag gesture; verify 4-option screen-off row at 56dp height.
- **[Risk] Pill scale clips at capsule inset** → `clipChildren=false` on `FrostSegmentedControlView` wrapper; vertical overflow padding like slider.
- **[Risk] Drag feels redundant when only 2 options** → Acceptable; same pattern across all segment counts for consistency.
- **[Trade-off] Two-step change (tap then drag) for distant jumps** → Operators can still tap unselected segment directly.

## Migration Plan

1. Implement gesture + compose integration behind existing APIs.
2. Unit-test index mapping and hit rect helpers.
3. Manual QA on `CommonSettingsFragment` four rows.
4. `make sync` to emulator.

Rollback: revert compose/gesture files; tap-only behavior restored.

## Open Questions

- None blocking; reuse slider threshold/scale dimens unless UX requests segment-specific values later.
