## MODIFIED Requirements

### Requirement: Sound-effect asset preference under hmi prefs

The image / HAL SHALL persist the UI click **asset key** via `ButtonFeedback` at `/var/lib/hmi/sound.conf` (key `button_feedback`). Cold start of the HMI App SHALL warm-read this preference before registering the Cyber click backend so the first taps play the correct sample. Boot `settings-restore.service` is NOT required to apply sound-effect / ButtonFeedback (unlike backlight/volume shell helpers). Sound-effect MUST NOT be relocated into `misc-settings.json` solely because Misc prefs were unified (Sound Effect is Display & Sound, not Misc).

#### Scenario: Pref file survives relaunch

- **WHEN** the operator selects Effect 2 and the HMI process restarts
- **THEN** `/var/lib/hmi/sound.conf` (key `button_feedback`) still encodes Effect 2’s asset key

## ADDED Requirements

### Requirement: AutoSleep preference under hmi prefs

The image / HAL SHALL persist the AutoSleep / screen-off policy at `/var/lib/hmi/display.conf` (key `auto_sleep`). Cold start SHALL restore the last policy for the idle watchdog. Boot `settings-restore.service` is NOT required to apply AutoSleep. AutoSleep MUST NOT be stored inside `misc-settings.json`.

#### Scenario: AutoSleep pref survives relaunch

- **WHEN** the operator selects Screen-off Time 30 min and the HMI process restarts
- **THEN** `/var/lib/hmi/display.conf` (key `auto_sleep`) still encodes the 30-minute policy
