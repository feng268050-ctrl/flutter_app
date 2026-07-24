## ADDED Requirements

### Requirement: Module map lists OTG mode picker

The CyberUI package README module map (or equivalent public export surface documentation) SHALL list the OTG mode-picker dialog entry alongside dialog-host / control suite entries so other products can discover and import it without reading HMI sources.

#### Scenario: README lists OTG picker

- **WHEN** an integrator opens the CyberUI README module map after this change
- **THEN** an OTG mode-picker (or equivalently named) entry is listed
