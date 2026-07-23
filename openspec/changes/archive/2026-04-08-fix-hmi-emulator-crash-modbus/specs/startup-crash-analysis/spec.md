## ADDED Requirements

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
