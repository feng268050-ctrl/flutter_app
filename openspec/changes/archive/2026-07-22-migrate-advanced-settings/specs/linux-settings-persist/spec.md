## ADDED Requirements

### Requirement: Advanced settings persist under dedicated var file

App-owned Advanced Settings preferences (AI assistance and dangerous-operation booleans, and optional cached numeric thresholds) SHALL persist in a dedicated JSON file under `/var/lib/hmi/` (e.g. `advanced-settings.json` via `OsPaths.varHmi`). They MUST NOT be stored in `misc-settings.json`. Missing or corrupt files MUST soft-fail to documented defaults without crashing the App.

#### Scenario: Soft-fail corrupt file

- **WHEN** `advanced-settings.json` is corrupt
- **THEN** the App applies defaults for AI (both ON) and dangerous ops (all OFF)
- **AND** the Settings UI remains usable

#### Scenario: Not Misc

- **WHEN** the operator changes Lens Contamination Detection
- **THEN** the value is written to the advanced-settings file
- **AND** MUST NOT appear as a key inside `misc-settings.json`
