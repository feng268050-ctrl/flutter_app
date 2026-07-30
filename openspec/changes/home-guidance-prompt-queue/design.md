## Context

Product Home today: paint → optional boot self-check → Modbus live → warn start + `flushPresentation` → bundled-firmware prompt. Cloud bind/registration call `showCyberDialog` directly. Warn frost uses **two** queues (`WarnAlarmCoordinator._showQueue` + `CyberUiWarnPresentation._queue`).

A phase design (self-check → drain all guidance → then alarms) would block alarm popups on async Wi‑Fi/cloud. That is rejected. Instead: **one global FIFO prompt queue** for guidance and alarms; enqueue when ready; never hold the alarm path for network.

## Goals / Non-Goals

**Goals:**

- One App **global prompt queue**: at most one prompt dialog visible; FIFO across guidance + warn frost.
- Migrate warn presentation onto it; **delete** legacy warn UI queue(s).
- Guidance (Wi‑Fi tip, register, bind, …) enrolls into the same queue when eligible—network may be late without delaying earlier alarm entries.
- Suppress non–self-check prompts only while boot self-check is active; after that, pump continuously.
- Preserve warn SFX tied to visible warn dialog; episode/ack policy unchanged in spirit.

**Non-Goals:**

- Waiting for cloud/Wi‑Fi before starting warn coordinator or allowing alarm enqueue.
- Priority lanes / preempt (strict FIFO for this change).
- Putting episode domain logic into the global queue.
- OTA prompts; full lws-ui HomePrompt parity beyond listed kinds + infrastructure.
- Redesigning CyberUI chrome.

## Decisions

### 1. App `GlobalPromptQueue` is the sole modal FIFO

**Choice:** Module under `app/lws_hmi/lib/features/global_prompt/` (name flexible):

| Piece | Role |
|-------|------|
| `GlobalPromptRequest` | **Required unique** `id` (dedupe + dismiss key), optional kind tag (`warn`, `wifiConnect`, `deviceRegister`, …), `present(BuildContext) → Future` |
| `GlobalPromptQueue` | `enqueue` / `dismiss(id)` / pump; one dialog; await presenter until closed; then next |
| Scope | App-root; navigator key shared with warn host |

API sketch:

- `enqueue({required String id, required present}) → Future<void>` — completes when **that** entry has been shown and closed (same semantics as current `CyberUiWarnPresentation.show`). Same `id` already pending/showing → dedupe (no-op or replace).
- `dismiss(String id) → Future<void>` — drop pending by id, or pop the visible modal if `id` is showing (programmatic close; mirrors today’s warn `dismiss(code)`).

Warn entries use the alarm code as `id` (`H001`, `C002`, …). Guidance uses singleton ids (`deviceBind`, `deviceRegister`, `wifiConnect`, …).

**Why:** Matches proven warn UI queue behavior; one host for all prompts.

**Alternatives:** Separate guidance + warn queues with a mutex — rejected (two drains, ordering bugs). Phase barrier until network — rejected (delays alarms).

### 2. Migrate warn onto global queue; delete old queues

**Choice:**

- Implement `WarnPresentation` as an adapter: `show` / `update` / `dismiss` → `GlobalPromptQueue.enqueue` / remove-by-id / pop if showing. Warn frost UI (`WarnFrostShell` / `WarnDialogBody`) stays; only the **queue host** moves.
- **Delete** `CyberUiWarnPresentation`’s `Queue<_PendingWarn>` and private `_pump` (fold into global queue or replace the class with `GlobalPromptWarnPresentation`).
- **Delete** `WarnAlarmCoordinator`’s `_showQueue` / `_drainShowQueue` / `_pumpQueue` modal serialization. On “should show”, call `presentation.show` (global enqueue). While `WarnGate` suppresses, keep a **non-UI** pending set/list of codes and `flushPresentation` enqueues them when the gate opens—do not reintroduce a second modal pump.
- `showingCode` / SFX: derive from “global queue current entry is warn with this code” (callback/`onPresented`/`onClosed` as today).

**Why:** User requirement—one queue; old queues retired.

**Alternatives:** Keep coordinator `_showQueue` as thin gate park only—allowed as a pending set, not a parallel FIFO pump of modals.

### 3. Boot self-check gate only (no guidance phase)

**Choice:** `WarnGate` / global pump suppress while `BootSelfCheckGate.isActive` only. After self-check completes or is skipped: enable pump; Home may `warn.start` + `flushPresentation` **without** waiting for Wi‑Fi/cloud/guidance enrollment.

Guidance prompts enqueue whenever eligibility is known (possibly seconds later) and take their FIFO place **behind** whatever is already queued (including alarms that arrived first).

**Why:** Network must not stall alarms.

### 4. Guidance enrollment (same FIFO)

**Choice:**

- Cloud `onAuthError` / `onUsersProbe` → `enqueue(id: register|bind, …)` using existing dialog bodies.
- Wi‑Fi tip: enqueue once per process when eligible (e.g. Wi‑Fi wanted/enabled, not connected); dismiss / open settings.
- Bundled firmware: enqueue when candidate known (startup or return-to-Home), same queue—no parallel `showCyberDialog` during competing prompts.
- Dedupe: same `id` pending/showing → no-op or replace per kind policy (warn code id = alarm code; bind/register singleton ids).

### 5. Home bootstrap (updated)

```
Home painted
→ self-check (optional; suppresses global pump / warn show)
→ on complete: ensureModbusLive → warn.start → flushPresentation
→ guidance enrolls asynchronously as Wi‑Fi/cloud/firmware ready → same FIFO
```

No `await guidanceIdle` before warn flush.

### 6. Tests

- Unit: FIFO order (warn then late bind; bind then warn), dedupe, self-check park then flush, delete-path coverage that CyberUi private queue is gone.
- Coordinator tests updated for no `_showQueue` drain (gate pending + presentation mock = global fake).

## Risks / Trade-offs

- **[Risk] Late cloud bind jumps behind many alarms** → Acceptable under FIFO; document; priority is a future change if product wants bind first.
- **[Risk] Long bundled-firmware progress blocks following alarms** → Same as any long prompt; consider progress as one queue job (already true today when shown).
- **[Risk] Package coordinator refactor breaks tests** → Update `packages/cyber_alarm` tests in the same change; keep `WarnPresentation` contract.
- **[Trade-off] Strict FIFO vs “alarms always first”** → Explicitly FIFO as requested; no guidance-phase barrier.

## Migration Plan

1. Land `GlobalPromptQueue` + scope; wire navigator.
2. Point `WarnPresentation` at it; remove CyberUi warn UI queue; adjust coordinator show path; green tests.
3. Migrate register/bind/Wi‑Fi tip/firmware onto enqueue.
4. Board check: self-check → alarm can show before cloud returns; later bind does not stack; never two prompts.

Rollback: revert to dual warn queues + direct guidance dialogs (atomic PR preferred).

## Open Questions

- Wi‑Fi tip eligibility when Ethernet already online — prefer skip tip if any path reaches cloud.
- Whether `requestImmediateShow` (Laser Enable) should jump the FIFO later — out of scope; stays enqueue (may already be showing).
