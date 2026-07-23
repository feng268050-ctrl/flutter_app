## MODIFIED Requirements

### Requirement: Advanced Settings is grouped by parameter concern

Advanced Settings SHALL display device parameters in titled groups: Offset & Correction, Power Thresholds, Temperature Thresholds, AI Assistance, and Dangerous Operations.

#### Scenario: Advanced Settings groups rows

- **WHEN** the user opens Advanced Settings
- **THEN** Offset & Correction contains Zero Offset and Scan Width Correction
- **AND** Power Thresholds contains Laser Starting Power, Laser Termination Power, and Minimum Gas Pressure Threshold
- **AND** Temperature Thresholds contains Motor Temperature Alarm Threshold, Driver Temperature Alarm Threshold, Protective Lens Temperature Alarm Threshold, Collimating Lens Temperature Alarm Threshold, and Temperature Alarm Recovery Interval
- **AND** AI Assistance contains Lens Contamination Detection and Zero Point Offset Detection toggle switches
- **AND** Dangerous Operations contains Keep Laser On while Alarmed first, then Allow Work after Camera Alarm, Allow Work after Gas Alarm, Allow Work after Lens Contamination, and Allow Work after Feeder Alarm toggle switches
- **AND** each Dangerous Operations switch displays a localized hint line below its title
