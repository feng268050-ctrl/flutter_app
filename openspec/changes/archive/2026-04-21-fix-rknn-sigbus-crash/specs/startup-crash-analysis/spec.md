## ADDED Requirements

### Requirement: RKNN native stage failures SHALL be captured as structured diagnostics
For AI inference paths that use RKNN runtime integration, the system SHALL capture structured diagnostics when lifecycle guards or runtime-boundary validation fails, including stage (`init`, `query`, `input`, `run`, `output`, `destroy`), failure category, thread identity, and context correlation metadata.

#### Scenario: RKNN validation failure is recorded with stage context
- **WHEN** RKNN input preflight validation fails in a worker thread
- **THEN** the system SHALL persist or emit a diagnostic record containing the RKNN stage and categorized reason code
- **AND** the diagnostic payload SHALL include module/thread context sufficient for root-cause triage

### Requirement: Fatal RKNN-native crashes SHALL preserve latest stage context
If a process-terminating native signal occurs during RKNN integration, the system SHALL persist the latest known RKNN stage and context correlation metadata prior to crash termination when such metadata was previously recorded in-memory during the call chain.

#### Scenario: Crash follows runtime invocation after stage tracking
- **WHEN** a fatal native signal happens after the app has recorded RKNN stage transitions for an active inference session
- **THEN** crash diagnostics SHALL include the latest stage marker and associated context identifier
- **AND** operators SHALL be able to distinguish lifecycle/validation-stage failures from post-dispatch runtime failures
