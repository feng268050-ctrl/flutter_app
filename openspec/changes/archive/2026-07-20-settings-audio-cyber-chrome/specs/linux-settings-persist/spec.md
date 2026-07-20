## ADDED Requirements

### Requirement: Sound-effect index preference under hmi prefs

The image / App SHALL persist the UI click sound-effect index (integer `0..2`) under `/var/lib/hmi/` (exact filename chosen at implementation, e.g. `sound-effect` or a field inside an existing HMI prefs file). Cold start of the HMI App SHALL read this preference before registering the Cyber click backend so the first taps use the correct sample. Boot `settings-restore.service` is NOT required to apply sound-effect (App-owned; unlike backlight/volume shell helpers).

#### Scenario: Pref file survives relaunch

- **WHEN** the operator selects Effect 2 and the HMI process restarts
- **THEN** the sound-effect preference under `/var/lib/hmi/` still encodes index `1`
