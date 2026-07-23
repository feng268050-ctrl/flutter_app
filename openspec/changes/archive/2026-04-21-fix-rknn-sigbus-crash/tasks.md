## 1. RKNN session safety foundation

- [x] 1.1 Introduce a guarded RKNN session abstraction that owns `rknn_context` and tracks lifecycle states (`NEW/INITIALIZED/RUNNING/DESTROYED`).
- [x] 1.2 Route all RKNN call entry points through the guarded session so raw context handles are no longer used directly by dispersed call sites.
- [x] 1.3 Enforce per-session synchronization for `query/input/run/output/destroy` operations to prevent unsafe concurrent access.

## 2. Preflight validation and error mapping

- [x] 2.1 Implement preflight validators for RKNN inputs (pointer presence, alignment, size/index/fmt consistency, state checks) before runtime calls.
- [x] 2.2 Define normalized native error categories for validation, lifecycle, and runtime-return failures and map each guard failure path to these categories.
- [x] 2.3 Ensure invalid calls return controlled failures without invoking RKNN APIs or terminating the process.

## 3. Structured diagnostics and crash triage context

- [x] 3.1 Add structured RKNN stage diagnostics (`init/query/input/run/output/destroy`) with thread id/name, context id, stage, and result category.
- [x] 3.2 Persist latest stage/context markers so crash analysis can associate fatal native signals with the most recent RKNN stage transition.
- [x] 3.3 Integrate diagnostic emission with existing startup/crash-analysis sinks used by operators.

## 4. Verification and regression coverage

- [x] 4.1 Add native/unit tests for lifecycle state transitions, use-after-destroy rejection, and validator behavior.
- [x] 4.2 Add integration/instrumented tests for concurrent call attempts and destroy-during-run scenarios on AI inference threads.
- [x] 4.3 Run AI-related instrumented test suite and verify no fatal native crashes occur in guarded negative-path scenarios.
