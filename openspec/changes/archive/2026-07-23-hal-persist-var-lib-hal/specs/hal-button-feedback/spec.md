## MODIFIED Requirements

### Requirement: ButtonFeedback preference stores asset key

`ButtonFeedback` SHALL persist the active asset key at `/var/lib/hal/sound.conf` (key `button_feedback`). Boot `settings-restore.service` is NOT required to apply ButtonFeedback.

#### Scenario: Preference survives relaunch

- **WHEN** the active asset key is set and the HMI process restarts
- **THEN** warm-read / get returns the same asset key from `/var/lib/hal/sound.conf` (key `button_feedback`)
