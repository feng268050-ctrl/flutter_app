# global-prompt-queue Specification

## Purpose

Process-wide FIFO host for operator **prompt** dialogs (guidance, warn/alarm frost, remote lock, bundled-firmware confirm, and similar App-level prompts). Serializes presentation so at most one prompt modal is visible. Page-local confirmations inside a Settings or mode flow are out of scope unless product policy enrolls them.

## Requirements

### Requirement: Prompt dialogs use the global prompt queue by default

Unless a capability **specially documents** an exemption, process-wide operator prompt dialogs SHALL enqueue onto the App `GlobalPromptQueue` and MUST NOT open via an independent modal host that can stack over another prompt. In scope by default: Wi‑Fi connection tip, device registration, device bind, remote lock feedback, bundled-firmware Home confirm, and warn/alarm frost. Boot self-check uses its own Home overlay and is the documented pump-suppress gate (not a second competing prompt host for guidance/warn/lock).

#### Scenario: Remote lock uses the queue

- **WHEN** remote lock feedback must be shown (cloud lock or locked entry gate)
- **THEN** the lock prompt SHALL be enqueued on the global prompt queue with stable id `remoteLock`
- **AND** MUST NOT bypass the queue with a direct overlay host
- **AND** unlock MUST `dismiss('remoteLock')`

#### Scenario: Exemption must be explicit

- **WHEN** a future prompt is allowed to bypass the global queue
- **THEN** that capability’s specification MUST state the exemption and rationale
- **AND** the default remains enqueue-on-global-queue

### Requirement: Global prompt queue serializes all prompt dialogs

The App SHALL provide a process-wide global prompt queue that presents prompt dialogs one at a time in FIFO order. Enqueue MAY occur whenever a prompt becomes eligible. The queue MUST support dedupe by stable id so the same logical prompt does not stack multiple pending entries. At most one prompt modal SHALL be visible at a time.

#### Scenario: FIFO across guidance and warn

- **WHEN** a warn prompt is enqueued
- **AND** later a device-bind guidance prompt is enqueued while the warn dialog is still pending or showing
- **THEN** the bind dialog MUST NOT appear until the warn dialog has been dismissed
- **AND** the bind dialog SHALL appear next if it remains at the head of the queue

#### Scenario: Late guidance does not block earlier alarms

- **WHEN** boot self-check has finished
- **AND** a warn prompt becomes eligible before cloud/Wi‑Fi guidance eligibility is known
- **THEN** the warn dialog MAY be shown without waiting for network or cloud enrollment
- **AND** a later-enqueued guidance prompt SHALL follow in FIFO order

#### Scenario: Duplicate id does not stack

- **WHEN** a prompt with id `deviceBind` is already pending or showing
- **AND** another enroll with the same id arrives
- **THEN** the queue MUST NOT show two bind dialogs stacked

### Requirement: Each prompt has a unique id and can be dismissed programmatically

Every global prompt queue entry SHALL carry a unique stable string `id` (examples: alarm code `H001`, `deviceBind`, `wifiConnect`, `remoteLock`). Callers MUST pass that id on enqueue. The queue SHALL expose programmatic `dismiss(id)` that:

- removes a **pending** entry with that id without showing it, and completes its waiters; and
- if that id is the **currently showing** prompt, closes the visible modal (navigator pop or equivalent) so the pump can advance to the next entry.

Operator confirm/cancel on the dialog itself remains valid and MUST also complete the entry.

#### Scenario: Dismiss pending by id

- **WHEN** a prompt with id `deviceBind` is pending behind another dialog
- **AND** the App calls `dismiss('deviceBind')`
- **THEN** that entry MUST be removed from the queue
- **AND** MUST NOT appear later solely because it was previously enqueued

#### Scenario: Dismiss showing by id

- **WHEN** a prompt with id `H001` is currently visible
- **AND** the App calls `dismiss('H001')`
- **THEN** the visible dialog MUST close
- **AND** the queue SHALL proceed to the next pending entry if any

#### Scenario: Dismiss showing remote lock on unlock

- **WHEN** a prompt with id `remoteLock` is pending or visible
- **AND** remote unlock clears the lock flag
- **THEN** the App MUST `dismiss('remoteLock')` (or equivalent)
- **AND** the lock dialog MUST NOT remain visible after unlock

### Requirement: Warn presentation uses the global prompt queue

Warn/alarm frost dialogs SHALL be shown by enqueuing onto the App global prompt queue through the `WarnPresentation` port. Dialog chrome for those entries SHALL use `packages/cyber_alarm_ui` frost shell/body widgets. The App MUST NOT maintain a separate warn-only UI modal FIFO (`CyberUiWarnPresentation` internal queue or equivalent). The `cyber_alarm` coordinator MUST NOT maintain a second modal presentation drain queue for showing dialogs.

#### Scenario: Warn show goes through global queue

- **WHEN** the coordinator requests presentation for alarm code `H001`
- **THEN** the warn frost dialog SHALL be hosted as a global prompt queue entry
- **AND** MUST NOT open via a parallel private warn UI queue

#### Scenario: Legacy warn UI queue removed

- **WHEN** this capability is implemented
- **THEN** the product warn host MUST NOT contain a separate `Queue` of pending warn dialogs used as a second modal pump

#### Scenario: Warn frost chrome from cyber_alarm_ui

- **WHEN** a warn frost prompt entry is presented from the global queue
- **THEN** the visible shell/body chrome SHALL come from `packages/cyber_alarm_ui`
- **AND** the App MUST NOT keep a parallel local copy of those warn frost widgets after migration

### Requirement: Boot self-check suppresses global prompt pump

While boot self-check is active, the App SHALL suppress presenting global prompt queue entries (including warn, guidance, and remote lock). After self-check completes or is skipped, the global queue MAY pump. The App MUST NOT introduce a guidance-only phase that suppresses warn presentation until network/cloud guidance has finished enrolling.

#### Scenario: Suppressed during self-check

- **WHEN** boot self-check overlay is active
- **AND** a warn, guidance, or remote-lock prompt is enqueued
- **THEN** no prompt dialog from that queue SHALL be shown until self-check finishes

#### Scenario: No guidance-phase barrier after self-check

- **WHEN** boot self-check has finished
- **AND** Wi‑Fi or cloud guidance has not yet enrolled
- **THEN** eligible warn prompts MAY present via the global queue immediately
- **AND** the App MUST NOT wait for guidance enrollment before pumping warn entries

### Requirement: Guidance and lock prompts enroll into the global queue

Wi‑Fi connection tip, device registration, device bind, and remote lock prompts SHALL enqueue onto the global prompt queue when eligible. They MUST NOT call an independent modal host that can stack over another prompt. Eligibility MAY depend on async network or cloud results without delaying other queue entries already enqueued.

#### Scenario: Cloud bind enqueues when probe returns

- **WHEN** the users binding probe reports unbound after network is ready
- **THEN** a bind prompt SHALL be enqueued on the global prompt queue
- **AND** SHALL display only when it reaches the head and no other prompt is showing

#### Scenario: Entry gate lock feedback uses the same id

- **WHEN** the operator attempts Quick/Engineer entry while remotely locked
- **THEN** lock feedback SHALL enqueue with id `remoteLock`
- **AND** MUST share dedupe with a cloud-driven lock prompt already pending or showing
