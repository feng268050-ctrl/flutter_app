## MODIFIED Requirements

### Requirement: Boot-self-check preference under hmi prefs

The App SHALL persist the “show startup self-check” boolean as a key inside `/var/lib/hmi/misc-settings.json` (unified Common Settings → Misc store), not as a standalone long-term preference file. Default when the JSON file is absent or the key is missing SHALL be **enabled** (`true`). If a legacy `/var/lib/hmi/boot-self-check` file exists and the JSON file does not yet contain the key, the App SHALL import that value into `misc-settings.json` on first read.

#### Scenario: Default enabled when file missing

- **WHEN** `/var/lib/hmi/misc-settings.json` is absent (and no legacy boot-self-check value applies)
- **THEN** boot self-check SHALL treat the preference as enabled

#### Scenario: Disabled value survives restart

- **WHEN** the operator disables Show Startup Self-Check
- **AND** the HMI process restarts
- **THEN** the preference SHALL remain disabled in `misc-settings.json`

### Requirement: Sound-effect index preference under hmi prefs

The image / App SHALL persist the UI click sound-effect index (integer `0..2`) under `/var/lib/hmi/` (exact filename chosen at implementation, e.g. `sound-effect` or a field inside an existing HMI prefs file). Cold start of the HMI App SHALL read this preference before registering the Cyber click backend so the first taps use the correct sample. Boot `settings-restore.service` is NOT required to apply sound-effect (App-owned; unlike backlight/volume shell helpers). Sound-effect MUST NOT be relocated into `misc-settings.json` solely because Misc prefs were unified (Sound Effect is Display & Sound, not Misc).

#### Scenario: Pref file survives relaunch

- **WHEN** the operator selects Effect 2 and the HMI process restarts
- **THEN** the sound-effect preference under `/var/lib/hmi/` still encodes index `1`

## ADDED Requirements

### Requirement: Misc settings JSON under hmi prefs

The App SHALL persist Common Settings → Misc operator preferences in `/var/lib/hmi/misc-settings.json`. At minimum the file SHALL be able to store Show Startup Self-Check and Show System Status Overlay. Additional Misc keys MAY be added to the same JSON object without creating new per-toggle files. `settings-restore.service` is NOT required to apply these Misc keys (App-owned warm-read).

#### Scenario: System status overlay key in misc JSON

- **WHEN** the operator enables Show System Status Overlay
- **AND** the HMI process restarts
- **THEN** `/var/lib/hmi/misc-settings.json` still encodes the overlay as enabled
