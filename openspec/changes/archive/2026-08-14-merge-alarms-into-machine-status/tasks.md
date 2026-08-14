## 1. Monitor top tabs (P0)

- [x] 1.1 Remove the Alarms tab from `MonitorPage._tabs` / `_tabLabels` (warning icon + `deviceMonitorWarnInfoTitle`)
- [x] 1.2 Delete `MonitorPage.tabAlarmInformation`; set `tabVideos = 2` and `tabAiVision = 3`
- [x] 1.3 Drop `AlarmInformationTab` from `ProductTabSlideBody` children; keep Work Info / Machine Status / Videos / AI Vision
- [x] 1.4 Confirm `MonitorRouteArgs.aiVision` still opens AI Vision after the index shift; clamp `initialTabIndex` to four tabs

## 2. Live Status four tiles (P1)

- [x] 2.1 Change Machine Status tile list to Safety Clamp, Gun Switch, Red Pointer, Camera only
- [x] 2.2 Leave `MachineStatusController` fields and `MachineStatusIds.modbusWatchIds` for laser / blow / wire feeding unchanged
- [x] 2.3 Keep the existing 4-column tile grid as a single row; size the row so tiles do not stretch to fill the viewport

## 3. Extract Device Health and Alarm Logs (P2)

- [x] 3.1 Extract `_MachineDeviceHealthSection` from `AlarmInformationTab` (Laser / Welding Gun / Wire Feeder comm + four temps), including Wire Feeder Communication; Welding Gun shows Gun Communication full width (no Camera Communication card)
- [x] 3.2 Extract `_MachineAlarmHistorySection` reusing `watchHistory(limit: 200)`, `MonitorAlarmLogRow`, `MonitorFrostActionButton`, `showAlarmLogsClearedDialog`, and `l10n.clearAlarmLogs`
- [x] 3.3 Render at most the latest 10 history rows; empty state when there are no rows
- [x] 3.4 Keep Clear Alarm Logs calling `clearHistory()` only (no episode ack, no HAL force-inactive)
- [x] 3.5 Do not add an Active Alarms section

## 4. Single Machine Status scroll (P3)

- [x] 4.1 Rebuild `MachineStatusTab` as one `CustomScrollView` (Live Status → Device Health → Alarm Logs)
- [x] 4.2 Size Live Status gauges from the viewport clamp (similar to today’s 160–260 px); no `Column`+`Expanded` page fill
- [x] 4.3 Remove nested `SettingsScrollView` / `ListView` / `Expanded` list from Device Health and Alarm Logs
- [x] 4.4 Add localized Device Health (and Alarm Logs via existing `alarmLogsTitle`) section headers; no Live Status heading
- [x] 4.5 Keep `MachineStatusTab.visible` start/stop on `MachineStatusController` only; do not stop `WarnAlarmScope` when leaving the tab

## 5. Cleanup (P4)

- [x] 5.1 Delete `alarm_information_tab.dart` and unused Monitor imports
- [x] 5.2 Add ARB keys for Device Health section title (parent `app_en.arb` / `app_zh.arb`); run `make l10n`
- [x] 5.3 Leave unused `deviceMonitorWarnInfoTitle` unless a cheap sweep shows it is unreferenced
- [x] 5.4 Update Monitor comments that still say “five tabs” or “7 status tiles”

## 6. Tests and spec wording

- [x] 6.1 Add/adjust widget tests: four Monitor tabs; four Live Status tiles; Device Health cards (including Wire Feeder Communication); Alarm Logs latest-20 + clear-history-only
- [x] 6.2 Keep `machine_status_controller_test` covering laser / blow / wire feeding watches
- [x] 6.3 Update related spec/docs wording that still says “Alarm Information tab” where it now means Machine Status Device Health (`hal-modbus-config`, `app-modbus-live`, `estop-comm-alarm-suppress`, `product-boot-self-check` as needed)
- [x] 6.4 Run `flutter analyze` and the Monitor / warn tests under `app/lws_hmi/`
