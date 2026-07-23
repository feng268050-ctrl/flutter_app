## 1. Core infrastructure

- [x] 1.1 Add `BootSelfCheckGate` with process-wide `isActive()` / `setActive(boolean)` used to suppress async warn popups during self-check.
- [x] 1.2 Add `BootSelfCheckItem` enum (or equivalent) defining the fixed check order, localized labels, and pass/fail evaluators aligned with `fragment_warn_info.xml` alarm semantics.
- [x] 1.3 Add `BootSelfCheckEvaluator` to perform synchronous Modbus reads (`createDeviceStatus`, `createDeviceData`) with bounded timeout and map results to pass/fail/skip.

## 2. Coordinator and async suppression

- [x] 2.1 Implement `BootSelfCheckCoordinator` (background worker + main-thread UI callbacks): append checking row, update pass/fail, auto-dismiss on completion, process-lifetime idempotency flag.
- [x] 2.2 Guard `DeviceDialogHandler.checkDeviceStatus` and `showCameraCommunicationDialog` to no-op while `BootSelfCheckGate` is active.
- [x] 2.3 On coordinator completion: clear gate, call `CameraCommunicationMonitor.startWhenHomeEntered`, and mark self-check completed for the process.

## 3. Self-check dialog UI

- [x] 3.1 Add dialog layout (`dialog_boot_self_check.xml` or equivalent) with title and scrollable list for dynamic item rows (name + status).
- [x] 3.2 Add `BootSelfCheckDialog` helper: non-cancelable, append/update rows, auto-dismiss after all items terminal.
- [x] 3.3 Add string resources for dialog title and row statuses (checking / pass / fail / skipped) in `values`, `values-en`, and `values-zh`.

## 4. MainActivity integration

- [x] 4.1 Remove immediate `CameraCommunicationMonitor.startWhenHomeEntered` from `MainActivity.initView`; trigger `BootSelfCheckCoordinator` instead (after WiFi onboarding hook when applicable).
- [x] 4.2 Ensure second home entry in same process skips self-check and starts `CameraCommunicationMonitor` if not already running.
- [x] 4.3 Run camera comm item via `CameraUtils.checkCameraBlocking()` inside the coordinator pipeline (not via periodic scheduler).

## 5. Validation

- [x] 5.1 Unit test `BootSelfCheckGate` suppresses `DeviceDialogHandler` popups while active and allows them after release.
- [x] 5.2 Unit test coordinator idempotency, item order, and `CameraCommunicationMonitor` deferred until completion.
- [x] 5.3 Unit test evaluator pass/fail mapping for comm-status and temperature items using fixture `DeviceStatus`/`DeviceData`.
- [x] 5.4 Manual QA on device: cold boot → home → self-check dialog shows all items → dialog closes → async C002/ping resumes; verify no duplicate self-check on home return.
