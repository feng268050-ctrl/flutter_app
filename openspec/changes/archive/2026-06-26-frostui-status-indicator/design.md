## Context

Monitor screens currently show device/alarm health with disabled `CheckBox` widgets whose `button` drawable is swapped at runtime via data binding (`checkbox_warn_show`, `check_comm_healthy`, `check_comm_fault`, `check_box_warn_show`). These drawables wrap legacy `@mipmap` assets (`check_succeed`, `check_none`, `alarm_status_true/false`) at 36dp — the same footprint as `FrostCheckbox` (`frost_checkbox_size`).

The new status indicator is **read-only** (no toggle), exposes four semantic states, two presentation variants, and draws a soft-edged circular **background** (not a stroke outline).

Affected surfaces:

| Screen | Component | Target variant | State mapping |
|--------|-----------|----------------|---------------|
| Monitor → Machine Status | `MachineStatusStatusTile` | **Dot** | on → Success (green dot); off → Idle (gray) |
| Monitor → Alarm Information | `FrostStatusIndicatorView` in `fragment_warn_info.xml` | **Icon** | `CommStatusDisplay` → Success / Failure / Idle |
| Quick-mode More Monitor | `MachineStatusStatusTile` dialog variant | **Dot** (same as Machine Status) | same as Machine Status |

`CommStatusDisplay` (Java) already resolves HEALTHY / FAULT / NEUTRAL; no Modbus or readiness logic changes.

## Goals / Non-Goals

**Goals:**

- Ship `FrostStatusIndicator` + `FrostStatusIndicatorView` in `frostui.control` with four states and two variants (Dot / Icon).
- Match monitor indicator footprint (`frost_status_indicator_size`, 36dp).
- Draw a soft-edged circular **background** (radial alpha falloff, not a flat stroke).
- Migrate all Monitor Machine Status and Alarm Information status lights to the new component.
- Map domain signals to `FrostStatusState` at the **binding-adapter layer**; component API is state-only.

**Non-Goals:**

- Interactive/toggle behavior (use `FrostCheckbox`).
- Replacing `FrostCheckbox` in dialogs, safety tips, or settings.
- Deleting legacy mipmap assets in this change (follow-up cleanup).
- Using `InProgress` (yellow) on current Monitor screens — available for boot self-check / OTA follow-ups.
- Backdrop blur sampling inside the indicator (edge softening is local draw-time only).

## Decisions

### 1. Compose-first with `AbstractComposeView` interop

**Choice:** `FrostStatusIndicator` (Compose) + `FrostStatusIndicatorView` (interop), mirroring `FrostCheckboxView`.

**Rationale:** Consistent with existing frostui control pattern; enables unit-tested draw logic without bitmap assets.

### 2. State model and presentation matrix

```kotlin
enum class FrostStatusState { Idle, InProgress, Success, Failure }
enum class FrostStatusVariant { Dot, Icon }
```

| State | Dot | Icon |
|-------|-----|------|
| Idle | gray bg | gray bg |
| InProgress | gray bg + yellow dot | gray bg + yellow dot |
| Success | gray bg + green dot | green bg + white ✓ |
| Failure | gray bg + red dot | red bg + white ✗ |

### 3. Soft background via radial gradient fill

**Choice:** Draw a filled disc with radial gradient alpha falloff at the outer edge (`drawSoftBackground`).

**Rationale:** Matches "边缘虚化" on the **background**, not a stroke ring.

### 4. Token placement

Add to `frostui_control_colors.xml` / `frostui_control_dimens.xml`:

- `frost_status_idle_ring` (gray background), `frost_status_in_progress_dot`, `frost_status_success`, `frost_status_failure`, `frost_status_glyph`
- `frost_status_indicator_size` (36dp), `frost_status_dot_radius`

### 5. `MachineStatusStatusTile` refactor

Replace inner `CheckBox` with `FrostStatusIndicatorView` (**Dot** variant, fixed in tile):

- Tile API: `setIndicatorState(FrostStatusState)` / `getIndicatorState()` — no `setChecked` on the tile or view.
- Legacy XML `app:machineStatusChecked` maps at adapter layer via `MachineStatusIndicatorMapping.fromOnOff()`: **on → Success**, **off → Idle**.
- Optional `app:machineStatusIndicatorState` for full four-state binding.

### 6. Alarm Information binding adapters

Retarget `CommStatusBindingAdapter` to `FrostStatusIndicatorView.setState(...)` with **Icon** variant:

```java
applyDisplay(indicator, CommStatusDisplay state) {
    indicator.setVariant(Icon);
    indicator.setState(switch (state) {
        case HEALTHY -> SUCCESS;
        case FAULT   -> FAILURE;
        case NEUTRAL -> IDLE;
    });
}
```

Layouts: replace `<CheckBox … app:commStatusAlarm=…>` with `<FrostStatusIndicatorView app:frostStatusVariant="icon" …>`.

### 7. Variant selection per screen

| Surface | `FrostStatusVariant` |
|---------|---------------------|
| Machine Status tiles (monitor + dialog) | **Dot** |
| Alarm Information comm + metric tiles | **Icon** |

Expose `app:frostStatusVariant` styleable; default `Dot`.

## Risks / Trade-offs

- **[Risk] Visual parity drift from legacy mipmap icons** → Mitigation: emulator side-by-side for Machine Status dot tiles and Alarm Information check/cross tiles.
- **[Risk] `InProgress` unused on Monitor** → Mitigation: ship in API; bind in boot-self-check follow-up.
- **[Risk] Boolean `machineStatusChecked` only uses two of four states** → Mitigation: document mapping; use `machineStatusIndicatorState` when Failure/InProgress needed.
- **[Risk] Performance with many indicators on Alarm Information scroll** → Mitigation: read-only Compose, invalidate on state change only.

## Migration Plan

1. Implement `FrostStatusIndicator` + tokens + unit tests.
2. Add `FrostStatusIndicatorView` + styleables.
3. Refactor `MachineStatusStatusTile` (Dot variant).
4. Update `fragment_machine_status.xml`, `fragment_machine_status_dialog.xml`.
5. Update `fragment_warn_info.xml` → `FrostStatusIndicatorView` (Icon variant).
6. Retarget `CommStatusBindingAdapter` and `MachineStatusBindingAdapter`.
7. `make sync` on emulator; verify both screens.

## Open Questions

- None blocking — confirm boot-self-check adopts `InProgress` in a follow-up if needed.
