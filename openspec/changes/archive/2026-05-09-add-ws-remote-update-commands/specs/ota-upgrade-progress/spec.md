## ADDED Requirements

### Requirement: Remote-triggered upgrade MUST emit device.update_progress events
When upgrade execution is triggered by `command.update_system`, the device MUST push `device.update_progress` events throughout the update lifecycle so upstream services and clients can observe progress in near real time.

Each progress event MUST include correlation-safe and machine-readable fields (snake_case) to identify current phase and progress state.  
When upgrade fails or is aborted, a progress event describing failure state MUST be emitted before the flow terminates.

#### Scenario: Progress events are emitted during upgrade
- **WHEN** device has accepted `command.update_system` and enters update execution
- **THEN** device SHALL emit one or more `device.update_progress` events representing lifecycle progression until completion or failure

#### Scenario: Terminal failure is reported as progress event
- **WHEN** update execution fails after it has started
- **THEN** device SHALL emit a `device.update_progress` terminal failure event containing failure context before stopping upgrade flow

### Requirement: Progress event semantics MUST be consistent with OTA UI stages
The remote `device.update_progress` stage model MUST map to local OTA stages (download, post-download system upgrade, completion/failure) so that remote observers and on-device UI represent the same underlying state progression.

#### Scenario: Download stage maps to remote progress
- **WHEN** local OTA pipeline is in package download phase
- **THEN** emitted `device.update_progress` events SHALL use the designated download stage and include corresponding progress value

#### Scenario: System-upgrade stage maps to remote progress
- **WHEN** local OTA pipeline transitions from package download to system upgrade handling
- **THEN** emitted `device.update_progress` events SHALL reflect system-upgrade stage semantics consistent with local UI status
