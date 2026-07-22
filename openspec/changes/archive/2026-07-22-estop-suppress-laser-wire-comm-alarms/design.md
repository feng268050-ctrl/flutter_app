## Context

Machine e-stop (`machine.emergency_stop`, input `0x0015` bit7) physically cuts power to the laser and wire feeder. Controllers still report communication-fault bits (`alarm.laser_comm` → H022, `alarm.wire_feeder_comm` → W001). Today `ModbusAlarmAttributeAdapter` maps those bits 1:1 into `AlarmSignalEvent`s, so the coordinator arms episodes, shows modals, and inserts SQLite history.

lws-ui already normalizes this in `ModbusFiledConvert.applyEmergencyStopCommAlarmReset`: while e-stop is triggered, clear bit0 of laser alarm seg1 and wire-feeder alarm seg1 before warn tables / UI read the snapshot. The archived HAL design left “E-stop clear false comm bits — HAL vs App?” open; product direction now is **App alarm path only**, no HAL/`modbus.json` changes.

## Goals / Non-Goals

**Goals:**

- No H022/W001 warn popup and no history insert while e-stop is active.
- Tear down any already-armed H022/W001 episode when e-stop engages.
- After e-stop release, real still-active bits may rise normally.
- Preserve raw Modbus values for Alarm Information lights, boot self-check, and other status consumers.
- Preserve all other alarm codes and raw HAL attribute values.

**Non-Goals:**

- Changing Modbus decode, poll/watch APIs, or `modbus.json`.
- Masking Alarm Information / status-check UI for laser/wire-feeder comm under e-stop.
- Clearing other laser/wire-feeder bits (current, drivers, H029 laser e-stop, W002, etc.).
- Suppressing gun, camera, or C001 health alarms on e-stop.
- Putting product e-stop policy inside `packages/cyber_alarm` or `packages/cyber_hal`.
- Changing physical e-stop interlock behavior or Modbus writes.

## Decisions

### D1 — Suppress in the App Modbus alarm adapter (not HAL, not package coordinator)

**Choice:** Extend `ModbusAlarmAttributeAdapter` (or a dedicated thin decorator used only on the signal/monitor fan-out it owns) to:

1. Always include `machine.emergency_stop` in the watched id set.
2. Track e-stop latch + raw active state for `alarm.laser_comm` / `alarm.wire_feeder_comm`.
3. Emit `AlarmSignalEvent`s for H022/W001 from the **effective** active flag: `effective = raw && !eStop`.
4. When e-stop rises, if effective was true, emit falling for those codes; while e-stop holds, ignore raw rising / treat reminders as inactive.
5. When e-stop falls, if raw is still true, emit rising (same as a fresh fault onset).

Pass Alarm Information / status `monitorChanges` **unchanged** (raw HAL values). Do **not** mutate values returned by HAL `watchAttributes` for other listeners.

**Rationale:** Matches “alarm path only” without teaching HAL product policy. Status checks stay truthful to Modbus. `WarnGate` is wrong: it still inserts history. Filtering inside `WarnAlarmCoordinator` by hard-coded codes would leak product policy into the shared package.

**Alternatives considered:**

| Option | Why not |
|--------|---------|
| Clear bits in HAL decode / config transform | Explicitly out of scope; pollutes all Modbus consumers |
| `WarnGate` during e-stop | Suppresses presentation only; history still inserts |
| Coordinator deny-list for H022/W001 | Product safety UI policy belongs in App adapters |
| Drop events entirely with no synthetic falling | Leaves a stuck modal / active episode if fault was already armed |

### D2 — Codes and attributes in scope

| Attribute | Code | Under e-stop |
|-----------|------|--------------|
| `alarm.laser_comm` | H022 | suppressed |
| `alarm.wire_feeder_comm` | W001 | suppressed |
| `machine.emergency_stop` | (no alarm_code) | watch only, as latch |
| Other `alarm.*` | unchanged | pass through |

Same bit0-only scope as lws-ui (`& ~0x1` on those two segments).

### D3 — History and presentation semantics

- Rising for H022/W001 MUST NOT reach the coordinator while e-stop is active → no `insertRising`, no modal enqueue.
- Synthetic falling on e-stop engage uses existing coordinator recover/teardown policy.
- Reminder edges for suppressed codes MUST NOT re-arm presentation while e-stop is active.
- Unrelated concurrent alarms (e.g. H001) continue normally during e-stop.

### D4 — Spec surface

- New capability `estop-comm-alarm-suppress` owns the product rules.
- `cyber-alarm` gains an ADDED requirement that App adapters MAY filter/rewrite edges before the coordinator; package episode policy stays code-agnostic.

## Risks / Trade-offs

- **[Risk] E-stop and comm-bit updates arrive in different watch batches** → Keep latch in adapter state; apply suppress using last-known e-stop when processing either id; include `machine.emergency_stop` in the same watch set so latency stays one poll period.
- **[Risk] Other Modbus consumers still see raw true bits** → Acceptable: only alarm path + Alarm Information feed from this adapter are normalized; document that raw HAL remains truthful.
- **[Risk] Operator expects a “laser disconnected” indication during e-stop** → Product wants silence; e-stop itself is the operator signal (machine status / H029 if applicable).
- **[Trade-off] Adapter grows product policy** → Prefer a small named helper (e.g. `EstopCommAlarmMask`) unit-tested beside the adapter for clarity.

## Migration Plan

1. Land adapter mask + unit tests (no firmware/config change).
2. `make build-app` / `make push-app`; device: press e-stop with laser/wire feeder powered path that previously raised H022/W001 — confirm no popup/history; release e-stop with a real comm fault still present — confirm alarm may rise.
3. Rollback: revert App adapter change; HAL/config untouched.

## Open Questions

None blocking. Product confirmed: suppress popup/history only; status lights and self-check keep raw bits.
