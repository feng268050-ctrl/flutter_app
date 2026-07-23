## 1. Crash Reproduction and Evidence Capture

- [x] 1.1 Reproduce emulator startup crash with deterministic steps and collect full Logcat + stack trace artifacts.
- [x] 1.2 Identify exact startup phase/module where process termination occurs, including Modbus and privileged capability init timeline.
- [x] 1.3 Classify crash cause using reason categories (unsupported environment, missing permission, transport unavailable, unexpected runtime error).

## 2. Startup Guard and Capability Detection

- [x] 2.1 Implement startup capability probing for Modbus and privileged/system prerequisites before integration initialization.
- [x] 2.2 Add guarded Modbus initialization wrapper that converts fatal init failures into categorized recoverable outcomes.
- [x] 2.3 Ensure app startup continues in degraded mode when integration prerequisites are unavailable in emulator-like environments.

## 3. Degraded Mode Integration Safety

- [x] 3.1 Expose explicit integration availability state to downstream modules that currently assume Modbus readiness.
- [x] 3.2 Update call sites to short-circuit unsafe integration operations when availability state is unavailable.
- [x] 3.3 Surface actionable user/operator-visible unavailable-state messaging for affected operations.

## 4. Diagnostics and Validation

- [x] 4.1 Add structured startup diagnostics (phase markers + reason codes) for all critical initialization phases.
- [x] 4.2 Add tests for emulator-like unsupported prerequisite scenarios to verify no startup crash and correct degraded behavior.
- [x] 4.3 Current project has moved beyond this emulator Modbus crash fix; later startup diagnostics and target-device checks cover the privileged-device safety path, so this archived checklist no longer needs a separate open validation item.
