## Context

Monitor is a four-feature product surface that currently uses **five** top tabs. `MachineStatusTab` shows dual gauges plus seven run tiles in a `Column` + `Expanded` layout that fills the viewport. `AlarmInformationTab` is a separate tab: left `SettingsScrollView` of communication/temperature health, right `Expanded` Alarm Logs (`warn.watchHistory(limit: 200)` + `clearHistory()`).

Live faults already present through App-lifetime `WarnAlarmController` / frost popup / sound. The Alarm tab does not list a separate Active Alarms feed; Device Health tiles plus history cover that information. The product plan (`docs/monitor_machine_status_alarm_integration_plan.md`) folds Alarms into Machine Status and forbids a new Active Alarms section.

Controllers stay split: `MachineStatusController` starts/stops with Machine Status visibility; `WarnAlarmScope` stays app-lifetime.

## Goals / Non-Goals

**Goals:**

- Monitor top navigation: Work Info, Machine Status, Videos, AI Vision.
- Machine Status is one vertical `CustomScrollView`: Live Status → Device Health → Alarm Logs.
- Live Status: two gauges + four tiles (Safety Clamp, Gun Switch, Red Pointer, Camera).
- Device Health: existing comm + temperature cards, including Wire Feeder Communication.
- Alarm Logs: same history API and Clear semantics; default UI shows the latest 10 rows.
- Delete `AlarmInformationTab` after extraction. Keep controllers separate.

**Non-Goals:**

- Merging `MachineStatusController` and `WarnAlarmController`.
- Removing Modbus attributes `machine.laser_on`, `machine.air_valve_on`, `machine.wire_feeding_on` or stopping their watches.
- Changing Process Mode live-status dialog tiles.
- Adding Active Alarms, View All, or a second Alarm Logs page.
- Changing warn frost, sound, episode policy, or SQLite history schema.
- HAL / overlay / `cyber_alarm` package behavior changes.

## Decisions

### D1 — Presentation merge only

Extract `_MachineDeviceHealthSection` and `_MachineAlarmHistorySection` from `AlarmInformationTab` and host them in `MachineStatusTab`. Do not wrap `AlarmInformationTab()` inside Machine Status. Delete the tab file when nothing else imports it.

**Alternative:** Nest the existing tab widget. Rejected — it keeps a two-column + nested scroll layout that conflicts with a single-page scroll.

### D2 — Single `CustomScrollView`, no nested scroll

```text
CustomScrollView
  sliver: Live Status (viewport height: gauges Expanded, 4 tiles at bottom)
  sliver: Device Health (headers + comm/temp cards)
  sliver: Alarm Logs pinned header (title + Clear small secondary)
  sliver: Alarm Logs latest 10 rows
```

Drop inner `SettingsScrollView` on Device Health and inner `ListView`/`Expanded` list on Alarm Logs. Alarm rows are a `SliverList` in the same outer scroll. Live Status uses `Expanded` only inside its viewport-tall sliver (not a nested scroll).

**Alternative:** Keep the current split-pane Alarm layout (health left, logs right). Rejected — nested scroll and a second visual page inside Machine Status.

### D3 — First-screen Live Status fills the viewport

Live Status is a viewport-tall sliver (not sticky). Four tiles occupy **one** 4-column row at the **bottom** of that section and scroll away with it. The gauge row is `Expanded` above the tiles so Gas Pressure / Laser Current cards grow downward with leftover height. Gauge `size` comes from the card constraints, not a 160–260 viewport fraction.

**Alternative:** Explicit gauge + tile sizes from viewport fraction. Rejected — leftover first-screen space stayed empty and gauges could not grow.

### D4 — Four Live Status tiles; controller still watches seven bits

UI list:

```dart
(l10n.safetyLockText, s?.safetyLockOn),
(l10n.gunHeadSwitchText, s?.gunSwitchOn),
(l10n.redLightText, s?.redLightOn),
(l10n.ipCameraText, s?.cameraOn),
```

`MachineStatusIds.modbusWatchIds` and controller fields for laser / blow / wire feeding stay. Process Mode, RGB policy, and laser work guard keep using those attributes.

### D5 — Device Health content (no Active Alarms)

Reuse existing widgets: `SettingsSectionHeader` + `MonitorCommCard` / `MonitorTempMetricCard` / `SettingsParamRow`. Groups:

| Group | Cards |
|----|----|
| Laser Device | Pump Communication |
| Welding Gun | Gun Communication (full width), Motor Temp, Motor Driver Temp, Protective Mirror Temp, Collimator Temp |
| Wire Feeder | Wire Feeder Communication |

Camera **run** tile stays on Live Status. Camera **Communication** is not shown in Device Health; Gun Communication uses the full content width (same as Pump / Feeder). Wire Feeder run tile is removed from Live Status; Wire Feeder Communication stays. Camera C002 still appears in Alarm Logs and the App warn frost.

Do not add an Active Alarms list. Live episodes stay on the App warn host.

### D6 — Alarm Logs: watch 200, show 10, pin the header

Keep `warn.watchHistory(limit: 200)` and `warn.clearHistory()`. Render the newest **10** rows through `latestAlarmHistoryRows()` (presentation limit stays decoupled from the watch). Empty state reuses existing copy. Clear keeps `l10n.clearAlarmLogs` as a **secondary small** button on the **trailing side of a pinned Alarm Logs header** (`SliverPersistentHeader`, same `CustomScrollView`). The header is visually transparent so Alarm Logs blends with the Machine Status page; keep the title, trailing Clear control, and a tab-style 1px hairline (`ProductTopTabs.dividerColor` / `dividerInset`). Rows MUST clip at that divider so they cannot paint through the header while scrolling (same rule as Monitor tab content below the tab strip). Rows stay a `SliverList` under the header (not a nested scroll). Clear must not ack or force-inactive live faults.

**Alternative:** Show all 200 in the page scroll. Rejected — too long for a merged page. View All is deferred.

### D7 — Section chrome

Page status-bar title stays the Machine Status tab label. In-page `MonitorSectionHeader` for **Device Health** and **Alarm Logs**. Live Status has no extra title (avoids duplicating the tab name above the gauges). Add ARB keys for Device Health (and Live Status only if a header is later required). Reuse `alarmLogsTitle`, `alarmInfoLaserDevice`, `alarmInfoWeldingGun`, `alarmInfoWireFeeder`, card labels.

### D8 — Tab indices

```text
tabWorkInformation = 0
tabMachineStatus   = 1
tabVideos          = 2   // was 3
tabAiVision        = 3   // was 4
```

Delete `tabAlarmInformation` and the Alarms tab config (warning icon + `deviceMonitorWarnInfoTitle`). `MonitorRouteArgs.aiVision` already uses the named `tabAiVision` constant. Clamp `initialTabIndex` to the new length (4). Leave unused ARB `deviceMonitorWarnInfoTitle` in place unless a later l10n sweep removes it.

### D9 — Controller lifetimes unchanged

`MachineStatusTab.visible` still `start()` / `stop()` `MachineStatusController`. Device Health and Alarm Logs subscribe to `WarnAlarmScope` (already running). Leaving Machine Status must not dispose or stop `WarnAlarmController`.

## Risks / Trade-offs

- **[Risk] Nested scroll / clipping after merge** → One `CustomScrollView`; no inner `ListView`/`SettingsScrollView`/`Expanded` scrollables.
- **[Risk] First screen looks cramped or gauges shrink** → Viewport-based gauge clamp; one tile row with an explicit height.
- **[Risk] Operators lose a dedicated Alarms tab** → Device Health + Alarm Logs sit directly under Live Status; frost popup still covers live faults.
- **[Risk] Clearing logs is mistaken for clearing faults** → Keep Clear Alarm Logs copy and existing confirmation dialog; do not touch episode/Modbus state.
- **[Trade-off] Latest 20 vs full 200** → Shorter page; full history remains in SQLite and can gain View All later.
- **[Trade-off] Laser / Gas Flow / Wire Feeder hidden on Monitor** → Process Mode dialog still shows them; Modbus data remains.

## Migration Plan

1. Ship as App-only (`make build-app` / `make push-app`). No rootfs/HAL.
2. Rollback: revert the Monitor presentation commit; controllers and DB are unchanged.
3. After landing, treat `docs/monitor_machine_status_alarm_integration_plan.md` as implemented (do not keep a second conflicting plan).

## Open Questions

None. Locked by the revised plan: no Active Alarms, latest 20, presentation-only merge, Process Mode dialog out of scope.
