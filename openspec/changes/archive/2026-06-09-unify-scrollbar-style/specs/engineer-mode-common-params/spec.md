## ADDED Requirements

### Requirement: Engineer parameter panels use the global scrollbar baseline

Engineer Mode parameter panels SHALL use the global vertical scrollbar style as their scrollbar baseline while preserving the current Engineer Mode behavior that hides the scrollbar until the user scrolls. The panel MUST use the unified white rounded thumb, `insideOverlay`, fading behavior, and no default visible track.

#### Scenario: Engineer parameter panel initially hides scrollbar

- **WHEN** the operator opens an Engineer Mode parameter tab such as cutting, wash, or welding
- **THEN** the parameter panel MUST NOT show a vertical scrollbar before the operator scrolls

#### Scenario: Engineer parameter panel reveals unified scrollbar on scroll

- **WHEN** the operator scrolls an Engineer Mode parameter panel vertically
- **THEN** the panel MUST show the same global vertical scrollbar thumb used by other scrollable pages
- **AND** the panel MUST continue using overlay/fade behavior without a separate visible track

#### Scenario: Engineer parameter layout is preserved

- **WHEN** the Engineer Mode parameter panels adopt the global scrollbar style or container
- **THEN** their existing parameter rows, click targets, validation entry points, and save/reset controls MUST remain unchanged
