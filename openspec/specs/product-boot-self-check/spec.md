# product-boot-self-check Specification

## Purpose
TBD - created by archiving change product-boot-self-check. Update Purpose after archive.
## Requirements
### Requirement: Boot self-check triggers once per process on first Home entry

When the operator first reaches product Home in a process, and the boot-self-check preference is enabled, the App SHALL start a boot self-check sequence exactly **once per process lifetime**. Subsequent Home entries in the same process MUST NOT re-run the self-check. The initial route MUST remain Home; self-check MUST be presented as an overlay after Home has painted (MUST NOT replace Home as `initialRoute`).

#### Scenario: First Home entry starts self-check when enabled

- **WHEN** product Home becomes visible for the first time in the process
- **AND** the boot-self-check preference is enabled
- **AND** self-check has not completed in this process
- **THEN** the coordinator SHALL begin the check pipeline
- **AND** a self-check progress dialog SHALL be shown as an overlay on Home

#### Scenario: Second Home entry skips self-check

- **WHEN** the operator leaves Home and returns within the same process
- **AND** boot self-check has already completed in this process
- **THEN** the self-check dialog MUST NOT be shown again

#### Scenario: Preference disabled skips self-check

- **WHEN** the boot-self-check preference is disabled
- **AND** the operator reaches Home
- **THEN** the self-check dialog MUST NOT be shown
- **AND** the coordinator SHALL treat the sequence as complete for gate/resume purposes

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
9. Camera comm status (ICMP ping with bounded timeout; MUST NOT use HTTP deviceinfo solely for connectivity)

Item labels SHOULD align with Monitor → Alarm Information wording where applicable.

#### Scenario: Controller unreachable fails dependent Modbus items

- **WHEN** lower-controller communication fails or is not ready
- **THEN** subsequent Modbus-dependent items SHALL be marked **fail**
- **AND** the camera comm status item SHALL still execute

#### Scenario: Modbus unavailable fails Modbus items

- **WHEN** Modbus self-check is not available (no link / host stub)
- **THEN** Modbus-backed items SHALL be marked **fail**
- **AND** the camera item SHALL still run (fail if unreachable / not applicable)

#### Scenario: Camera check uses ping only

- **WHEN** the camera comm status item runs
- **THEN** the App SHALL evaluate reachability using ICMP (or equivalent ping) with a bounded timeout
- **AND** MUST NOT call HTTP `GET /System/deviceinfo` solely for connectivity

### Requirement: Async overlapping detection is gated during boot self-check

While boot self-check is active, the App SHALL expose a process gate (`isActive`) so overlapping async warn/camera monitors MUST NOT present competing popups. When self-check finishes (dialog dismissed or preference disabled), the gate SHALL clear and deferred monitors MAY start.

#### Scenario: Gate active during pipeline

- **WHEN** boot self-check dialog is showing or the pipeline is running
- **THEN** `BootSelfCheckGate.isActive` (or equivalent) SHALL be true

#### Scenario: Gate clears after dismiss

- **WHEN** boot self-check completes
- **THEN** the gate SHALL be inactive
- **AND** subsequent product warn/camera monitors MAY run per their own rules

### Requirement: Settings Misc controls boot self-check preference

Common Settings → Misc “Show Startup Self-Check” SHALL read and write the persisted boot-self-check preference (default **enabled**). Changing the switch MUST NOT immediately run the self-check pipeline; it only affects future Home entries.

#### Scenario: Switch toggles persistence

- **WHEN** the operator turns “Show Startup Self-Check” off
- **THEN** the preference file SHALL record disabled
- **AND** the next process start MUST NOT show the self-check dialog on Home

