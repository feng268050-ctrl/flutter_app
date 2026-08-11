## ADDED Requirements

### Requirement: hmi.service conflicts with settings.service

`hmi.service` SHALL declare `Conflicts=settings.service` (and Settings SHALL conflict with HMI per `settings-app-lifecycle`) so only one Flutter seat runs. Boot enablement of `hmi.service` in `multi-user.target.wants` remains required; Settings MUST NOT be added to multi-user wants by this conflict wiring.

#### Scenario: Conflict metadata present

- **WHEN** inspecting shipped `hmi.service` after this change
- **THEN** the unit lists `Conflicts=settings.service` (or equivalent bidirectional conflict with Settings)
- **AND** `hmi.service` remains in `multi-user.target.wants`
