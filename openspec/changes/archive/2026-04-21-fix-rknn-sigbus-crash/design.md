## Context

`librknnrt.so` crashes in production show `SIGBUS (BUS_ADRALN)` and invalid jump address (`pc=0xffffffff`) on `mj-laser-thread`. Hash and load-path verification indicate the runtime binary itself is the expected packaged file, so the dominant risk is app-side misuse at native call boundaries (invalid buffers, stale context handles, or thread-unsafe access patterns).

The current JNI/native path spans Java orchestration, `NativeBridge`, and `libai.so` wrapper calls. Failures in this boundary are currently fatal and not consistently diagnosable by call stage.

## Goals / Non-Goals

**Goals:**
- Prevent process crashes caused by invalid RKNN call inputs, destroyed contexts, or unsafe concurrent access.
- Define deterministic context lifecycle rules and enforce them in one place.
- Improve observability with structured per-stage native diagnostics for triage and regression detection.
- Add tests that prove guardrails: invalid usage returns controlled errors rather than terminating the app process.

**Non-Goals:**
- Replacing RKNN runtime, model format, or inference algorithm behavior.
- Introducing remote crash collection infrastructure beyond existing app diagnostics paths.
- Broad refactor of unrelated AI pipeline components not involved in RKNN lifecycle and call safety.

## Decisions

1. **Centralize RKNN context ownership in a guarded session abstraction**
   - Introduce a native-side `RknnSession` (or equivalent existing wrapper enhancement) that owns `rknn_context`, lifecycle state (`NEW`, `INITIALIZED`, `RUNNING`, `DESTROYED`), and synchronization primitive.
   - Rationale: one owner with explicit state transitions removes ambiguous direct-handle usage.
   - Alternative considered: keep raw context passing with scattered checks in each call site. Rejected due to duplicated logic and high bypass risk.

2. **Serialize context-bound RKNN calls per session**
   - Enforce single-flight execution per `rknn_context` for `query/input/run/output/destroy` by mutex/lock discipline in wrapper APIs.
   - Rationale: prevents concurrent mutation and use-after-destroy patterns.
   - Alternative considered: lock-free usage with caller contracts only. Rejected because current crash evidence suggests contract violations already happen.

3. **Apply strict preflight validation before every runtime boundary call**
   - Validate nullability, alignment, size/index/fmt ranges, and session state before invoking RKNN APIs.
   - Convert validation failures into explicit typed error codes/events and short-circuit calls.
   - Alternative considered: rely on RKNN internal validation. Rejected because failures currently escalate to native crashes.

4. **Emit stage-scoped structured diagnostics**
   - Add consistent event payload fields: stage (`init/query/input/run/output/destroy`), thread name/id, context id, validation outcome, error category, and native return code if present.
   - Rationale: enables quick discrimination between input, lifecycle, and runtime-origin failures.
   - Alternative considered: keep logcat-only freeform logs. Rejected due to poor triage value and inconsistent fields.

5. **Add multi-layer tests for lifecycle and concurrency misuse**
   - Unit tests for session state machine + validation.
   - Integration/instrumented tests for repeated inference, concurrent call attempts, and destroy-while-running scenarios.
   - Rationale: crash prevention must be regression-tested under realistic thread behavior.

## Risks / Trade-offs

- **[Risk] Increased synchronization may reduce peak throughput** -> **Mitigation:** serialize only per context, allow parallelism via multiple independent sessions if needed.
- **[Risk] Additional validation may reject previously tolerated malformed inputs** -> **Mitigation:** classify errors and update callers to provide compliant buffers.
- **[Risk] Native wrapper changes may affect existing JNI contracts** -> **Mitigation:** preserve public API shape where possible and add compatibility tests across existing call sites.
- **[Risk] Crash may include hidden runtime bug beyond caller misuse** -> **Mitigation:** keep runtime return/error telemetry; if crashes persist after guardrails, escalate with reproducible diagnostics package.

## Migration Plan

1. Implement guarded session abstraction and wire all RKNN call sites through it.
2. Land validation and structured diagnostics with feature parity for existing success paths.
3. Add and pass unit + instrumented concurrency/lifecycle tests.
4. Roll out to internal testing with targeted stress scenarios on `mj-laser-thread` equivalents.
5. If regression appears, rollback by disabling new guarded path behind integration flag and restoring previous invocation path while preserving diagnostics.

## Open Questions

- Should the app support multi-session parallel inference immediately, or keep single-session semantics until stability is validated?
- Which existing diagnostics sink is canonical for RKNN structured events in release builds?
- Do we need a temporary runtime kill-switch to bypass RKNN calls when repeated validation failures are detected?
