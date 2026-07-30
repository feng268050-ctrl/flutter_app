## MODIFIED Requirements

### Requirement: Async overlapping detection is gated during boot self-check

While boot self-check is active, the App SHALL expose a process gate (`isActive`) so overlapping async **prompt dialogs** (warn frost and Home guidance) MUST NOT present competing dialogs. The product IP-camera session `start()` and Home camera status icon MAY run during self-check because they do not present a blocking popup. When self-check finishes (dialog dismissed or preference disabled), the gate SHALL clear and deferred prompts MAY present via the **global prompt queue** without a guidance-then-alarm phase barrier.

#### Scenario: Gate active during pipeline

- **WHEN** boot self-check dialog is showing or the pipeline is running
- **THEN** `BootSelfCheckGate.isActive` (or equivalent) SHALL be true

#### Scenario: Gate clears after dismiss

- **WHEN** boot self-check completes
- **THEN** the gate SHALL be inactive
- **AND** subsequent warn and guidance prompts MAY enqueue and present via the global prompt queue in FIFO order
- **AND** warn presentation MUST NOT wait for network/cloud guidance enrollment to complete

#### Scenario: Camera status icon may run during self-check

- **WHEN** boot self-check is active
- **AND** the product IP-camera session is running
- **THEN** the Home camera status icon MAY update
- **AND** the session MUST NOT show a competing modal that blocks the self-check dialog

### Requirement: Boot self-check suppresses warn presentation

While the boot self-check overlay is active, the product App MUST gate `cyber_alarm` so it does not present new modal warn dialogs for Modbus-backed alarm onsets. Self-check item evaluation MAY continue to use the same Alarm Information semantics for pass/fail tiles. After self-check completes (success or operator-dismissed failure path per existing rules), normal warn presentation SHALL resume for subsequent onsets via the global prompt queue and MUST NOT remain suppressed for guidance/network readiness.

#### Scenario: Alarm during self-check does not popup

- **WHEN** boot self-check is active
- **AND** a Modbus `alarm.*` attribute becomes true
- **THEN** the App MUST NOT show a modal warn dialog for that onset during the active self-check session

#### Scenario: After self-check resumes warns without guidance barrier

- **WHEN** boot self-check has finished
- **AND** a rising edge occurs for a catalogued alarm code (or flush presents a parked episode)
- **THEN** warn presentation MAY show a modal dialog via the global prompt queue
- **AND** MUST NOT wait for Wi‑Fi or cloud guidance prompts to enroll or finish
