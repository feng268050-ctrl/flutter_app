# estop-comm-alarm-suppress Specification

## Purpose

While machine e-stop is active, suppress false laser / wire-feeder communication warn episodes (H022 / W001) on the App alarm path without masking status checks or changing HAL / `modbus.json`.

## Requirements

### Requirement: Suppress laser and wire-feeder comm alarms while e-stop is active

While machine emergency stop (`machine.emergency_stop`) is active, the product App warn/alarm path SHALL treat laser communication (`alarm.laser_comm` / code **H022**) and wire feeder communication (`alarm.wire_feeder_comm` / code **W001**) as inactive for episode purposes. The App MUST NOT arm a warn episode, MUST NOT present a modal warn dialog, and MUST NOT insert a historical alarm-log row for H022 or W001 solely because those Modbus bits are true during e-stop. Suppression MUST occur in the App alarm signal path (adapter or equivalent filter). The system MUST NOT change `packages/cyber_hal` Modbus decode behavior or `modbus.json` attribute definitions to implement this policy. Other alarm codes MUST continue to rise and clear normally during e-stop.

#### Scenario: E-stop blocks H022 rising

- **WHEN** `machine.emergency_stop` is true
- **AND** `alarm.laser_comm` becomes true
- **THEN** the warn coordinator MUST NOT receive an active rising edge for H022
- **AND** no H022 history row is inserted
- **AND** no H022 modal is shown

#### Scenario: E-stop blocks W001 rising

- **WHEN** `machine.emergency_stop` is true
- **AND** `alarm.wire_feeder_comm` becomes true
- **THEN** the warn coordinator MUST NOT receive an active rising edge for W001
- **AND** no W001 history row is inserted
- **AND** no W001 modal is shown

#### Scenario: Unrelated alarms still present during e-stop

- **WHEN** `machine.emergency_stop` is true
- **AND** an unrelated Modbus alarm code (e.g. H001) transitions inactive→active
- **THEN** that code SHALL arm and present per existing `cyber_alarm` policy

### Requirement: E-stop engagement clears armed H022 and W001 episodes

When `machine.emergency_stop` transitions from inactive to active, if H022 and/or W001 are currently fault-active in the warn stack, the App alarm path SHALL emit an inactive (falling) transition for each such code so the coordinator can tear down presentation per existing recover policy. The App MUST NOT insert a new rising history row as part of that clear.

#### Scenario: Open H022 dialog closes on e-stop

- **WHEN** H022 is fault-active with a modal showing (or queued)
- **AND** `machine.emergency_stop` becomes true
- **THEN** the warn path SHALL deliver a falling/inactive edge for H022
- **AND** the H022 episode SHALL tear down per coordinator policy
- **AND** no additional H022 rising history row is inserted due to e-stop

### Requirement: E-stop release restores live comm-bit edges

When `machine.emergency_stop` returns inactive, H022 and W001 SHALL again follow live Modbus bit edges. If a suppressed bit remains true at e-stop release, the App SHALL emit a rising edge for that code so a real post-e-stop disconnect is recorded and presented.

#### Scenario: Still-true laser comm rises after e-stop release

- **WHEN** `machine.emergency_stop` becomes false
- **AND** `alarm.laser_comm` is still true
- **THEN** the warn path SHALL emit a rising edge for H022
- **AND** a history row MAY be inserted and a modal MAY be shown per normal policy

#### Scenario: Cleared bit stays quiet after e-stop release

- **WHEN** `machine.emergency_stop` becomes false
- **AND** `alarm.laser_comm` and `alarm.wire_feeder_comm` are false
- **THEN** the warn path MUST NOT emit rising edges for H022 or W001

### Requirement: Status checks keep raw laser/wire-feeder comm bits under e-stop

E-stop suppression applies only to the warn/alarm signal path (episodes, modal presentation, historical log). Machine Status Device Health status lights, boot self-check, and other status consumers MUST continue to observe the raw Modbus values for `alarm.laser_comm` and `alarm.wire_feeder_comm` without e-stop masking.

#### Scenario: Comm lights still show raw fault during e-stop

- **WHEN** `machine.emergency_stop` is true
- **AND** raw `alarm.laser_comm` / `alarm.wire_feeder_comm` are true
- **AND** Machine Status Device Health is driven by the App warn Modbus adapter monitor feed
- **THEN** those two comm status lights SHALL reflect the raw true (fault) bits
- **AND** the warn path MUST still suppress H022/W001 popup and history as specified above
