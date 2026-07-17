## MODIFIED Requirements

### Requirement: Linux orientation maps to flutter-pi flags via shell helper

Setting display orientation SHALL go through `change-orientation` in `/usr/libexec/hmi/`, persisting **`/var/lib/hmi/display-orientation`** for `hmi-launch.sh`.

#### Scenario: Portrait persisted for next launch

- **WHEN** user selects portrait in Demo on Linux
- **THEN** `/var/lib/hmi/display-orientation` contains `portrait`
