## ADDED Requirements

### Requirement: cyber_ota remains non-UI; Apps compose cyber_upgrade_ui for presentation

`packages/cyber_ota` SHALL remain a Flutter-free whole-device OTA apply engine (manifest, transfer, verify, extract, inactive-slot apply, progress Stream). Product Apps SHALL map `cyber_ota` progress events into `cyber_upgrade_ui` phases/progress for operator UI. `cyber_ota` MUST NOT depend on `cyber_upgrade_ui` or Flutter widgets. This requirement does not change Ed25519 verify, ingress kinds, or A/B apply behavior.

#### Scenario: Engine package has no Flutter UI dependency

- **WHEN** a developer inspects `packages/cyber_ota` dependencies
- **THEN** the package does not require Flutter or `cyber_upgrade_ui` to build and run its orchestration APIs

#### Scenario: App maps OtaPhase to cyber_upgrade_ui phases

- **WHEN** a whole-device session emits transferring/verifying/extracting/writing/arming progress
- **THEN** the App MAY present those events through `cyber_upgrade_ui` multi-phase progress without modifying `cyber_ota` phase semantics
