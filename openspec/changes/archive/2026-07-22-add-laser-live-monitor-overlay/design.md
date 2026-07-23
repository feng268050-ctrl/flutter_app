## Context

Product design is captured in `docs/laser-live-monitor-overlay-design.md` (方案 A). Today:

- **Engineer Mode**: Laser Enable ON + gun rising edge opens `WorkStatusDialogBuilder.createShowNoButtonDialog` → `MachineStatusOverlay.show(ctx, false)` with gauges-only `MachineStatusDialogFragment`.
- **Quick Mode welding**: detect pipeline already runs via `LivePr1InferenceStreamCoordinator`, but `GeneralOperationsFragment.deviceStatusListen` does **not** open the gun overlay. Logo “More Monitor” already calls `MachineStatusOverlay.show(ctx, true)`.
- Detect results publish on `StreamDetectResultBus`; AI Vision preview patterns exist (`DetectionOverlayView`, EasyPlayer PR1).

Constraints: FrostDialog shell stays; do not own pipeline lifecycle from UI; CNC out of scope; Recording Work / Modbus enable gates unchanged.

## Goals / Non-Goals

**Goals:**

- Shared Live Monitor body (PR1 + boxes + compact gauges) for gun auto and More Monitor.
- Quick welding pages match Engineer gun open/close semantics via `WorkStatusDialogBuilder`.
- Overlay is subscribe-only for detect; dismiss stops preview only.

**Non-Goals:**

- CNC Cut / CNC UI.
- Rebuilding phone Monitor HTTP/SSE inside the overlay.
- Porting full `AiVisionFragment` (offline, pinch tutorial, etc.).
- Alarm-list SSE UI in v1.
- Changing Laser Enable Modbus / reminder / alarm interrupt flows.

## Decisions

### 1. Single body fragment, two entry modes

- **Decision**: `#work_status_content` hosts `LaserLiveMonitorOverlayFragment` for both `showConfirm=false` (gun) and `showConfirm=true` (More Monitor).
- **Why**: Avoid dual UIs; only confirm-bar differs.
- **Alternatives**: Separate fragments per entry — rejected (duplication).

### 2. Trigger / close ownership

- **Decision**: Gun path exclusively through `WorkStatusDialogBuilder` (create / scheduleCloseOnGunOff / closeDialogDelayMillis / clearInstance). More Monitor uses `MachineStatusOverlay.show(..., true)` directly.
- **Conflict rule (v1)**: If gun auto overlay already visible, More Monitor tap reuses active Handle / no-op (do not flip confirm bar mid-flight).
- **Why**: Matches existing singleton Handle model; reduces gun-off dismiss clobbering intentional confirm UX.
- **Alternatives**: Promote confirm bar when More Monitor tapped — deferred.

### 3. Preview URL and player

- **Decision**: Always `MediaMtxRelayUrls.localPr1()` via EasyPlayer (or existing PR1 helper). Stop asynchronously on dismiss.
- **Why**: Keeps PR0 process-video recording bandwidth separate.
- **Alternatives**: PR0 preview — rejected (recording contention).

### 4. Detection subscription

- **Decision**: Fragment registers on `StreamDetectResultBus`, maps to `DetectionOverlayView` boxes (v1: lens_det / existing live overlay mapper parity with AI Vision live). Clear boxes on stale/empty. Do not start/stop `NativeStreamDetectCoordinator`.
- **Why**: Pipeline already tied to Laser Enable; overlay must not double-own sessions.
- **Alternatives**: Extend `StreamDetectOverlayBridge` gate — optional later if bus wiring is awkward.

### 5. Gauges sidebar

- **Decision**: Compact sidebar reuses dialog-variant frosted gauge/tile components and Modbus MemoryCache bindings from current machine-status dialog (field set 1:1 for v1).
- **Why**: Satisfies glass-card specs and operator familiarity.
- **Alternatives**: Minimal numeric-only strip — deferred.

### 6. Quick Mode wiring

- **Decision**: Mirror `EngineerModeActivity.openWorkStatusDialog` gun-edge logic inside `GeneralOperationsFragment` (only when Laser Enable open; ignore CNC fragment). End of work / destroy closes via Builder.
- **Why**: Spec alignment without CNC bleed.

### 7. Title copy (v1)

- **Decision**: Keep existing `real_time_machine_status_text` for v1; optional “Live Monitor” rename in polish phase.
- **Why**: Avoid string churn blocking body work.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| EasyPlayer `stop` on main → ANR | Async stop on dismiss; match proven patterns |
| PR0 Recording Work + PR1 preview load | PR1-only preview; field-check concurrent recording |
| Gun-off closes More Monitor instance | Builder only dismisses instances it opened; regression test dual entry |
| CNC accidentally gets gun overlay | Scope code to `GeneralOperationsFragment` only |
| Empty boxes when Laser OFF + More Monitor | Accepted empty state; show preview + gauges |
| Preloader layout mismatch | Update `MachineStatusOverlayPreloader` with new body |

## Migration Plan

1. Ship fragment + overlay attach behind same entry points (no feature flag required if body is additive).
2. Engineer gun path picks up new body automatically.
3. Quick gun path enable + keep More Monitor.
4. Rollback: revert overlay attach to `MachineStatusDialogFragment` if critical; pipeline unaffected.

## Open Questions

Resolved for implementation defaults (see Decisions): gauges 1:1; lens_det-first boxes; title keep; More Monitor while gun overlay → reuse/no-op.

Remaining optional polish:

1. Whether HUD status line ships in Phase 1 or Phase 2.
2. Whether zero-point boxes overlay in addition to lens_det in v1 (default: no).
