## MODIFIED Requirements

### Requirement: Settings Misc controls boot self-check preference

Common Settings → Misc “Show Startup Self-Check” SHALL read and write the persisted boot-self-check preference from the unified Misc store `/var/lib/hmi/misc-settings.json` (default **enabled**). Changing the switch MUST NOT immediately run the self-check pipeline; it only affects future Home entries.

#### Scenario: Switch toggles persistence

- **WHEN** the operator turns “Show Startup Self-Check” off
- **THEN** `/var/lib/hmi/misc-settings.json` SHALL record the preference as disabled
- **AND** the next process start MUST NOT show the self-check dialog on Home
