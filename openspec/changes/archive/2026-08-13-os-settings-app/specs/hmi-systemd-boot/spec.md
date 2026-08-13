## ADDED Requirements

### Requirement: hmi.service conflicts with os-settings.service

`hmi.service` SHALL declare `Conflicts=os-settings.service` (and OS Settings SHALL conflict with HMI per `os-settings-app-lifecycle`) so only one Flutter seat runs. Boot enablement of `hmi.service` in `multi-user.target.wants` remains required; OS Settings MUST NOT be added to multi-user wants by this conflict wiring.

#### Scenario: Conflict metadata present

- **WHEN** inspecting shipped `hmi.service` after this change
- **THEN** the unit lists `Conflicts=os-settings.service` (or equivalent bidirectional conflict with OS Settings)
- **AND** `hmi.service` remains in `multi-user.target.wants`
