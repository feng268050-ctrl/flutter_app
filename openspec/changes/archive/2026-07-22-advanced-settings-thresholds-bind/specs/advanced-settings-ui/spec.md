## MODIFIED Requirements

### Requirement: Advanced Settings tab presents lws-ui section layout with CyberUI controls

The Advanced Settings tab SHALL present a scrollable layout whose section order matches lws-ui: Offset & Correction, Power Thresholds, Temperature Thresholds, AI Assistance, Dangerous Operations. Threshold rows SHALL be live Cyber scaled sliders bound to the threshold controller (Modbus + cache), not placeholder-only shells. AI / Dangerous toggles remain CyberUI switches. Zero Offset Auto MAY remain a local reset until the full Auto procedure lands.

#### Scenario: Thresholds are interactive and bound

- **WHEN** the user opens Advanced Settings
- **THEN** power and temperature threshold sliders are interactive
- **AND** releasing a slider attempts a Modbus attribute write for the mapped id
