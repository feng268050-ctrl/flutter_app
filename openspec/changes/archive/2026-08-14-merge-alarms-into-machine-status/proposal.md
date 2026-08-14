## Why

Monitor currently splits live run state and alarm/health information across two top-level tabs (`Machine Status` and `Alarms`). Operators must leave Live Status to see device communication, temperatures, or alarm history, and the extra tab adds navigation cost without a distinct workflow. Merge the Alarms surface into Machine Status so one page carries Live Status, Device Health, and Alarm Logs.

## What Changes

- **BREAKING (in-app navigation):** Remove the Monitor top-level `Alarms` tab. Monitor tabs become `Work Info` / `Machine Status` / `Videos` / `AI Vision`. `MonitorPage.tabVideos` and `tabAiVision` shift from 3/4 to 2/3; `tabAlarmInformation` is deleted.
- Machine Status becomes a single vertical scroll with three sections: **Live Status** → **Device Health** → **Alarm Logs**. No inner tabs and no nested scroll views.
- Live Status keeps the two gauges (Gas Pressure, Laser Current) and reduces run tiles from seven to four: Safety Clamp, Gun Switch, Red Pointer, Camera. Laser / Gas Flow / Wire Feeder tiles are removed from this UI only; `MachineStatusController` and Modbus attributes stay.
- Device Health is the former Alarm Information left column: Laser Device (Pump Communication), Welding Gun (Gun Communication full width + four temperatures), Wire Feeder Communication. Camera Communication is not shown in Device Health; the Live Status Camera run tile and C002 alarm history / frost stay.
- Alarm Logs is the former Alarm Information history list (`watchHistory(limit: 200)` + `clearHistory()`). Default visible rows are the latest 10. **Clear Alarm Logs** still clears history only, not live faults.
- Do **not** add an `Active Alarms` section. Live faults stay on App-wide warn frost / sound; Device Health shows comm/temp health; history is Alarm Logs only.
- Presentation-only merge: keep `MachineStatusController` (tab-visible start/stop) and `WarnAlarmController` / `WarnAlarmScope` (app-lifetime) separate.
- Delete `AlarmInformationTab` after the sections move. Process Mode live-status dialog is out of scope.

## Capabilities

### New Capabilities

- (none)

### Modified Capabilities

- `product-monitor-ui`: Collapse Monitor from five tabs to four; relocate Alarm Information into Machine Status as Device Health + Alarm Logs; shrink Live Status tiles to four; require a single Machine Status scroll; forbid a separate Active Alarms list.
- `cyber-alarm`: Point Monitor status-light scenarios at Machine Status Device Health instead of a standalone Alarm Information tab. Episode policy, popup host, and history repository stay unchanged.

## Impact

- `app/lws_hmi/lib/features/monitor/presentation/monitor_page.dart` — tab list, indices, body.
- `app/lws_hmi/lib/features/monitor/presentation/tabs/machine_status_tab.dart` — Live Status tiles + CustomScrollView hosting Device Health and Alarm Logs.
- New Machine Status section widgets (Device Health, Alarm Logs) extracted from `alarm_information_tab.dart`; then delete that tab file.
- `MachineStatusController` / `WarnAlarmController` stay; no HAL, overlay, or `cyber_alarm` engine changes.
- Specs: `openspec/specs/product-monitor-ui/`, wording in `openspec/specs/cyber-alarm/`. Related docs that still say “Alarm Information tab” (e.g. `hal-modbus-config`, `app-modbus-live`, `estop-comm-alarm-suppress`, `product-boot-self-check`) get naming updates in implementation, not requirement deltas.
- Tests: Monitor tab counts/indices, Machine Status tile set, Device Health + Alarm Logs on Machine Status, history clear semantics.
- Rebuild: `make build-app` then `make push-app`.
