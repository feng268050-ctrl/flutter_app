# product-boot-self-check Specification

## Purpose
Startup self-check overlay on product Home: Modbus alarm-information checks plus camera ICMP, gated once per system boot via `/run/hmi/` marker, controlled by Misc preference.

## Requirements
### Requirement: Boot self-check triggers once per process on first Home entry

When the operator first reaches product Home after a **system boot** (power-on or reboot), and the boot-self-check preference is enabled, and self-check has not yet been consumed for that boot, the App SHALL start a boot self-check sequence. Within the same system boot, subsequent HMI process starts (including `hmi.service` restart, crash recovery, or app hot-push) MUST NOT re-run the self-check. Within a single process, subsequent Home entries MUST NOT re-run the self-check. The initial route MUST remain Home; self-check MUST be presented as an overlay after Home has painted (MUST NOT replace Home as `initialRoute`).

Boot consumption SHALL be recorded in a runtime marker under `/run/hmi/` (tmpfs) so it clears automatically on reboot. The App MUST NOT use a durable `/var/lib/hmi/` preference file as the sole once-per-boot gate.

#### Scenario: First Home entry after boot starts self-check when enabled

- **WHEN** the system has just booted (no boot self-check marker under `/run/hmi/` yet)
- **AND** product Home becomes visible for the first time in the HMI process
- **AND** the boot-self-check preference is enabled
- **THEN** the coordinator SHALL begin the check pipeline
- **AND** a self-check progress dialog SHALL be shown as an overlay on Home

#### Scenario: Second Home entry in the same process skips self-check

- **WHEN** the operator leaves Home and returns within the same process
- **AND** boot self-check has already completed in this process
- **THEN** the self-check dialog MUST NOT be shown again

#### Scenario: HMI restart within the same boot skips self-check

- **WHEN** boot self-check has already completed (or been marked consumed) earlier in this system boot
- **AND** the HMI process exits and starts again without a system reboot
- **AND** the operator reaches Home
- **THEN** the self-check dialog MUST NOT be shown

#### Scenario: Preference disabled skips self-check

- **WHEN** the boot-self-check preference is disabled
- **AND** the operator reaches Home
- **THEN** the self-check dialog MUST NOT be shown
- **AND** the coordinator SHALL treat the sequence as complete for gate/resume purposes
- **AND** the boot SHALL be marked consumed so a later HMI restart in the same boot still skips self-check

#### Scenario: Next system boot can show self-check again

- **WHEN** the system reboots or power-cycles
- **AND** the boot-self-check preference is enabled
- **AND** product Home becomes visible for the first time after that boot
- **THEN** the self-check dialog SHALL be shown (unless the preference is disabled)

### Requirement: Self-check dialog appends items and status incrementally

During boot self-check, the App SHALL display a CyberUI-hosted progress dialog titled for startup self-check. For every item, the dialog SHALL **append that item’s row with status checking and paint it before evaluating the next item**, then update that row to **pass** or **fail**. Undetectable / unavailable results MUST use **fail** (not skipped). After all items reach a terminal status, the dialog SHALL show a footer with a “don’t show again” control and Close, auto-dismiss after **3 seconds** unless the operator interacts, and MUST NOT dismiss on scrim tap. The dialog barrier MUST NOT use an opaque full-screen scrim under the frosted panel (realtime backdrop blur samples Home).

#### Scenario: Item transitions from checking to pass

- **WHEN** a check item begins execution
- **THEN** the dialog SHALL append a row with status **checking** and allow it to paint before the next item starts
- **WHEN** the item evaluation concludes healthy
- **THEN** that row SHALL update to status **pass**

#### Scenario: Dialog auto-closes after all items complete

- **WHEN** every scheduled check item has reached a terminal status
- **THEN** the self-check dialog SHALL dismiss automatically after approximately 3 seconds without requiring Close
- **AND** operator touch or Close SHALL cancel or supersede auto-dismiss

#### Scenario: Don’t show again persists preference

- **WHEN** the operator enables “don’t show again” and dismisses the dialog
- **THEN** the App SHALL persist boot-self-check preference as disabled for future process starts

### Requirement: Self-check covers Modbus alarm-information checks and camera connectivity

The boot self-check pipeline SHALL evaluate, in order:

1. Lower-controller communication (valid device type / controller ready)
2. Pump comm status (`alarm.laser_comm` semantics)
3. Gun head comm status (`alarm.gun_comm`)
4. Motor driver board temperature (alarm + temp value present)
5. Gun motor temperature (alarm + temp value present)
6. Protective mirror temperature (alarm + temp value present)
7. Collimator temperature (alarm + temp value present)
8. Wire feeder comm status (`alarm.wire_feeder_comm`)

The pipeline MUST NOT include a Camera Comm / ICMP camera item. Camera reachability is owned by HAL `ip_camera` health observation and the product IP-camera session / Home status icon, not by boot self-check.

Item labels SHOULD align with Monitor → Alarm Information wording where applicable for the Modbus-backed items above.

#### Scenario: Controller unreachable fails dependent Modbus items

- **WHEN** lower-controller communication fails or is not ready
- **THEN** subsequent Modbus-dependent items SHALL be marked **fail**
- **AND** the pipeline SHALL NOT schedule a camera connectivity item

#### Scenario: Modbus unavailable fails Modbus items

- **WHEN** Modbus self-check is not available (no link / host stub)
- **THEN** Modbus-backed items SHALL be marked **fail**
- **AND** the pipeline SHALL still complete without a camera item

#### Scenario: Camera is not part of boot self-check

- **WHEN** boot self-check runs on a production board
- **THEN** the dialog MUST NOT list Camera Comm as a checklist row
- **AND** camera ICMP MUST NOT be required for self-check completion

### Requirement: Async overlapping detection is gated during boot self-check

While boot self-check is active, the App SHALL expose a process gate (`isActive`) so overlapping async **warn popups** MUST NOT present competing dialogs. The product IP-camera session `start()` and Home camera status icon MAY run during self-check because they do not present a blocking popup. When self-check finishes (dialog dismissed or preference disabled), the gate SHALL clear and deferred warn monitors MAY start.

#### Scenario: Gate active during pipeline

- **WHEN** boot self-check dialog is showing or the pipeline is running
- **THEN** `BootSelfCheckGate.isActive` (or equivalent) SHALL be true

#### Scenario: Gate clears after dismiss

- **WHEN** boot self-check completes
- **THEN** the gate SHALL be inactive
- **AND** subsequent product warn monitors MAY run per their own rules

#### Scenario: Camera status icon may run during self-check

- **WHEN** boot self-check is active
- **AND** the product IP-camera session is running
- **THEN** the Home camera status icon MAY update
- **AND** the session MUST NOT show a competing modal that blocks the self-check dialog

### Requirement: Settings Misc controls boot self-check preference

Common Settings → Misc “Show Startup Self-Check” SHALL read and write the persisted boot-self-check preference from the unified Misc store `/var/lib/hmi/misc-settings.json` (default **enabled**). Changing the switch MUST NOT immediately run the self-check pipeline; it only affects future Home entries.

#### Scenario: Switch toggles persistence

- **WHEN** the operator turns “Show Startup Self-Check” off
- **THEN** `/var/lib/hmi/misc-settings.json` SHALL record the preference as disabled
- **AND** the next process start MUST NOT show the self-check dialog on Home

### Requirement: Boot self-check suppresses warn presentation

While the boot self-check overlay is active, the product App MUST gate `cyber_alarm` so it does not present new modal warn dialogs for Modbus-backed alarm onsets. Self-check item evaluation MAY continue to use the same Alarm Information semantics for pass/fail tiles. After self-check completes (success or operator-dismissed failure path per existing rules), normal warn presentation SHALL resume for subsequent onsets.

#### Scenario: Alarm during self-check does not popup

- **WHEN** boot self-check is active
- **AND** a Modbus `alarm.*` attribute becomes true
- **THEN** the App MUST NOT show a modal warn dialog for that onset during the active self-check session

#### Scenario: After self-check resumes warns

- **WHEN** boot self-check has finished
- **AND** a later rising edge occurs for a catalogued alarm code
- **THEN** warn presentation MAY show a modal dialog for that onset

### Requirement: Boot self-check dialog copy uses App localization

Boot self-check dialog title, item labels, status words (checking / pass / fail), footer controls (“don’t show again”, Close), and related operator-visible strings SHALL use `AppLocalizations` for the active UI locale. EN/ZH values SHALL prefer lws-ui `boot_self_check_*` strings when present.

#### Scenario: Self-check dialog follows locale

- **WHEN** Language is `zh-CN` and boot self-check presents its dialog
- **THEN** the dialog title and migrated item/status/footer strings render in Simplified Chinese
