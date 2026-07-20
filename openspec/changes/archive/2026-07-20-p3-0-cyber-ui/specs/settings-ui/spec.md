## ADDED Requirements

### Requirement: Settings may adopt CyberUI incrementally

Settings shell tabs MAY remain Material. When Settings introduces frosted cards or Cyber dialogs, it SHALL use `packages/cyber_ui` APIs and MUST NOT add a parallel Settings-local glass toolkit.

#### Scenario: Settings stays usable without full glass migration

- **WHEN** CyberUI v1 lands and Settings tabs are not yet fully glass-migrated
- **THEN** Settings remains navigable with Material tab content and existing HAL-backed controls

#### Scenario: New Settings glass uses CyberUI

- **WHEN** a Settings surface adds frosted card or Cyber dialog chrome after this change
- **THEN** that chrome is implemented via CyberUI widgets
