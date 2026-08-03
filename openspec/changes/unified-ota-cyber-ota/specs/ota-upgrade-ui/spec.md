## ADDED Requirements

### Requirement: Safe shutdown returns to Home before whole-device apply

Before starting whole-device verify-and-apply (including when triggered by host `make upgrade` after upload), the HMI SHALL enter a safe state: stop any active laser/welding work session (including extinguishing laser output / ending in-progress jobs as defined by the product App), close work screens, and navigate back to **Home**. Partition writes MUST NOT begin until this safe shutdown and Home navigation have completed (or the session fails closed without writing).

#### Scenario: make upgrade trigger stops work and returns Home

- **WHEN** a host finishes uploading a signed bundle and triggers the on-device OTA session while the operator is on a work screen (e.g. quick/engineer/monitor with an active session)
- **THEN** the HMI stops laser/work activity, returns to Home, and only then proceeds into the upgrade UI
- **AND** MUST NOT begin partition writes before Home is reached

#### Scenario: Cloud or Settings confirm also safe-shuts down

- **WHEN** the operator confirms a cloud/Settings whole-device update while a work session is active
- **THEN** the HMI performs the same safe shutdown and Home navigation before the dedicated upgrade page runs apply

### Requirement: Dedicated upgrade page shows burn progress without laser work

Whole-device OTA progress (verify and burn/write, and in-progress download when applicable) SHALL be shown on a **dedicated upgrade page** (full-screen route) driven by `cyber_ota` progress callbacks — not as a dialog layered on top of laser work screens. The upgrade page SHALL NOT provide laser firing or welding/job start controls. While partition writes are in progress, the operator MUST NOT be offered a control that cancels an in-flight write. The page SHALL remain until apply finishes successfully (reboot requested) or fails with an error state.

#### Scenario: Host upload completion opens dedicated upgrade page

- **WHEN** a host finishes uploading a signed bundle under `/userdata/ota/` and triggers the on-device OTA session
- **THEN** after safe shutdown to Home, the HMI navigates to the dedicated upgrade page and advances burn progress as writes proceed

#### Scenario: Cloud download uses the same upgrade page

- **WHEN** a cloud/Settings-initiated download of required images completes successfully (or continues on the upgrade page)
- **THEN** the HMI shows burn/write progress on the dedicated upgrade page for the subsequent verify-and-apply phase

#### Scenario: Upgrade page has no laser job entry

- **WHEN** the dedicated upgrade page is visible
- **THEN** the operator cannot start laser output or a welding/cutting/cleaning job from that page

#### Scenario: Verify failure surfaces error without claiming flash success

- **WHEN** signature verification fails after ingress
- **THEN** the upgrade page or error UI reports failure and MUST NOT claim that partitions were successfully updated

### Requirement: Settings check-for-updates uses cyber_ota

Device Information OTA footer controls (**Check for Updates**, **Automatically check for updates**) SHALL invoke `cyber_ota` for check (and, after operator confirmation when an update exists, for download+apply via the safe-shutdown and dedicated upgrade page flow). They MUST NOT report a false success when no client is wired, and MUST NOT remain permanently deferred once this capability is implemented.

#### Scenario: Check for Updates runs manifest check

- **WHEN** the operator activates Check for Updates and the network/manifest path is available
- **THEN** the UI reflects whether an update is available based on `cyber_ota` version compare

### Requirement: Whole-device OTA excludes concurrent control-board flash

While a whole-device `cyber_ota` apply session is writing partitions (or the dedicated upgrade page holds an active apply session), the system SHALL refuse to start a concurrent control-board Modbus firmware transfer, and the reverse SHALL hold while a control-board transfer is active (existing coordinator extended to cover whole-device OTA).

#### Scenario: Control-board upgrade blocked during OTA write

- **WHEN** a whole-device apply is in the writing phase
- **THEN** a request to start bundled/control-board firmware transfer is rejected or deferred until OTA finishes
