## 1. Package skeleton (`cyber_alarm`)

- [x] 1.1 Create `packages/cyber_alarm` path package (pure Dart; no `cyber_hal` / Flutter deps in domain + coordinator)
- [x] 1.2 Define domain types: `AlarmCode`, `WarnEpisode`, `AlarmSignalEvent` (include change kind: rising / falling / reminder)
- [x] 1.3 Define ports: `AlarmSignalSource`, `WarnPresentation`, `AlarmLogRepository`, `WarnGate`
- [x] 1.4 Add `AlarmCodeCatalog` model + load helpers; App seeds high-frequency lws-ui codes and joins to `modbus.json` `meta.alarm_code` (soft-fail unknowns)
- [x] 1.5 Add App `pubspec.yaml` path dependency on `cyber_alarm`

## 2. Modbus adapter (App infrastructure only)

- [x] 2.1 Implement App `ModbusAlarmAttributeAdapter` on App façade `watchAttributes` → package `AlarmSignalSource` (map id + meta → code; tag reminder)
- [x] 2.2 Subscribe only to alarm ids needed for episodes/history (reuse/extend `MonitorModbusIds` or catalog-driven list)
- [x] 2.3 Unit-test rising/falling/reminder classification without opening UI (package + adapter tests)

## 3. Episode coordinator + presentation host

- [x] 3.1 Implement `WarnAlarmCoordinator` in `cyber_alarm`: rising → arm episode; falling → recover per policy; single queue
- [x] 3.2 Implement App CyberUI (or interim Material) `WarnPresentation` host registered once at App shell
- [x] 3.3 Wire App `WarnGate` to boot self-check `isActive` so presentation is suppressed during self-check
- [x] 3.4 Widget/unit tests: gate on → no show; gate off + rising → show; recover clears when policy allows

## 4. Historical alarm log

- [x] 4.1 Implement App `AlarmLogRepository` (SQLite or file store under OsPaths) behind the package port; insert on rising edge only
- [x] 4.2 Expose query + clear APIs for Monitor via App façade over the repository
- [x] 4.3 Replace Alarm Information “coming soon” Clear with repository clear; bind Logs list to history stream
- [x] 4.4 Keep live active list/telemetry separate from history Clear behavior

## 5. Monitor consumer wiring

- [x] 5.1 Ensure Alarm Information lights/temps still bind attributes directly (no episode ownership in tab)
- [x] 5.2 Document/label UI: history = Alarm Logs; live actives remain distinct if both shown
- [x] 5.3 Confirm status lights still use Cyber Success/Failure/Idle Icon semantics unchanged

## 6. Verification

- [x] 6.1 Unit tests for catalog join, reminder non-insert, gate suppression (prefer package-level for coordinator)
- [x] 6.2 `make build-app` (and push when board available): force/simulate `alarm.*` true → dialog + history row
- [x] 6.3 During boot self-check, alarm onset does not popup; after finish, new onset can popup
- [x] 6.4 Confirm no warn/episode types under `packages/cyber_hal`; episode engine lives in `packages/cyber_alarm`; App only wires adapters/host/store

## 7. Follow-ups (document only; not this change)

- [x] 7.1 Note deferred: laser interrupt adapter on same ports
- [x] 7.2 Note deferred: camera / lens / zero-point `AlarmSignalSource` adapters
