## Context

`FrostSlider` and `FrostCapsuleSlider` currently use `awaitEachGesture` + `awaitFirstDown` on the full touch height. On pointer down they immediately call `applyX(down.position.x)`, which implements tap-to-seek anywhere on the track. This matches legacy `ScaledSeekBar` behavior but is unsafe on a factory HMI where accidental taps jump temperature thresholds and offsets.

Both sliders already expose `onStartTracking` / `onStopTracking` and pass `fromUser=true` through `onProgressChange` during drag. Advanced settings relies on live value-box updates while dragging and persistence on release (`advanced-settings-persistence` spec).

## Goals / Non-Goals

**Goals:**

- Eliminate tap-to-seek: track clicks never change value.
- Thumb-only arming: pointer down must hit the thumb region (visible circle for linear slider; logical thumb at fill edge for capsule slider).
- Long-press (~400 ms) on thumb arms drag (`draggingEnabled=true`), plays arm sound, scales thumb ~1.3×.
- While armed, horizontal move updates value continuously using existing fraction math.
- Pointer up/cancel disarms, restores thumb scale, plays release sound; early release before threshold leaves value unchanged.
- Isolated per-slider state when multiple sliders are on screen.
- Reuse `FrostUiClickSoundRegistry` for arm and release cues.

**Non-Goals:**

- Changing `FrostFlankedSliderView` / video playback seek bar (out of scope unless it shares the same Compose primitive later).
- Haptic feedback (not requested).
- Accessibility TalkBack-specific affordances beyond standard semantics (follow-up if needed).
- Opt-out flag to restore tap-to-seek (intentionally removed).

## Decisions

### 1. Shared gesture module: `FrostSliderLongPressDragGesture`

Extract a single `Modifier.frostSliderLongPressDrag(...)` (or internal helper) used by both `FrostSlider` and `FrostCapsuleSlider`.

**State machine per gesture:**

| Phase | Condition | Action |
|-------|-----------|--------|
| Idle | — | `draggingEnabled=false`, thumb scale 1.0 |
| Thumb down | down in thumb hit rect | start long-press timer; do not change value |
| Early up | up before threshold | cancel timer; no value change; no sound |
| Armed | timer elapsed | `draggingEnabled=true`; scale thumb; play arm sound; call `onStartTracking` |
| Dragging | armed + move | update fraction from X; `onProgressChange(..., fromUser=true)` |
| Release | up/cancel while armed | `draggingEnabled=false`; restore scale; play release sound; call `onStopTracking` |

**Rationale:** One implementation avoids drift between linear and capsule variants.

**Alternative considered:** Per-composable duplicate logic — rejected (maintenance risk).

### 2. Long-press threshold: 400 ms

User acceptance cites ~400 ms. Store as `FrostControlDimens.sliderLongPressThresholdMs` (default 400) for tuning without code change.

**Alternative:** 300 ms — too easy to trigger accidentally on HMI panels.

### 3. Thumb scale: 1.3× (within 1.25–1.4 range)

Animate with `animateFloatAsState` (~150 ms, same family as switch animation). Capsule slider draws a visible logical thumb circle at the fill edge during arm/drag (currently invisible) OR scales the fill-edge indicator — prefer **visible overlay circle** at fill edge matching linear thumb diameter so operators see what they long-pressed.

### 4. Thumb hit testing

**Linear (`FrostSlider`):**

- Compute thumb center from current display fraction (not jump on down).
- Hit rect = thumb center ± max(thumbRadius, minTouchTarget/2) clamped to touch height.

**Capsule (`FrostCapsuleSlider`):**

- Logical thumb at fill edge: X = inset + fillWidth, Y = center.
- Same hit rect using capsule height as touch dimension.
- Clicks on value text / trailing icon area do not arm unless within thumb hit rect.

**Rationale:** Matches requirement 8 — only thumb region starts gesture.

### 5. No tap-to-seek

Remove initial `applyX(down.position.x)` on down. Track clicks outside thumb hit rect are ignored entirely (no consume unless needed to block parent scroll).

### 6. Sound cues

- **Arm (long-press threshold reached):** `FrostUiClickSoundRegistry.playClick()` — same registry as other controls.
- **Release (after armed drag ends):** `FrostUiClickSoundRegistry.playClick()` once on pointer up.

Remove prior "click on start tracking" if it would double-fire with arm sound. Short tap on thumb: silent.

**Alternative:** Distinct sound assets — not available in frostui; registry only exposes one click today.

### 7. Multi-slider isolation

Gesture state (`draggingEnabled`, scale, drag fraction) lives in `remember { }` inside each composable instance — no static/shared holder.

### 8. Existing callbacks

- `onStartTracking`: invoke when transitioning to armed (after long-press), not on raw pointer down.
- `onStopTracking`: invoke on pointer up only if drag was armed; pass `cancelled=true` if multi-touch broke gesture (preserve existing `SinglePointerTracker` behavior).

## Risks / Trade-offs

- **[Risk] Slower interaction for expert users** → Acceptable for safety; operators drag from current thumb position only.
- **[Risk] Capsule slider had invisible thumb — users may not know where to press** → Show scaled thumb indicator at fill edge during arm/drag; document in release notes.
- **[Risk] Long-press conflicts with parent scroll** → `requestDisallowInterceptTouchEvent(true)` only after arm, not on initial down.
- **[Risk] Value box in advanced settings stops updating on track tap** → By design; only armed drag updates.

## Migration Plan

1. Implement shared gesture + update both Compose sliders.
2. Add/update unit tests for hit rect and fraction mapping (no change to math).
3. Manual QA: advanced settings (multiple sliders), common settings brightness.
4. Rollback: revert gesture module to restore tap-to-seek if critical regression.

## Open Questions

- None blocking — arm/release both use existing click sound unless product requests distinct assets later.
