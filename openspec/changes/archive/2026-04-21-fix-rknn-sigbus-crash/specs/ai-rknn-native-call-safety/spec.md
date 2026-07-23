## ADDED Requirements

### Requirement: RKNN context lifecycle SHALL be explicitly managed
The system SHALL create, track, and destroy each `rknn_context` through a single owned session abstraction that prevents use-after-destroy and rejects operations on uninitialized or destroyed contexts.

#### Scenario: Call on destroyed context is rejected
- **WHEN** an inference call is requested after the associated session has been destroyed
- **THEN** the system SHALL reject the call with a categorized lifecycle error
- **AND** the system SHALL NOT invoke the RKNN runtime API with that context handle

### Requirement: Context-bound RKNN calls SHALL be thread-safe
The system SHALL enforce serialized access for runtime operations bound to the same `rknn_context` so concurrent calls cannot mutate or consume shared state unsafely.

#### Scenario: Concurrent run requests target the same context
- **WHEN** two threads attempt `rknn_run` on the same context at overlapping times
- **THEN** the system SHALL serialize or reject one request according to the session policy
- **AND** the process SHALL remain alive without native fatal signals

### Requirement: Runtime boundary inputs SHALL be validated before RKNN calls
Before calling `rknn_inputs_set`, `rknn_run`, or `rknn_outputs_get`, the system SHALL validate required fields (buffer pointer presence, alignment constraints, size/index/fmt consistency, and session state) and fail fast on invalid inputs.

#### Scenario: Invalid input buffer metadata is detected preflight
- **WHEN** a caller provides input metadata with an invalid size or unsupported format mapping
- **THEN** the system SHALL return a validation error without invoking the underlying RKNN call
- **AND** diagnostics SHALL record the failed stage and validation category

### Requirement: Native RKNN stages SHALL emit structured diagnostics
The system SHALL record structured diagnostics for RKNN call stages (`init`, `query`, `input`, `run`, `output`, `destroy`) including stage identifier, thread metadata, context identifier, and result category for each failure or rejected call.

#### Scenario: Preflight rejection produces triage-ready diagnostics
- **WHEN** a preflight validation failure blocks an RKNN stage call
- **THEN** the system SHALL emit a diagnostic event containing stage, context id, thread info, and normalized error category
- **AND** the event SHALL be available to existing crash-analysis tooling paths
