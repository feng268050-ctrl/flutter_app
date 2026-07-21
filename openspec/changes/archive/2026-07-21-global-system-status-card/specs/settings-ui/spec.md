## ADDED Requirements

### Requirement: Misc preferences use unified misc-settings.json

Common Settings → Misc operator preferences SHALL be persisted in a single JSON file at `/var/lib/hmi/misc-settings.json` (or `${OsPaths.varHmi}/misc-settings.json`). The App SHALL NOT introduce additional per-toggle preference files under `/var/lib/hmi/` for new Misc switches. Keys for at least Show Startup Self-Check and Show System Status Overlay SHALL live in this file. Missing file or missing keys SHALL apply documented per-key defaults. Corrupt JSON MUST NOT crash the App (soft-fail to defaults).

#### Scenario: Fresh board uses JSON defaults

- **WHEN** `/var/lib/hmi/misc-settings.json` is absent
- **THEN** Misc preferences use their documented defaults (Show Startup Self-Check enabled; Show System Status Overlay disabled)

#### Scenario: Toggle writes the unified file

- **WHEN** the operator changes a Misc switch (Show Startup Self-Check or Show System Status Overlay)
- **THEN** `/var/lib/hmi/misc-settings.json` is updated to reflect the new value
- **AND** other Misc keys already present in the file remain intact

### Requirement: Misc Show System Status Overlay is persisted

Common Settings → Misc SHALL expose an interactive “Show System Status Overlay” switch backed by the unified Misc JSON store. The control MUST NOT remain a disabled stub with “Not persisted yet”. The preference SHALL default to **off** (overlay hidden). Toggling the switch SHALL update overlay visibility for the current session and for subsequent process starts.

#### Scenario: Switch is interactive and defaults off

- **WHEN** the operator opens Common Settings → Misc on a fresh Misc preference store
- **THEN** “Show System Status Overlay” is present and reflects the disabled (off) state

#### Scenario: Toggle updates preference

- **WHEN** the operator turns “Show System Status Overlay” on or off
- **THEN** the preference is updated in `/var/lib/hmi/misc-settings.json` immediately
- **AND** the global system status card appears or disappears accordingly without requiring an app restart

## MODIFIED Requirements

### Requirement: Misc Show Startup Self-Check is persisted

Common Settings → Misc SHALL expose an interactive “Show Startup Self-Check” switch backed by the unified Misc JSON store at `/var/lib/hmi/misc-settings.json` (not a dedicated `boot-self-check` file as the ongoing source of truth). The control MUST NOT remain a disabled stub with “Not persisted yet”.

#### Scenario: Switch is interactive

- **WHEN** the operator opens Common Settings → Misc
- **THEN** “Show Startup Self-Check” reflects the current value from `misc-settings.json` (or its default / legacy-imported value)
- **AND** toggling it updates the preference in `misc-settings.json` for subsequent process starts
