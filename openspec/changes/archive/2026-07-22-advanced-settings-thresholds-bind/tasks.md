## 1. Catalog and store

- [x] 1.1 Fix `AdvancedSettingsModbusIds` (swing_width_correction, blowing_pressure_threshold) + wire codec (lws-ui scale/offset)
- [x] 1.2 Extend `AdvancedSettingsStore` with numeric threshold keys + defaults + JSON round-trip
- [x] 1.3 Add `ModbusRtuClient.writeAttribute`

## 2. Threshold controller + UI

- [x] 2.1 Add `AdvancedSettingsThresholdsController` (warm from store, watch Modbus, commit write + cache on change-end)
- [x] 2.2 Wire `AdvancedSettingsTab` to controller; Auto = local zero reset only (no Auto procedure)
- [x] 2.3 Start/stop watch with Settings Advanced tab lifecycle / ensureModbusLive

## 3. Warn severity + laser hook

- [x] 3.1 `WarnDialogBody` INFO title style; presentation resolves via `LaserAlarmPolicy.treatBypassableAsInfo`
- [x] 3.2 Wire `DangerousOperationsSettings.onBypassDisabled` → `LaserWorkGuard.evaluateAndInterruptIfNeeded` stub (soft-clear `control.laser_enable` when policy says blocked)

## 4. Verification

- [x] 4.1 Unit tests: codec, store numerics, policy→info style helper
- [x] 4.2 Widget/controller smoke; `flutter analyze` on touched paths
