## Context

This product already has the pieces; they are not wired together:

- HAL `IpCameraController.health` — debounced `unknown` / `healthy` / `unhealthy` (quiet windows, consecutive thresholds)
- Product `IpCameraProductSession` — eth0 / MediaMTX / UI phases for Home icon and Machine Status
- `cyber_alarm` — `AlarmSignalSource` → episodes → presentation / history / gate
- App `WarnAlarmController` — Modbus adapter only today; catalog already has **C002**; `LaserAlarmPolicy` + dangerous-ops bypass + `LaserWorkGuard` already know C002

Earlier slices deferred “non-Modbus camera → warn.” This change is **App glue only**: health Stream → existing alarm ports.

**Reference, not blueprint:** Operator expectation that an unreachable camera should surface as coded warn **C002** matches the product catalog (and historical lws-ui behavior). Implementation MUST use in-tree IP Camera + `cyber_alarm` APIs — do **not** port Android monitors, cache keys, `ExternalWarnAlarm`, or a second warn pipeline.

## Goals / Non-Goals

**Goals:**

- Emit C002 rising/falling from HAL health into the existing coordinator.
- Reuse gate, dialog host, history, severity chrome, SFX hooks, and laser guard already in App.
- Keep HAL and `cyber_alarm` domain free of camera topology and Flutter UI.

**Non-Goals:**

- Porting or mirroring lws-ui class structure / scheduling / MemoryCache edges.
- Re-implementing ping, eth0, MediaMTX, or Home/Monitor camera chrome.
- L001 / H034 / other non-Modbus sources.
- Camera deviceinfo HTTP; RGB LED refresh.
- Boot self-check Camera Comm item — already removed by archived `ipc-camera-async-status` (main `product-boot-self-check`); this change does not revisit the self-check checklist.

## Decisions

### 1. Source of truth = HAL `IpCameraHealth`, via product session

**Choice:** Adapter subscribes to `session.camera.health` (same controller the session already monitors).

| Phase | C002 active? |
|-------|----------------|
| `unknown` | No |
| `healthy` | No |
| `unhealthy` | Yes |

**Not:** `IpCameraUiPhase.failed` alone (folds attempt-budget / path UI). **Not:** a new ICMP timer in the warn feature.

Debounce / quiet windows stay in HAL — adapter is edge-only.

### 2. One coordinator, merged `AlarmSignalSource`

**Choice:** Thin App merge of `ModbusAlarmAttributeAdapter` + camera adapter into the existing single `WarnAlarmCoordinator.signals` slot (small `MergingAlarmSignalSource` in App is enough; package helper optional).

**Not:** Second coordinator, side-door dialogs, or camera-specific episode policy in App widgets.

### 3. Self-check = existing warn gate

**Choice:** Use `BootSelfCheckWarnGate` / `BootSelfCheckGate` already wired to the coordinator. Camera adapter emits health edges like Modbus; presentation stays suppressed while gated; Home already calls `flushPresentation()` when the gate opens.

**Not:** A camera-only monitor start/stop lifecycle copied from another product. **Not:** special-case history rules beyond what the existing gate + coordinator already do for other sources (unless a bug forces a tiny adapter deferral — prefer coordinator/gate consistency).

### 4. Severity + SFX via existing policy

**Choice:** Dialog INFO/WARN already uses `infoStyleForCode` → `LaserAlarmPolicy.treatBypassableAsInfo`. Extend `_syncWarnSound` to skip looping SFX when that predicate is true for the alerting code.

**Not:** A separate camera severity enum or warn-type table.

### 5. Laser interrupt on edges

**Choice:** After C002 rising/falling, call existing `LaserWorkGuard.evaluateAndInterruptIfNeeded` (episodes already include C002 once the adapter feeds the coordinator). Dangerous-ops toggle path already evaluates.

### 6. Monitor actives

**Choice:** Keep Alarm Information bound to `WarnAlarmController.monitor` / coordinator episodes. Spec: list includes non-Modbus C002 when the episode is active. Machine Status camera tile stays session UI phase (unchanged).

## Risks / Trade-offs

- **[Risk] C002 during path reconfigure** → Mitigation: HAL `unknown` / suspend probes; adapter ignores `unknown`.
- **[Risk] Duplicate rising on adapter restart** → Mitigation: last-emitted active bool; coordinator episode dedupe.
- **[Risk] INFO SFX change affects other bypassable codes** → Acceptable: same `treatBypassableAsInfo` predicate already used for dialog chrome.
- **[Risk] Drift from another product’s monitor timing** → Acceptable by design; this stack owns health cadence and gate semantics.

## Migration Plan

1. App-only: `make build-app` / `make push-app`.
2. No overlay/rootfs change.
3. Rollback: drop camera source from merge.

## Open Questions

- None blocking.
