## Context

Home/Settings (Material) and `cyber_hal` Modbus are already on main. Continuous poll covers `status` → `data`; attribute catalog in `app/hmi/assets/hal/modbus.json` includes gun temperatures (`telemetry.gun_motor_temp` …) and boolean `alarm.*` with `meta.alarm_code`. Home shows a temperature card via a broad `modbusAttributeChanges` fan-out. There is no Monitor route or lws-ui-shaped Alarm Information / alarm-list UI.

Constraints: Flutter **3.24.4** + flutter-pi; Material stand-in until P3.0 CyberUI; product UIs must use attribute ids (no raw addresses); first paint of Home must remain free of blocking Modbus I/O; lws-ui Android/Kotlin is the behavioral reference for inventory, not a line-by-line port.

## Goals / Non-Goals

**Goals:**

- Ship `/monitor` with Alarm Information (four gun temps) + active alarm list.
- Drive UI only via `ModbusHal.watchAttributes` / `watchHealth` after `AppServices.ensureModbusLive()`.
- Home gains a visible Monitor entry; shared application helper for temp/alarm watch (Home card + Monitor).
- Document this slice’s lws-ui → attribute-id inventory in this design.

**Non-Goals:**

- CyberUI / Frost cards; camera / MediaMTX / AI overlay.
- Quick Mode / Engineer Mode product flows.
- Full More Monitor / WorkStatus dialogs / process holding writes.
- Enabling `poll.alarm_remind` (leave config default off unless UX requires it later).
- Android APK / YNHAPI path.
- HAL schema or transport changes (config attribute adds only if inventory gaps appear).

## Decisions

### D1 — Material Monitor feature module under `features/monitor/`

**Choice:** `domain` / `application` / `presentation` mirroring Home/Settings DDD layout.

**Why:** Matches existing product modules; keeps Monitor presentation swappable when CyberUI arrives.

**Alternatives:** Extend Demo — rejected (Demo is engineering smoke). Drop domain layer — rejected (temps + alarm list already need shared models).

### D2 — Narrow `watchAttributes(ids: …)` for Monitor

**Choice:** Monitor (and the shared helper) subscribe with an explicit id allowlist: four `telemetry.*_temp` ids, four over-temp bools used for row styling, and all product `alarm.*` bools shown in the list (or a documented subset if list is code-filtered by `meta.alarm_code` presence).

**Why:** Avoids UI work on unrelated telemetry churn; aligns with `hal-modbus-config` “change-only watch” intent.

**Alternatives:** Keep Home’s unfiltered fan-out — acceptable for Home card but too noisy for Monitor alarm list logic.

### D3 — Soft-fail display and health

**Choice:** Missing/failed values show `-`; `watchHealth` may surface a non-blocking “comm fault” affordance (text/banner) without owning Warn dialog policy. No crash without Modbus slave.

**Why:** Matches P2 Demo and Home temperature card behavior; C001 dialog policy stays product-later.

### D4 — Inventory for this slice (lws-ui Alarm Information + alarm bits)

| UI (lws-ui Monitor) | Attribute id | Notes |
|---------------------|--------------|--------|
| Motor temperature | `telemetry.gun_motor_temp` | input; scale ×0.1 °C in config |
| Motor driver temperature | `telemetry.gun_motor_drive_temp` | |
| Protective mirror temperature | `telemetry.protective_cover_temp` | label naming vs lws-ui “Protective Mirror” |
| Collimator temperature | `telemetry.collimator_temp` | |
| Motor over-temp | `alarm.gun_motor_over_temp` | H008; row highlight |
| Driver over-temp | `alarm.driver_over_temp` | H009 |
| Protective mirror over-temp | `alarm.protective_mirror_over_temp` | H010 |
| Collimator over-temp | `alarm.collimator_over_temp` | H011 |
| Active alarms list | all other `alarm.*` with `meta.alarm_code` | show when value `true`; display code + `meta.label` |

SoC/GPU on Home remain `SysInfo` — not part of Monitor Alarm Information.

### D5 — Navigation

**Choice:** `AppRoutes.monitor = '/monitor'`; Home Monitor affordance uses `pushNamed`. Layout: bottom or side entry consistent with available Home chrome (exact pixel layout may stub relative to lws-ui until assets exist).

### D6 — No HAL package API change

**Choice:** Reuse `ModbusHal` as-is. If an lws-ui field lacks an attribute, add to `modbus.json` only.

## Risks / Trade-offs

- **[Risk] Incomplete lws-ui Monitor inventory** → Mitigation: scope this change to Alarm Information + alarm list; open questions track next fields.
- **[Risk] Duplicate subscriptions (Home card + Monitor)** → Mitigation: shared helper; both call `ensureModbusLive` once; HAL already multiplexes watch.
- **[Risk] Alarm list volume / flicker** → Mitigation: change-only watch; UI gate debounce (same pattern as Home ~500 ms) if needed.
- **[Trade-off] Material ≠ product glass** → Accept until CyberUI; structure pages for later skinning.

## Migration Plan

1. Land feature + routes behind normal `make build-app` / `push-app` (or rootfs if assets only in app bundle).
2. No rootfs/kernel change expected.
3. Rollback: remove Monitor route/entry; Home card can keep prior local subscription if helper reverts.

## Open Questions

1. Exact Home Monitor control placement/assets vs lws-ui (bottom chrome vs temporary Material button)?
2. Should Monitor show SoC/GPU as well, or only welding-gun Alarm Information?
3. Alarm list ordering: register bit order vs `alarm_code` sort vs severity?
4. Confirm lws-ui “Protective Mirror” maps to `telemetry.protective_cover_temp` (naming mismatch only?).
