## MODIFIED Requirements

### Requirement: AutoSleep preference under hmi prefs

Setting AutoSleep policy from the HMI SHALL persist the selected policy at `/var/lib/hal/display.conf` (key `auto_sleep`). Cold start SHALL restore the last policy. Preference MUST NOT be stored inside `misc-settings.json`.

#### Scenario: Preference survives relaunch

- **WHEN** the operator selects 10 minutes and the HMI process restarts
- **THEN** AutoSleep still reports the 10-minute policy
