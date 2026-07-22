## Why

Advanced Settings UI already shows threshold sliders and dangerous-ops facades, but thresholds do not watch/write Modbus and warn presentation ignores bypass→INFO severity. Operators cannot persist product params to the controller or get lws-ui-parity warn chrome for allow-* bypasses. Zero Offset Auto and AI StreamDetect gating remain out of scope.

## What Changes

- Bind Advanced Settings numeric thresholds to catalogued HAL attribute ids (watch + write on commit), with App JSON cache under `advanced-settings.json` for soft-fail / restart.
- Fix attribute id map (`swing_width_correction`, `blowing_pressure_threshold`).
- Expose `ModbusRtuClient.writeAttribute` for Settings writes.
- Wire dangerous-ops policy into warn dialog severity (bypassable codes → INFO/black title when allow-* ON), parity with lws-ui `WarnDialogSeverity`.
- Add App-layer laser work re-evaluate hook wired from `DangerousOperationsSettings.onBypassDisabled` (no-op / soft until laser-enable interrupt path exists; document).
- **Out of scope:** Zero Offset Auto procedure; StreamDetect / stain / zero-point AI coordinators.

## Capabilities

### New Capabilities
- `advanced-settings-thresholds`: Modbus-backed threshold watch/write + local JSON cache for Advanced Settings numerics
- `advanced-settings-warn-severity`: Dangerous-ops bypass maps to warn dialog INFO vs WARN presentation

### Modified Capabilities
- `advanced-settings-ui`: Threshold sections use live bound controls (not local-only shells)
- `advanced-settings-dangerous-operations`: Consumers include warn severity + re-evaluate hook wiring
- `linux-settings-persist`: Document numeric keys in `advanced-settings.json`
- `cyber-alarm`: Optional — App-owned severity override at presentation time (no package API change if App resolves style)

## Impact

- **App:** `AdvancedSettingsStore` numerics, threshold controller, `advanced_settings_tab`, `ModbusRtuClient.writeAttribute`, warn presentation / controller
- **HAL:** existing `writeAttribute` / watch; catalog ids only
- **cyber_ui / cyber_alarm:** WarnDialogBody INFO title color; no Frost ports
- **Not:** AI StreamDetect, Zero Point Auto daemon
