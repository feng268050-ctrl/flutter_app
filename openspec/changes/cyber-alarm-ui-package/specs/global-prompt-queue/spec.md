## MODIFIED Requirements

### Requirement: Warn presentation uses the global prompt queue

Warn/alarm frost dialogs SHALL be shown by enqueuing onto the App global prompt queue through the `WarnPresentation` port. Dialog chrome for those entries SHALL use `packages/cyber_alarm_ui` frost shell/body widgets. The App MUST NOT maintain a separate warn-only UI modal FIFO (`CyberUiWarnPresentation` internal queue or equivalent). The `cyber_alarm` coordinator MUST NOT maintain a second modal presentation drain queue for showing dialogs.

#### Scenario: Warn show goes through global queue

- **WHEN** the coordinator requests presentation for alarm code `H001`
- **THEN** the warn frost dialog SHALL be hosted as a global prompt queue entry
- **AND** MUST NOT open via a parallel private warn UI queue

#### Scenario: Legacy warn UI queue removed

- **WHEN** this capability is implemented
- **THEN** the product warn host MUST NOT contain a separate `Queue` of pending warn dialogs used as a second modal pump

#### Scenario: Warn frost chrome from cyber_alarm_ui

- **WHEN** a warn frost prompt entry is presented from the global queue
- **THEN** the visible shell/body chrome SHALL come from `packages/cyber_alarm_ui`
- **AND** the App MUST NOT keep a parallel local copy of those warn frost widgets after migration
