## ADDED Requirements

### Requirement: Boot self-check does not replace Home as initial route

The App’s initial route MUST remain product Home (`/`). Boot self-check, when shown, MUST be an overlay (or equivalent modal) after Home entry — it MUST NOT become the named `initialRoute` and MUST NOT remove Home/Settings/Monitor/Demo from the route table.

#### Scenario: Cold start still opens Home

- **WHEN** the HMI process starts with boot self-check enabled
- **THEN** `initialRoute` SHALL be Home
- **AND** boot self-check, if presented, SHALL appear after Home is entered
