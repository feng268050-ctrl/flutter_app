## Why

Operators and support tools need to see the configured gun-head focus scale reference in the same places they inspect other device identity/configuration details. The value already exists in ROM model configuration via `FOCUS_SCALE_REF` / `focus_scale_ref`, but it is not currently visible on Settings Device Information or exported in the WebSocket remote snapshot.

## What Changes

- Display a **Focus Scale Reference** row in Settings **Device Information** using the effective integer value from `DeviceModelConfig.getFocusScaleRef()`.
- Include the same value in the remote snapshot `deviceInfo` object as `focusScaleRef` for both `command.stat_response` and `device.online`.
- Keep the value transient and ROM-derived; do not persist it as a Room `t_device_info` column.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `device-focus-scale-ref-config`: The configured focus scale reference is also surfaced to Settings Device Information.
- `device-remote-snapshot`: The remote snapshot `deviceInfo` object includes `focusScaleRef` and keeps `command.stat_response` aligned with `device.online`.

## Impact

- **UI**: Settings Device Information layout, string resources, and `DeviceInfoViewModel`/binding model.
- **Data model**: Transient `DeviceInfo` field for `focusScaleRef`, populated from `DeviceModelConfig`.
- **WebSocket/API**: Additive `deviceInfo.focusScaleRef` integer in `command.stat_response` `payload.data` and `device.online` `payload.stat`.
- **Tests/docs**: Update snapshot serialization tests and any network API reference that enumerates `deviceInfo` fields.
