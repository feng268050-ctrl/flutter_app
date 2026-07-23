# Warn Episode Architecture

## Problem

Warn popups were split across `WarnDialogUtil`, `WarnCacheManager`, `DemoAlarmStickyTracker`,
`GlobalSoundManager`, `DeviceStatusConvert.closeWarn`, Frost overlay lifecycle, and
`AutoDialogQueue`. Each layer had partial state, so fixes in one path broke another.

## Model

One **episode** per alarm code per fault cycle:

```
WarnEpisode (per errorCode)
├── phase: INACTIVE | FAULT_ACTIVE | OPERATOR_ACKED
├── policy.resistExternalAutoClose  (frozen at arm time; demo = true)
├── policy.demoSimulated            (make alarm; no Modbus bit required)
├── overlay: optional Frost handle  (0 or 1 global visible session)
└── audio: tied to overlay visibility for WARN_TYPE
```

### Invariants

1. **Overlay visible ⇔ coded warn sound playing** (same errorCode).
2. **Sound and overlay stop together** only on `CloseReason.OPERATOR` or
   `CloseReason.FAULT_RECOVERED` when `!policy.resistExternalAutoClose`.
3. **Policy is frozen at `armEpisode()`** — never toggled at dismiss time.
4. **Only `WarnEpisodeController` may** dismiss overlay, stop episode audio, or clear episode phase.

### Close reasons

| Reason | Who | Effect when resist=false | Effect when resist=true |
|--------|-----|--------------------------|-------------------------|
| OPERATOR | User taps 知道了 | Full teardown | Full teardown (clears resist) |
| FAULT_RECOVERED | Modbus / external clear | Full teardown | No-op |
| OVERLAY_REPLACED | Frost handoff (non-warn) | Reattach if resist | Reattach if resist |

### Laser enable

| Check | Source |
|-------|--------|
| Preflight block | Real fault OR demo episode in `FAULT_ACTIVE` (not yet acked) |
| Runtime interrupt | Same, honour dangerous-ops bypass for A001/C002/L001 only |
| After operator ack | Demo: episode inactive. Production: still blocked while Modbus fault bit set |

## API (`WarnEpisodeController`)

- `armEpisode(code, policy)` / `armDemoEpisode(code)` — rising edge
- `notifyFaultActive(code, policy)` — external fault (camera, lens, zero-point)
- `prepareModbusPassiveDialog(code)` — Modbus passive gating (`createSeriousHit`)
- `requestPassiveShow(vo)` / `requestImmediateShow(activity, vo)` — queue ingress
- `tryConsumeReminderForDialog(code)` / `markDialogOpen(code)` — queue task hooks
- `rearmReminder(code)` / `rearmReminderAfterOverlayHandoff(code)`
- `tryClose(code, reason)` — external recovery (`closeWarn` replacement)
- `acknowledgeOperator(code)` — confirm button
- `isFaultActive` / `isReminderPending` / `isBlockingLaser` / `isDemoFaultActive`
- `resistsExternalAutoClose` / `shouldProtectOverlay`

## Layering

```
Sources (Modbus, demo, camera, AI)
    → build WarnDialogVo
    → WarnEpisodeController.arm / requestShow / tryClose
        → AutoDialogQueue (scheduling only)
        → WarnDialogPresenter (Frost UI only; no policy)
        → GlobalSoundManager (audio driver; controller owns lifecycle)
```

## Migration

Phase 1 (done): controller owns phase, policy, close, ack, laser queries; `WarnDialogUtil` is presenter-only for Frost UI.

Phase 2 (done): removed `DemoAlarmStickyTracker`; demo state lives in `WarnEpisodePolicy.demoSimulated` +
`WarnEpisodeController.isDemoFaultActive()`. All warn popup ingress goes through
`requestPassiveShow()` / `requestImmediateShow()`.

Phase 3 (done): episode reminder / dialog / fault / resist state owned by {@link WarnEpisodeController};
{@link WarnEpisodePersistence} mirrors to {@link com.lasercyber.lws.ui.bean.entity.WarnMark}.
`WarnCacheManager` removed; all callers use the controller API.
