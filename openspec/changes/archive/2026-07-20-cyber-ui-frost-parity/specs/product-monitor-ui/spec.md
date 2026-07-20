## ADDED Requirements

### Requirement: Monitor may adopt Cyber borders and controls

Monitor chrome that needs frosted panels or interactive Cyber controls SHALL prefer `packages/cyber_ui` components when available. Status indicators already using Cyber MUST remain on the package API.

#### Scenario: Status stays on CyberStatusIndicator

- **WHEN** Monitor renders machine/alarm status lights
- **THEN** they continue to use `CyberStatusIndicator` (or successor) from cyber_ui
