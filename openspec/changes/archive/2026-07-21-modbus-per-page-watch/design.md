## Context

Product HMI keeps one process-wide `ModbusRtuClient` / `ModbusHal` on `AppServices`. Continuous RTU poll must stay up for alarms without requiring Monitor to be open. HAL already supports multiple `watchAttributes` listeners, each with optional `ids`. Today the App collapses that into one watch feeding `modbusAttributeChanges` / `modbusHealthChanges` broadcast streams; pages filter with `switch`. Boot self-check still owns one-shot reads and suppresses poll while active.

## Goals / Non-Goals

**Goals:**

- `ensureModbusLive` (and route `scheduleEnsureModbusLive`) only start continuous polling under intercept rules.
- Each live UI surface binds interest via `watchAttributes(ids: …)` (and `watchHealth` where needed); dispose cancels that subscription only.
- Align App usage with HAL multi-subscriber watch; stop using a single undifferentiating attribute fan-out as the product path.

**Non-Goals:**

- Changing RTU transport, register map, or `modbus.json` catalog.
- Moving boot self-check off one-shot `readAttribute`.
- Per-page `startPolling` or multiple HAL instances.
- Reworking exclusive-session / OTA Modbus flows beyond keeping poll ensure separate from watches.

## Decisions

### 1. Ensure = poll only

**Choice:** `ensureModbusLive` calls HAL `startPolling` (via client helper), honors `modbusLiveAllowed` and `BootSelfCheckGate.isActive` (defer until gate clears / Home `onComplete`), does **not** open attribute watches or accept `watchIds`.

**Alternatives:** Keep ensure starting a default watch — rejected (reintroduces global fan-out). Start poll from first page watch — rejected (alarms need poll before Monitor mounts).

### 2. Per-surface watch with explicit ids

**Choice:** Device Information, `GunAlarmTelemetry`, Demo each hold a `StreamSubscription` from `watchAttributes(ids: theirIds)`. Id lists live next to the feature (constants / catalog helpers already exist: device info fields, `MonitorModbusIds`, demo tiles).

**Alternatives:** Filtered views over a broadcast — rejected (still one HAL watch; ids not bound at subscribe). One App “session” object owning all watches — unnecessary indirection for now.

### 3. Client API shape

**Choice:** Slim `ModbusRtuClient`: keep `readAttribute` / list / snapshots; replace `startLiveDemo` with `ensurePolling()` (or ensure path calls HAL `startPolling` directly) plus `watchAttributes` / `watchHealth` passthrough. Optional one-shot `info` group read stays with consumers that need SN/version (Device Info / Demo), not with ensure.

**Alternatives:** Pages import `ModbusHal` only — possible but façades already centralize asset/profile loading.

### 4. Health stream

**Choice:** No process-wide health broadcast required. Monitor (and Demo Modbus Link) subscribe to `watchHealth()` alongside attributes. Aggregate window semantics remain HAL-owned.

### 5. Route bootstrap unchanged in placement

**Choice:** Home (after self-check), Monitor, Settings, Demo still call ensure so poll runs if entry route ≠ Home. They do **not** subscribe to attributes at route level unless the route itself displays Modbus fields.

## Risks / Trade-offs

- **[Risk]** Forgetting a page watch after removing broadcast → UI stuck on `-` → **Mitigation:** tasks enumerate consumers; tests assert subscribe with ids / dispose cancel.
- **[Risk]** Multiple watchers increase HAL dispatch work → **Mitigation:** already designed; filter by ids keeps payloads small; poll cost unchanged.
- **[Risk]** Deferred ensure during self-check + page mounts watch before poll → prime waits for first successful cycle (existing HAL behavior) → **Mitigation:** document; ensure still runs on self-check `onComplete`.
- **[Trade-off]** Slightly more subscribe boilerplate per page vs shared stream — accepted for correct HAL use.

## Migration Plan

1. Add poll-only ensure + client watch passthrough.
2. Migrate Monitor / Device Info / Demo off broadcast; delete unused broadcast controllers when unused.
3. Update tests; `flutter analyze` on `app/hmi`.
4. `make build-app` && `make push-app` for device smoke (Home → self-check → temps/alarms on Monitor without prior Demo).

Rollback: revert App wiring; HAL unchanged.

## Open Questions

- Whether to keep a thin deprecated `modbusAttributeChanges` shim during one PR or remove in the same change (prefer remove in same change if all call sites migrate).
- Whether Demo under non-AppScope (standalone) still uses a private client watch — keep soft-fail path for tests.
