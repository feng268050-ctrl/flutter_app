## ADDED Requirements

### Requirement: Prefer Cyber controls when available

As CyberUI gains switch, checkbox, slider, segmented, stepper, and dialog-host widgets, Settings screens that currently use Material stand-ins for the same role SHALL migrate to the Cyber counterparts in the adoption phase (Phase G), unless a documented exception applies (e.g. platform picker that has no Cyber equivalent yet).

#### Scenario: Volume and sound-effect already on Cyber path

- **WHEN** the operator opens Volume or Sound Effect
- **THEN** those surfaces continue to use Cyber volume / effect selection chrome introduced earlier

#### Scenario: Binary settings rows use CyberSwitch when migrated

- **WHEN** Phase G has migrated a Settings toggle row
- **THEN** that row uses `CyberSwitch` (or package equivalent) rather than raw Material `Switch` alone
