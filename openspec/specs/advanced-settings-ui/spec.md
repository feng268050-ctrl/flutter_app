# advanced-settings-ui Specification

## Purpose

Advanced Settings tab layout and CyberUI controls (sections, switches, scaled threshold chrome) with lws-ui section parity.
## Requirements
### Requirement: Advanced Settings tab presents lws-ui section layout with CyberUI controls

The Advanced Settings tab SHALL present a scrollable layout whose section order matches lws-ui: Offset & Correction, Power Thresholds, Temperature Thresholds, AI Assistance, Dangerous Operations. Threshold rows SHALL be live Cyber scaled sliders bound to the threshold controller (Modbus + cache), not placeholder-only shells. AI / Dangerous toggles SHALL use CyberUI switch components (e.g. `CyberSwitch` via Settings switch row patterns). The App MUST NOT use Android `FrostSwitchView` or other non-Cyber switch widgets for these toggles. Zero Offset Auto MAY remain a local reset until the full Auto procedure lands.

#### Scenario: Operator opens Advanced Settings

- **WHEN** the user selects the Advanced Settings tab
- **THEN** the five section groups are visible in the order above
- **AND** AI Assistance and Dangerous Operations switches are CyberUI switches

#### Scenario: Thresholds are interactive and bound

- **WHEN** the user opens Advanced Settings
- **THEN** power and temperature threshold sliders are interactive
- **AND** releasing a slider attempts a Modbus attribute write for the mapped id

#### Scenario: No Frost Java switches

- **WHEN** Advanced Settings toggle rows are rendered
- **THEN** they are built from CyberUI switch APIs rather than a ported Frost Java switch
