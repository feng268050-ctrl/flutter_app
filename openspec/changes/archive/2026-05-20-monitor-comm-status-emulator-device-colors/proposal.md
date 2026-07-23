## Why

The Monitor **Alarm Information** screen gates Comm Status indicators (Pump, Gun, Feeder) with `statusReady`, so when there is no lower-controller communication they render as unchecked (`check_none`, red). That is correct on production hardware—missing comm is a fault—but misleading on the Android emulator, which never has real peripherals attached. Operators testing UI on AVD should see neutral gray for absent comm, while YNH devices must still show red.

## What Changes

- Introduce a **three-state** visual for Comm Status check indicators only: healthy (green), fault/no-comm on device (red), and neutral/no-comm on emulator (gray).
- Scope to the three Comm Status tiles in `fragment_warn_info.xml` (Pump, Gun, Feeder); temperature and other alarm tiles keep existing readiness gating (unchecked red when not ready).
- Expose emulator detection to data binding via `WarnInfoFragment` (reuse `AndroidEmulatorUtils.isLikelyEmulator()`).
- Add or reuse a gray checkbox drawable asset for the neutral state.

## Capabilities

### New Capabilities

- `alarm-comm-status-platform-display`: Platform-aware rendering rules for Pump/Gun/Feeder Comm Status indicators on Alarm Information.

### Modified Capabilities

- `offline-alarm-status-readiness`: Clarify that readiness gating for unchecked indicators applies to non-comm tiles; Comm Status tiles follow `alarm-comm-status-platform-display` when status is not ready or comm alarm is active.

## Impact

- Android UI: `WarnInfoFragment`, `fragment_warn_info.xml`, checkbox selector or per-tile binding for comm status only.
- Drawable assets: neutral/gray comm status icon (new mipmap or selector state).
- Reuses existing `AndroidEmulatorUtils`; no Modbus or protocol changes.
- Does not change Alarm Logs, other Monitor tabs, or online alarm bit interpretation once `statusReady` is true.
