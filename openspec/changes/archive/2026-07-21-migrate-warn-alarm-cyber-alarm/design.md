## Context

lws-hmi HAL already polls Modbus continuous groups and exposes human-readable `alarm.*` / `telemetry.*` attributes plus `watchHealth`. Monitor Alarm Information binds those for lights, temps, and a live active list. lws-ui still owns the full warn stack (codes → episode → dialog queue → Room log → laser interrupt) inside Android UI/handler packages.

Product requirement: migrate warn behavior to Flutter HMI **without** pushing dialog/episode policy into HAL or CyberUI, and **without** scattering episode logic inside Monitor widgets. Abstract as a shared **`packages/cyber_alarm`** layer so multiple product Apps (and future non-Modbus sources) share one episode engine through ports.

## Goals / Non-Goals

**Goals:**
- Introduce `packages/cyber_alarm` (domain + coordinator + ports) as the 5th stack layer between Product App and CyberUI/HAL.
- App consumes HAL only through attribute/health watches (existing façades) and feeds `cyber_alarm` via adapters.
- Present warn dialogs via a presentation port implemented by the App with CyberUI overlay — not ad-hoc `showDialog` in Monitor, and not inside the package as Flutter widgets (v1).
- Persist historical alarm log via repository port (App implements store); Clear history without clearing live bits.
- Suppress warn presentation while boot self-check is active (`WarnGate`).
- Keep Machine Status vs Alarm Information indicator semantics separate from episodes.

**Non-Goals:**
- HAL owning Warn dialogs, episode tables, or alarm-code catalogs.
- CyberUI owning episode/resist-ack policy.
- Porting Android class names 1:1 (`DeviceStatusConvert`, `WarnDialogUtil`) into Dart UI files.
- Laser enable interrupt and non-Modbus sources (camera / lens / zero-point) in this change (ports must allow later adapters).
- Changing Modbus register maps or Dot/Icon status-light mapping.

## Decisions

### 1. Five-layer boundary (`cyber_alarm` package, not App-only, not HAL)

**Choice:** Place reusable warn/alarm orchestration in `packages/cyber_alarm`:

```
packages/cyber_alarm/
  lib/
    domain/           → AlarmCode, WarnEpisode, WarnEpisodePolicy, AlarmSignalEvent
    application/      → WarnAlarmCoordinator (arm / ack / recover / queue)
    ports/            → AlarmSignalSource, WarnPresentation, AlarmLogRepository, WarnGate
    catalog/          → AlarmCodeCatalog model + load helpers (data injected by App)

app/hmi/
  lib/features/warn_alarm/   (thin App wiring only)
    infrastructure/   → ModbusAlarmAttributeAdapter, LocalAlarmLogStore
    presentation/     → CyberUI WarnPresentation host
    bootstrap/        → catalog seed, gate wiring, register coordinator
```

**Rationale:** Matches multi-product direction (shared CyberUI + HAL + domain packs). Episode policy is product-domain reusable logic, not board I/O and not chrome.

**Alternatives considered:**
- Put episode logic in `cyber_hal` — rejected (HAL non-goal; hard to test UI policy on board).
- Keep everything in `app/hmi/lib/features/warn_alarm/` only — rejected for this change (locks reuse; contradicts agreed 5-layer stack).
- Put policy in `cyber_ui` — rejected (chrome must stay policy-free).

### 2. Ports & adapters (hexagonal)

**Choice:** Define ports in `cyber_alarm`:

| Port | Direction | Responsibility |
|------|-----------|----------------|
| `AlarmSignalSource` | inbound | Stream of `{attributeId?, code, active, kind}` from Modbus (and later camera) |
| `WarnPresentation` | outbound | Show / dismiss / update modal episode |
| `AlarmLogRepository` | outbound | Insert rising-edge history; query; clear |
| `WarnGate` | inbound | e.g. `BootSelfCheckGate.isActive` → suppress presentation |

App Modbus adapter maps `watchAttributes` dirty list → `AlarmSignalSource` events using catalog + `meta.alarm_code`. HAL never receives callbacks that open dialogs. Package MUST NOT depend on `cyber_hal` or Flutter for domain/coordinator (adapters stay in App).

**Rationale:** Swapping CyberUI or adding C002 does not rewrite coordinator; package stays portable.

### 3. Catalog ownership

**Choice:** `cyber_alarm` owns the **catalog model and join rules**; the product App **seeds** entries (code, severity, title/body keys / locale). HAL `meta.alarm_code` / `meta.label` are hints for list labels and code join keys only.

**Rationale:** Dialog copy and severity are product UX; register decode stays in HAL config; structure stays shared.

### 4. Episode vs Monitor lights

**Choice:** Status lights continue to bind attributes directly (Success Icon / Failure Icon / Idle). Episodes are a parallel `cyber_alarm` stream: rising edge → arm episode → presentation queue. Lights MUST NOT open dialogs.

**Rationale:** Same component, different semantics (already product rule).

### 5. History vs active list

**Choice:** Active list = current true `alarm.*` with codes (existing). History = repository rising-edge records (App store behind package port). Monitor “Alarm Logs” title means history after this change; live active alarms stay driven by telemetry model (may remain above or as badge). Exact layout in tasks; requirement is behavioral.

### 6. Boot self-check gate

**Choice:** Coordinator consults `WarnGate`; when self-check active, still update domain active set / history optionally, but **MUST NOT** call `WarnPresentation.show`.

**Rationale:** Aligns with lws-ui and existing boot-self-check wording about suppressing overlapping warn monitors.

## Risks / Trade-offs

- **[Risk] Catalog drift vs `modbus.json` meta** → Mitigation: startup or test that every `meta.alarm_code` exists in product catalog (or soft-fallback to meta label + unknown severity).
- **[Risk] Double presentation if Monitor and global host both show** → Mitigation: single process-wide `WarnPresentation` host registered at App shell.
- **[Risk] Reminder kind floods history** → Mitigation: history INSERT only on rising edge (`false→true`); ignore `reminder` for log insert (may refresh dialog only if policy says so).
- **[Risk] Accidental HAL/Flutter deps in package** → Mitigation: package tests run without Flutter; CI/`analyze` forbids importing `cyber_hal` / `flutter` from domain+coordinator libs (presentation stays App-side).
- **[Trade-off] Laser interrupt deferred** → Weld safety path lags Android until follow-up; document follow-up change.

## Migration Plan

1. Scaffold `packages/cyber_alarm` + App path dep; land coordinator + no-op presentation (log-only) behind flag if needed.
2. Wire App Modbus adapter + history store; update Monitor Logs UI.
3. Enable CyberUI warn presentation + boot gate.
4. Device smoke: inject/force `alarm.*` true; verify dialog + history; self-check does not popup.
5. Rollback: disable presentation host / feature flag; HAL unchanged; package can remain unused.

## Open Questions

1. Should history INSERT happen even when presentation is gated (self-check)? Prefer **yes** (audit) unless product says no. **Implemented: yes.**
2. Exact Monitor layout for active vs history after Clear lands. **Implemented: Active codes line + history list with Clear.**
3. Whether HAL `alarm_remind` should be enabled for dialog re-prompt in this change or left off. **Left off (HAL default); reminder kind handled if HAL emits.**
4. Whether v1 `cyber_alarm` is pure Dart only (preferred) or may optionally export a thin Flutter helper later — default **pure Dart**. **Implemented pure Dart.**

## Deferred follow-ups (not this change)

- Laser enable interrupt adapter on the same `cyber_alarm` ports.
- Camera / lens / zero-point `AlarmSignalSource` adapters (C002 / L001 / H034 class).
