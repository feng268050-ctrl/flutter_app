## Purpose

Define startup safety and diagnostics behavior for critical initialization paths so runtime-incompatible integrations do not crash app startup and failures are observable for operators.

## Requirements

### Requirement: Startup crash diagnostics are captured before process termination
The system SHALL record structured startup diagnostics for each critical initialization phase, including phase identifier, outcome, and failure reason code, before propagating any fatal startup exception.

#### Scenario: Startup phase fails with categorized error
- **WHEN** a critical startup phase throws an exception during initialization
- **THEN** the system records the phase identifier and categorized reason code in structured diagnostics
- **AND** the exception record includes module context needed for root-cause analysis

### Requirement: Environment-incompatible integrations do not crash app startup
The system SHALL treat environment-incompatible integration initialization (including unavailable Modbus dependencies) as a recoverable startup condition and continue app startup in a degraded mode.

#### Scenario: Emulator lacks Modbus prerequisites
- **WHEN** startup capability probing detects missing or unsupported Modbus prerequisites in emulator runtime
- **THEN** Modbus initialization is skipped or terminated safely without process crash
- **AND** the app transitions to degraded mode with integration-unavailable state

#### Scenario: Integration unavailable state is consumed safely
- **WHEN** a downstream module checks integration availability after degraded startup
- **THEN** the module receives explicit unavailable state instead of assuming Modbus readiness
- **AND** unsafe integration calls are avoided

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
