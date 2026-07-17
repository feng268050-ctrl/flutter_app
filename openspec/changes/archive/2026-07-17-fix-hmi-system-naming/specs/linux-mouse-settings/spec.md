## MODIFIED Requirements

### Requirement: MouseSettingsController uses shell persistence on Linux

On Linux, set operations MUST go through `apply-mouse-settings` in `/usr/libexec/hmi/`, persisting under **`/var/lib/hmi/mouse.conf`**.

#### Scenario: Natural scroll persisted via helper

- **WHEN** user toggles natural scroll on in Demo
- **THEN** `/var/lib/hmi/mouse.conf` is updated
