## ADDED Requirements

### Requirement: External brightness changes are observable

The Linux backlight implementation SHALL detect changes to the active sysfs `brightness` node made **outside** the controller (e.g. shell write) via **inotify** (or equivalent fd watch) and expose them to callers (Stream or get that reflects the new percent after the event). Periodic Process polling of brightness MUST NOT be the primary observation path.

#### Scenario: External sysfs write updates observers

- **WHEN** an operator writes a new value to the panel backlight sysfs brightness node while the HMI is running
- **THEN** a subscribed UI/controller observer can read the updated percent without the operator moving the Demo slider
