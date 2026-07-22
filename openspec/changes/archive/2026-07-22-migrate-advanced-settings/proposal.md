## Why

lws-hmi Settings → Advanced Settings is still a placeholder while lws-ui already exposes Offset/Power/Temperature thresholds plus **AI Assistance** and **Dangerous Operations** toggles that gate production AI and laser-alarm behavior. Operators migrating to Flutter HMI lose those controls. This change migrates Advanced Settings with **lws-ui layout/section parity** and **CyberUI controls** (not Frost Java widgets), and defines how AI / dangerous switches are owned, persisted, and consumed at the App layer.

## What Changes

- Replace Advanced Settings placeholder with a scrollable section layout matching lws-ui: Offset & Correction, Power Thresholds, Temperature Thresholds, **AI Assistance**, **Dangerous Operations**.
- Persist App-only AI + dangerous booleans in a dedicated store under `/var/lib/hmi/` (not Misc JSON, not HAL).
- Expose App-layer facades (ports) so StreamDetect / warn / future laser guards **read** the same toggles; switches MUST NOT send Modbus solely because they flipped.
- Use **CyberUI** switches (and existing Settings chrome patterns) for all toggle rows; numeric threshold editors MAY land as Cyber numeric/stepper or interim Material with follow-up Cyber polish.
- Wire dangerous-ops policy APIs to match lws-ui `LaserEnableAlarmGuard` semantics where warn/laser interrupt already exists; otherwise ship store + API and document consumer wiring as gated tasks.
- **Out of scope / follow-up:** Custom Home drag layout; full Modbus write parity for every threshold register if HAL attributes are not yet catalogued (thresholds UI may soft-fail or show last-known until attributes exist).

## Capabilities

### New Capabilities
- `advanced-settings-ui`: Advanced Settings tab layout and CyberUI controls (sections, switches, hints) parity with lws-ui Advanced Settings.
- `advanced-settings-ai-assistance`: Lens / zero-point AI assistance toggles — persistence, defaults, App-layer gate APIs for production AI paths.
- `advanced-settings-dangerous-operations`: Five dangerous-operation toggles — persistence, defaults, hints, App-layer policy APIs for laser enable / runtime interrupt / warn severity consumers.

### Modified Capabilities
- `settings-ui`: Advanced tab MUST present live Advanced Settings content (no longer placeholder-only once this change lands).
- `linux-settings-persist`: Document dedicated advanced-settings persistence file under `/var/lib/hmi/`.

## Impact

- **App:** `advanced_settings_tab.dart`, new `AdvancedSettingsStore` (+ scope), optional threshold Modbus binding via existing `ModbusRtuClient` / attribute ids.
- **Consumers:** warn-alarm / AI stream / future laser guard import App facades — **not** UI widgets.
- **cyber_ui:** `CyberSwitch` (+ SettingsSwitchRow pattern); no new Frost Java ports.
- **HAL:** no ownership of AI/dangerous booleans; threshold registers remain attribute catalog when present.
