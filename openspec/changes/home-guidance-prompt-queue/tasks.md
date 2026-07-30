## 1. Global prompt queue

- [x] 1.1 Add `features/global_prompt/` with request model, FIFO `GlobalPromptQueue` (required unique `id`, enqueue / `dismiss(id)` / single-modal pump / dedupe by id)
- [x] 1.2 Wire app-root scope + shared `navigatorKey` so warn, cloud, and Home enrollments share one instance
- [x] 1.3 Suppress pump (or refuse present) while `BootSelfCheckGate.isActive`; resume after self-check completes/skips
- [x] 1.4 Unit tests: FIFO order, dedupe, await-until-closed, `dismiss` pending vs showing, self-check park then pump

## 2. Migrate warn; delete old queues

- [x] 2.1 Implement `WarnPresentation` adapter that enqueues warn frost onto `GlobalPromptQueue` (keep frost UI bodies)
- [x] 2.2 Remove `CyberUiWarnPresentation` internal `Queue` / private `_pump` (replace or thin-wrap)
- [x] 2.3 Remove `WarnAlarmCoordinator` modal `_showQueue` / `_drainShowQueue` pump; keep gate-parked pending set + `flushPresentation` → `presentation.show`
- [x] 2.4 Keep SFX / `showingCode` / `onPresented` / `onClosed` / ack wiring working with the adapter
- [x] 2.5 Update `packages/cyber_alarm` and App warn tests for the new presentation path

## 3. Enroll guidance on the same queue

- [x] 3.1 Refactor `DeviceRegistrationDialogs` / cloud hooks to `enqueue` register + bind (no independent stack)
- [x] 3.2 Add Wi‑Fi connection tip + l10n; enqueue once per process when eligible
- [x] 3.3 Enroll bundled-firmware Home prompt onto the global queue (startup + return-to-Home)
- [x] 3.4 Ensure Home bootstrap still does self-check → Modbus → warn start/flush **without** awaiting network/guidance

## 4. Verification

- [x] 4.1 `flutter analyze` / unit tests for queue + warn adapter + coordinator
- [x] 4.2 Manual: self-check on/off; alarm can show before cloud returns; late bind/register FIFO behind; never two prompts; old warn UI queue code gone (see `manual-checklist.md`)
