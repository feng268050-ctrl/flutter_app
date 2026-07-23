## Context

`DeviceModelConfig` already loads `focus_scale_ref` from `/system/etc/model.properties` and exposes the effective signed integer through `getFocusScaleRef()`. That value is currently used by the laser reminder illustration, but Settings Device Information does not show it and remote snapshots do not serialize it.

Device Information rows are data-bound from `DeviceInfoViewModel.liveData`, backed by `DeviceInfo`. WebSocket `command.stat_response` and `device.online` are both built from `DeviceStatusPut.packRemoteSnapshot()`, whose `deviceInfo` object already carries transient ROM-derived fields such as `cameraIp` and `hostIp`.

## Goals / Non-Goals

**Goals:**

- Show the effective focus scale reference on Settings Device Information.
- Serialize the same value as `deviceInfo.focusScaleRef` in the shared remote snapshot so `command.stat_response` and `device.online` stay aligned.
- Keep the value sourced from `DeviceModelConfig.getFocusScaleRef()` at runtime.

**Non-Goals:**

- Do not change how `focus_scale_ref` is loaded, defaulted, or validated.
- Do not persist `focusScaleRef` in Room or add a database migration.
- Do not change laser reminder image selection.

## Decisions

- Add a transient `Integer`/`int`-style property to `DeviceInfo` named `focusScaleRef`.
  - Rationale: Device Information data binding and snapshot serialization already flow through `DeviceInfo`, and this matches transient fields such as `cameraVersion`, `cameraIp`, and `hostIp`.
  - Alternative considered: Add a standalone view-model property and a custom snapshot map entry. That would duplicate sourcing logic and make UI/API drift more likely.

- Populate `focusScaleRef` from `DeviceModelConfig.getFocusScaleRef()` in the same assembly paths that populate other ROM-derived `DeviceInfo` fields.
  - Rationale: `DeviceModelConfig` owns fallback behavior (`0` for missing/invalid values), so consumers should not parse ROM files or env names directly.
  - Alternative considered: Read `FOCUS_SCALE_REF` directly. That environment variable is only a developer/CI input for writing `model.properties`, not a runtime app source.

- Display the Settings row as a plain signed integer string.
  - Rationale: The source value is numeric and can be negative, zero, or positive. No localization or unit conversion is needed.
  - Alternative considered: Hide `0` as unset. Existing config semantics treat absent/invalid values as `0`, and operators need to see the effective value.

## Risks / Trade-offs

- Additive WebSocket field may be ignored by older consumers -> Mitigation: serialize it inside existing `deviceInfo` as an additive scalar and keep current fields unchanged.
- UI binding could show a default Java numeric value before data load -> Mitigation: populate the value in the same defaults path that always sets model/version fields for Device Information.
- Room schema churn from adding fields to `DeviceInfo` -> Mitigation: mark the field ignored/transient, consistent with existing non-persisted runtime-only fields.
