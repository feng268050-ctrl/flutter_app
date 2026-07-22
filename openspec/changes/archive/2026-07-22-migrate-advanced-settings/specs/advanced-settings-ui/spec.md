## ADDED Requirements

### Requirement: Advanced Settings tab presents lws-ui section layout with CyberUI controls

The Advanced Settings tab SHALL replace the placeholder with a scrollable layout whose section order matches lws-ui Advanced Settings: Offset & Correction, Power Thresholds, Temperature Thresholds, AI Assistance, Dangerous Operations. Toggle controls in AI Assistance and Dangerous Operations SHALL use CyberUI switch components (e.g. `CyberSwitch` via Settings switch row patterns). The App MUST NOT use Android `FrostSwitchView` or other non-Cyber switch widgets for these toggles.

#### Scenario: Operator opens Advanced Settings

- **WHEN** the user selects the Advanced Settings tab
- **THEN** the five section groups are visible in the order above
- **AND** AI Assistance and Dangerous Operations switches are CyberUI switches

#### Scenario: No Frost Java switches

- **WHEN** Advanced Settings toggle rows are rendered
- **THEN** they are built from CyberUI switch APIs rather than a ported Frost Java switch
