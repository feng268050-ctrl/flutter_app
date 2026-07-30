## Why

Boot self-check already owns its overlay, but guidance prompts (Wi‑Fi tip, device registration, device bind, …) still fire ad hoc from async network/cloud hooks, while warn frost uses a separate dual queue (`WarnAlarmCoordinator` + `CyberUiWarnPresentation`). Two hosts race. A prior idea—drain all guidance before opening alarms—would **stall alarm popups** until Wi‑Fi/cloud settle, which is unacceptable. Operators need **one global prompt FIFO**: at most one prompt modal at a time; guidance and alarms enqueue as they become ready, without waiting on the network to “finish.”

## What Changes

- Add an App-owned **global prompt queue manager** (modeled on the current warn UI queue): FIFO enqueue, single modal pump, dedupe, await-until-closed per entry.
- Migrate **warn/alarm frost dialogs** onto that global queue via the existing `WarnPresentation` port.
- **Remove / delete** the old presentation queues: `CyberUiWarnPresentation`’s internal `Queue<_PendingWarn>`, and the coordinator’s modal drain queue (`_showQueue` / `_drainShowQueue`) once presentation is solely global-FIFO (gate parking may remain as a non-UI pending set).
- Enroll guidance prompts (Wi‑Fi connect tip, device registration, device bind; extensible, e.g. bundled firmware) into the **same** FIFO—no separate guidance-phase gate that blocks alarms.
- Keep **boot self-check** as the only startup overlay that suppresses other prompts while active; after it closes (or is skipped), the global queue may pump freely. Alarms MUST NOT wait for cloud/Wi‑Fi eligibility.
- Clarified ownership: episode policy stays in `cyber_alarm`; **modal serialization** is App global queue only.

## Capabilities

### New Capabilities
- `global-prompt-queue`: Process-wide prompt modal host — FIFO for guidance + warn dialogs, single prompt at a time, pump after boot self-check, replace legacy warn UI queues.

### Modified Capabilities
- `cyber-alarm`: Warn presentation SHALL enqueue through the App global prompt queue; coordinator MUST NOT maintain a second modal presentation FIFO; gate still suppresses show calls (or pump) only while boot self-check is active.
- `product-boot-self-check`: After self-check, overlapping prompts resume via the global queue (no “guidance-then-alarm” phase). Warn gating remains self-check-only for presentation suppress.
- `device-registration-ui`: Bind and registration dialogs MUST enqueue on the global prompt queue (not independent `showCyberDialog` stacks).
- `product-home-ui`: Home bootstrap opens warn + enrolls guidance into the shared queue after self-check without delaying first paint or waiting on network for alarm eligibility.

## Impact

- **App:** new `features/global_prompt/` (or equivalent) queue + scope; refactor `CyberUiWarnPresentation` into a thin adapter that enqueues warn frost jobs; cloud hooks + Wi‑Fi tip + optional bundled-firmware enroll into the same queue; delete private warn UI queue code.
- **Package `cyber_alarm`:** simplify coordinator presentation pumping (remove `_showQueue` modal drain); keep episodes, history, `WarnGate`, `flushPresentation` for gate-parked codes.
- **Out of scope:** OTA Home prompts; changing boot self-check item pipeline; priority/preempt over FIFO (strict FIFO unless a later change adds priority).
