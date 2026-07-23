## Why

Monitor **Machine Status** and **Alarm Information** still render status indicators with legacy mipmap/drawable assets (`check_succeed`, `check_none`, `alarm_status_true/false`, `checkbox_warn_show`). These bitmaps are inconsistent with the FrostUI design system, hard to theme, and cannot share a unified vector-drawn status primitive. A single **four-state** status indicator with **Dot** and **Icon** presentation modes will unify monitor visuals and eliminate redundant image assets at call sites.

## What Changes

- Add **`FrostStatusIndicator`** to `frostui.control`: read-only indicator with four semantic states — **Idle** (gray background), **InProgress** (yellow center dot), **Success** (green), **Failure** (red).
- Indicator size SHALL match monitor footprint (`frost_status_indicator_size` / 36dp).
- Draw a circular **background** with **edge softening / fade** (radial alpha falloff, not a flat stroke).
- **Success** and **Failure** support two visual variants:
  - **Dot**: semantic color on the center dot; background stays neutral gray.
  - **Icon**: semantic color on the background; white checkmark (Success) or cross (Failure) centered inside.
- Provide Compose API (`FrostStatusIndicator`) and XML/Java interop (`FrostStatusIndicatorView`) with `setState` / `setVariant` only (no boolean shortcuts on the component).
- **Machine Status** (`MachineStatusStatusTile`): **Dot** variant; legacy `machineStatusChecked` maps on → Success, off → Idle at the binding adapter.
- **Alarm Information** (`fragment_warn_info.xml`, `CommStatusBindingAdapter`): **Icon** variant; `CommStatusDisplay` three-state semantics unchanged.
- Quick-mode **More Monitor** dialog tiles use the same **Dot** variant as Machine Status.

## Capabilities

### New Capabilities

- `frostui-status-indicator`: Four-state status light primitive (Compose + View interop), appearance tokens, Dot/Icon variants, and binding contracts for monitor screens.

### Modified Capabilities

- `frostui-control-primitives`: Extend control package with read-only `FrostStatusIndicator` alongside existing interactive primitives.
- `alarm-comm-status-platform-display`: Visual rendering switches from checkbox drawables to `FrostStatusIndicator` **Icon** variant; three-state semantics unchanged.
- `offline-alarm-status-readiness`: Visual rendering switches from checkbox drawables to `FrostStatusIndicator` **Icon** variant; readiness gating semantics unchanged.
- `quick-mode-more-monitor-glass-cards`: `MachineStatusStatusTile` indicator swaps to `FrostStatusIndicator` **Dot** variant.

## Impact

- **New sources**: `FrostStatusIndicator.kt`, `FrostStatusIndicatorView.kt`, `frostui_control_*` tokens, `MachineStatusIndicatorMapping.java`.
- **Monitor UI**: `MachineStatusStatusTile.java`, `fragment_machine_status.xml`, `fragment_warn_info.xml`, `fragment_machine_status_dialog.xml`, `CommStatusBindingAdapter.java`, `MachineStatusBindingAdapter.java`.
- **Tests**: state × variant resolve tests; binding adapter mapping tests.
- **No protocol changes**: Modbus alarm bits, `statusReady` / `dataReady` gating, and `CommStatusDisplay` resolution logic remain as-is.
