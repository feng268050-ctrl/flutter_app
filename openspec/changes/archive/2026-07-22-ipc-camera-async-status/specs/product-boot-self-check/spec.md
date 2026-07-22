## MODIFIED Requirements

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
