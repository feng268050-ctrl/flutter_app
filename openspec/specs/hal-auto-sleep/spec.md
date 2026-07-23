# hal-auto-sleep Specification

## Purpose
TBD - created by archiving change refactor-cyber-hal-output. Update Purpose after archive.
## Requirements
### Requirement: AutoSleep portable API under output display

The HAL SHALL expose a portable `AutoSleep` API under `hal/output/display` that gets and sets an idle screen-off policy. Supported policies SHALL include at least: 10 minutes, 30 minutes, 60 minutes, and Never. Callers MUST NOT depend on Android `Settings.System` screen-off integers.

#### Scenario: Set Never persists and disables blanking

- **WHEN** the client sets AutoSleep policy to Never
- **THEN** a subsequent get returns Never and the idle blanking path MUST NOT blank the panel solely due to elapsed idle time

#### Scenario: Set 30 minutes is readable

- **WHEN** the client sets AutoSleep policy to 30 minutes
- **THEN** a subsequent get returns the 30-minute policy

### Requirement: AutoSleep preference under hmi prefs

Setting AutoSleep policy from the HMI SHALL persist the selected policy at `/var/lib/hal/display.conf` (key `auto_sleep`). Cold start SHALL restore the last policy. Preference MUST NOT be stored inside `misc-settings.json`.

#### Scenario: Preference survives relaunch

- **WHEN** the operator selects 10 minutes and the HMI process restarts
- **THEN** AutoSleep still reports the 10-minute policy

### Requirement: Linux AutoSleep blanks with absolute zero and wakes on double-tap

On Linux, when idle exceeds the policy duration, AutoSleep SHALL blank the panel by writing **absolute sysfs brightness value `0`** (physical off), not logical percent 0 / hardware floor. It SHALL remember the prior logical brightness for restore and MUST NOT persist absolute 0 into the backlight preference file. While blanked, a **double-tap** (two pointer-downs within a short window) SHALL restore the prior logical brightness; a single tap or pointer move MUST NOT wake. While awake, activity SHALL only reset the idle timer.

#### Scenario: Idle blanks to absolute zero

- **WHEN** AutoSleep policy is 10 minutes and no user activity occurs for at least 10 minutes
- **THEN** sysfs `brightness` is `0` and the persisted backlight preference file is unchanged

#### Scenario: Double-tap wakes

- **WHEN** the panel is blanked by AutoSleep and the operator double-taps
- **THEN** brightness is restored to the prior logical percent

#### Scenario: Single tap does not wake

- **WHEN** the panel is blanked by AutoSleep and the operator performs a single tap
- **THEN** the panel remains at absolute brightness 0

