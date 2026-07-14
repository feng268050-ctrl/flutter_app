## ADDED Requirements

### Requirement: Display orientation API exposes portrait and landscape

The HMI SHALL provide a reusable display-orientation API with exactly two product modes: **portrait** and **landscape**. The API SHALL get the current preferred mode and set a new preferred mode. Default when unset SHALL be **landscape** (ynh960 production default).

#### Scenario: Default is landscape

- **WHEN** no persisted orientation preference exists
- **THEN** get returns landscape

### Requirement: Linux maps modes to flutter-pi launch orientation

On Linux, **landscape** SHALL map to flutter-pi `-o landscape_left` and **portrait** SHALL map to flutter-pi `-o portrait_up`. The preferred mode SHALL be persisted on disk so `hmi-launch.sh` (or equivalent) applies the matching `-o` on the next HMI start.

#### Scenario: Preference survives restart

- **WHEN** the client sets portrait and the HMI process is restarted via the normal launch path
- **THEN** flutter-pi starts with `-o portrait_up` and the UI is in portrait

#### Scenario: Landscape restores production default

- **WHEN** the client sets landscape and the HMI process is restarted
- **THEN** flutter-pi starts with `-o landscape_left`

### Requirement: Applying orientation may restart HMI

Setting orientation on Linux MAY restart the HMI process to apply flutter-pi `-o`. The operation SHALL NOT brick boot: if preference write fails, the previous orientation remains in effect.

#### Scenario: Failed persist keeps previous orientation

- **WHEN** preference write fails
- **THEN** a subsequent HMI launch still uses the last successfully persisted mode (or landscape default)
