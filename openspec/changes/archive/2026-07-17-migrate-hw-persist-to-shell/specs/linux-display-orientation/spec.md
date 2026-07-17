## MODIFIED Requirements

### Requirement: Linux maps modes to flutter-pi launch orientation

On Linux, **landscape** SHALL map to flutter-pi `-o landscape_left` and **portrait** SHALL map to flutter-pi `-o portrait_up`. Setting the preferred mode SHALL go through `change-orientation` / `change-orientation.sh`, which MUST persist `/var/lib/hmi/display-orientation` so `hmi-launch.sh` applies the matching `-o` on the next HMI start. The Linux Flutter orientation backend MUST NOT write that preference file directly.

#### Scenario: Preference survives restart

- **WHEN** the client sets portrait (via Demo or `change-orientation`) and the HMI process is restarted via the normal launch path
- **THEN** flutter-pi starts with `-o portrait_up` and the UI is in portrait

#### Scenario: Landscape restores production default

- **WHEN** the client sets landscape and the HMI process is restarted
- **THEN** flutter-pi starts with `-o landscape_left`

#### Scenario: Shell writes same file as launch reads

- **WHEN** `change-orientation portrait` succeeds
- **THEN** `/var/lib/hmi/display-orientation` contains `portrait`
