## Why

Recent production crashes show `SIGBUS (BUS_ADRALN)` with `pc=0xffffffff` inside `librknnrt.so` on `mj-laser-thread`. Existing evidence rules out runtime-file mismatch and points to unsafe native call inputs, lifecycle management, or concurrent context access in the RKNN invocation path, so we need explicit safety guarantees to prevent process-level crashes.

## What Changes

- Add defensive validation and lifecycle guards around RKNN native calls (`rknn_init`, `rknn_query`, `rknn_inputs_set`, `rknn_run`, `rknn_outputs_get`, `rknn_destroy`).
- Introduce strict context ownership and thread-safety rules so a single `rknn_context` cannot be used after destroy or concurrently by unsafe call paths.
- Add input buffer sanity checks (pointer validity, alignment, size/fmt/index consistency) before crossing into runtime APIs.
- Add structured crash-focused diagnostics for RKNN call stages and failure categories to speed up root-cause analysis.
- Add regression tests that exercise multi-thread and invalid-input scenarios to verify graceful failures instead of native process termination.

## Capabilities

### New Capabilities
- `ai-rknn-native-call-safety`: Define required validation, lifecycle, and concurrency safety behavior for app-side RKNN native integration to avoid fatal native crashes.

### Modified Capabilities
- `startup-crash-analysis`: Extend diagnostics requirements to include RKNN inference-stage structured failure metadata for native crash triage.

## Impact

- Affected code: `libai.so` integration path, JNI bridge wrappers, AI inference orchestration, and related tests.
- Affected systems: on-device AI inference runtime stability and crash observability.
- Dependencies: RKNN runtime integration APIs and existing AI library bootstrap/install flow remain in use; this change adds stronger guardrails around call boundaries.
