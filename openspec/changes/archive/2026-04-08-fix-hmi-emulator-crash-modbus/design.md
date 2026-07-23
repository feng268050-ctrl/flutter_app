## Context

The app crashes during startup on Android Studio emulators, with initial evidence suggesting the Modbus initialization path triggers a fatal failure when hardware/system prerequisites are unavailable. Current startup behavior appears to treat some environment-dependent integrations as mandatory, which is acceptable on fully provisioned devices but brittle in emulator and partially provisioned environments.

This change spans startup orchestration, system capability detection, error handling, and diagnostics. It also affects behavior covered by existing privileged runtime requirements, so the design must preserve strict behavior on supported deployments while preventing process death on unsupported ones.

## Goals / Non-Goals

**Goals:**
- Ensure startup does not crash when Modbus or other privileged/system dependencies are unavailable in emulator-like environments.
- Preserve existing privileged behavior when prerequisites are satisfied on real target deployments.
- Introduce deterministic diagnostics to identify root cause of startup failures quickly.
- Make degraded runtime state explicit to the UI/service layer so downstream modules can avoid unsafe calls.

**Non-Goals:**
- Replacing the Modbus stack or redesigning all communication architecture.
- Guaranteeing full Modbus feature parity in emulator environments.
- Broad refactor of unrelated app lifecycle components.

## Decisions

- Add explicit runtime environment capability probing at startup before Modbus/system integration initialization.
  - Rationale: Avoid eager initialization that assumes privileged/system resources are always available.
  - Alternative considered: Keep eager initialization and catch top-level exceptions only. Rejected because it can still leave partially initialized state and poor diagnostics.

- Introduce a guarded initialization wrapper for Modbus and privileged operations with typed failure categories (unsupported environment, permission missing, transport unavailable, unexpected runtime error).
  - Rationale: Categorized failures enable deterministic fallback behavior and user/developer visibility.
  - Alternative considered: Generic try/catch with one fallback path. Rejected due to weak observability and hard-to-debug regressions.

- Continue app startup in degraded mode when capability probing or guarded initialization indicates unsupported prerequisites, instead of terminating process.
  - Rationale: Emulator usability and local validation require core app shell to remain operational.
  - Alternative considered: Hard fail on any integration init failure. Rejected because it blocks all non-hardware workflows.

- Add structured startup diagnostics (phase markers + reason codes) and ensure fatal exception handlers include integration context.
  - Rationale: Faster root-cause analysis for environment-specific crashes and reduced triage time.
  - Alternative considered: Rely on default stack traces only. Rejected due to insufficient contextual evidence.

## Risks / Trade-offs

- [Risk] Degraded mode may mask integration regressions on real devices if capability detection is too permissive. -> Mitigation: Require strict checks for production prerequisites and include telemetry/log signals whenever degraded mode is activated.
- [Risk] Additional startup branching can increase complexity. -> Mitigation: Centralize decision logic in one startup capability gate module and keep clear reason-code enums.
- [Risk] Existing flows may implicitly assume Modbus is always available. -> Mitigation: Expose explicit availability state and require call sites to guard behavior through that state.
- [Risk] Logging changes could be noisy. -> Mitigation: Use bounded structured events at startup phases instead of verbose continuous logs.
