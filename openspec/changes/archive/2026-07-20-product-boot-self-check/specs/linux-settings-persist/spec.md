## ADDED Requirements

### Requirement: Boot-self-check preference under hmi prefs

The App SHALL persist the “show startup self-check” boolean under `/var/lib/hmi/` (e.g. `/var/lib/hmi/boot-self-check`) using the same userdata-backed prefs layout as other HMI operator preferences. Default when absent SHALL be **enabled** (`true`).

#### Scenario: Default enabled when file missing

- **WHEN** the preference file is absent
- **THEN** boot self-check SHALL treat the preference as enabled

#### Scenario: Disabled value survives restart

- **WHEN** the operator disables Show Startup Self-Check
- **AND** the HMI process restarts
- **THEN** the preference SHALL remain disabled
