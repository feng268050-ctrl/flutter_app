## ADDED Requirements

### Requirement: Safe shutdown navigates to the dedicated upgrade page

Before starting whole-device transfer or verify-and-apply (including when triggered by host `make upgrade` at upload start), the HMI SHALL enter a safe state: stop any active laser/welding work session (including extinguishing laser output / ending in-progress jobs as defined by the product App), close work screens, and navigate **directly** to the **dedicated upgrade page**. The HMI MUST NOT use Home as an intermediate destination for this flow. Partition writes MUST NOT begin until this safe shutdown and upgrade-page navigation have completed (or the session fails closed without writing).

#### Scenario: make upgrade trigger stops work and opens upgrade page

- **WHEN** a host starts a whole-device upgrade session (before or as zip upload begins) while the operator is on a work screen (e.g. quick/engineer/monitor with an active session)
- **THEN** the HMI stops laser/work activity and navigates directly to the dedicated upgrade page
- **AND** MUST NOT begin partition writes before that page is showing the session
- **AND** MUST NOT require navigating to Home first

#### Scenario: Cloud or Settings confirm also safe-shuts down to upgrade page

- **WHEN** the operator confirms a cloud/Settings whole-device update while a work session is active
- **THEN** the HMI performs the same safe shutdown and navigates directly to the dedicated upgrade page before download/apply proceeds

### Requirement: Dedicated upgrade page unifies transfer as download progress

Whole-device OTA progress SHALL be shown on a **dedicated upgrade page** (full-screen route) driven by `cyber_ota` progress callbacks — not as a dialog layered on top of laser work screens. The **transferring** phase SHALL be presented to the operator as **download** progress for both cloud HTTP download and host `make upgrade` zip upload (host upload bytes are mapped into the same download/transfer UX). Subsequent extract, verify, and burn/write progress SHALL use the same page. The upgrade page SHALL NOT provide laser firing or welding/job start controls. While partition writes are in progress, the operator MUST NOT be offered a control that cancels an in-flight write. The page SHALL remain until apply finishes successfully (reboot requested) or fails with an error state.

#### Scenario: Host upload appears as download progress on upgrade page

- **WHEN** `make upgrade` is uploading the OTA zip and the on-device session is active
- **THEN** the dedicated upgrade page shows advancing download/transfer progress that reflects uploaded bytes
- **AND** after the zip is complete, the same page advances through extract/verify/burn as applicable

#### Scenario: Cloud download uses the same upgrade page

- **WHEN** a cloud/Settings-initiated download of the OTA zip runs (or continues) on the upgrade page
- **THEN** the HMI shows download progress on the dedicated upgrade page and then extract/verify/burn for the subsequent phases

#### Scenario: Upgrade page has no laser job entry

- **WHEN** the dedicated upgrade page is visible
- **THEN** the operator cannot start laser output or a welding/cutting/cleaning job from that page

#### Scenario: Verify failure surfaces error without claiming flash success

- **WHEN** signature verification fails after ingress/extract
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
