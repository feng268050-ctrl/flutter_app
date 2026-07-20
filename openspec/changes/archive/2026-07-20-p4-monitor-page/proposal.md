## Why

Product Home and Settings exist (Material stand-ins), and `cyber_hal` already polls Modbus attributes used by Monitor (gun temperatures, alarm bits). Operators still have no Monitor surface: temperatures live only on a Home card, and alarm codes are not presented as a product page. We need an lws-ui-aligned Monitor route now, driven by HAL attribute ids, before CyberUI and video/AI land.

## What Changes

- Add a **product Monitor** page (Material UI stand-in for CyberUI) reachable from Home, aligned with lws-ui Monitor structure for this slice.
- First delivery focuses on **Alarm Information** (four welding-gun temperatures) and an **active alarm list** (boolean `alarm.*` attributes with `meta.alarm_code` / labels).
- Wire Monitor exclusively through **`ModbusHal.watchAttributes` / `watchHealth`** and product `assets/hal/modbus.json` attribute ids — no App-side Modbus poll timers or raw register addresses in UI code.
- Extract shared Modbus temperature/alarm subscription logic from `HomeTemperatureCard` into a reusable application-layer helper so Home and Monitor do not diverge.
- Maintain a short **lws-ui → attribute-id inventory** in the change design for fields in this slice; defer full Monitor chrome (video, More Monitor dialogs, process writes, AI overlay) to later P4 slices.

## Capabilities

### New Capabilities

- `product-monitor-ui`: Product Monitor screen with Alarm Information temperatures and active alarm list; Material stand-in; HAL attribute-driven live updates and health soft-fail (`-` / no crash without slave).

### Modified Capabilities

- `product-home-ui`: Home SHALL provide a visible Monitor entry that navigates to the Monitor route (in addition to Settings); Quick/Engineer may remain stubs.
- `hmi-app-navigation`: Named route for Monitor (e.g. `/monitor`); Home remains the default launcher.
- `hal-modbus-config`: No schema change expected; product Monitor MUST consume existing watch/health requirements (delta only if inventory reveals missing attribute ids that require config additions — document in design; prefer config-only attribute adds under the App asset).

## Impact

- `app/hmi/lib/` — new `features/monitor/` (domain/application/presentation), route + Home entry; refactor Home temperature card to shared Modbus watch helper.
- Reuse — `AppServices.ensureModbusLive()`, `cyber_hal` `ModbusHal`, `assets/hal/modbus.json` (`telemetry.*_temp`, `alarm.*`).
- Specs — new `product-monitor-ui`; delta Home + navigation.
- Out of scope — CyberUI/Frost migration; MediaMTX / camera preview (P4.1); AI overlay (P4.3); Quick/Engineer modes; full lws-ui More Monitor / WorkStatus dialogs; Android APK path; enabling `poll.alarm_remind` unless needed for UX in this slice.
