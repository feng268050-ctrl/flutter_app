## ADDED Requirements

### Requirement: Misc Show Startup Self-Check is persisted

Common Settings → Misc SHALL expose an interactive “Show Startup Self-Check” switch backed by the product boot-self-check preference store. The control MUST NOT remain a disabled stub with “Not persisted yet”.

#### Scenario: Switch is interactive

- **WHEN** the operator opens Common Settings → Misc
- **THEN** “Show Startup Self-Check” reflects the current persisted value
- **AND** toggling it updates the preference for subsequent process starts
