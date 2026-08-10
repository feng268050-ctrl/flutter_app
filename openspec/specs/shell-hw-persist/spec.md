# shell-hw-persist Specification

## Purpose

Verb-noun board helpers that apply simple hardware settings and persist the canonical `/var/lib/hmi/` preference files consumed by boot restore and HMI launch.
## Requirements
### Requirement: Simple hardware knobs persist via verb-noun shell helpers

The image SHALL provide board helpers under `/usr/libexec/hmi/` that both apply and persist the following preferences under `/var/lib/hal/` (where those helpers are still shipped). Backlight apply/persist on current images is HAL-owned; the preference file schema remains:

| Helper / writer | Preference file |
|-----------------|-----------------|
| HAL backlight (or legacy `change-backlight.sh` if present) | `display.conf` (`backlight`) (logical 0–100; apply MUST NOT write sysfs absolute 0) |
| `change-volume.sh` | `sound.conf` (`volume`) (0–100) |
| `change-orientation.sh` | `display.conf` (`orientation` = `portrait` / `landscape`) |
| `apply-mouse-settings.sh` | `mouse.conf` |
| `set-performance-mode.sh` / `set-power-mode` (board) | `power.conf` (`mode` = `performance` / `balanced`) |

Each shipped helper MUST write the preference file under `/var/lib/hal/` as part of a successful apply. For backlight, successful HAL writes MAY persist logical `0`, and apply/restore of that value MUST keep the panel above absolute hardware zero. AutoSleep blanking MAY write absolute sysfs `0` transiently without updating this preference file. For power mode, invoking the helper **with an explicit mode argument** MUST persist `mode=`; boot restore with **no** argument MUST apply the persisted mode without forcing a rewrite to `performance`.

#### Scenario: Logical zero preference does not black out panel

- **WHEN** `/var/lib/hal/display.conf` (key `backlight`) contains `0` and HAL applies persisted preference
- **THEN** sysfs brightness is the hardware floor (≥ 1), not absolute 0

#### Scenario: Orientation helper writes launch preference

- **WHEN** `change-orientation portrait` succeeds
- **THEN** `/var/lib/hal/display.conf` contains `orientation=portrait` so the next `hmi-launch.sh` start uses the portrait eLinux HMI mapping

#### Scenario: Mouse helper writes mouse.conf

- **WHEN** `apply-mouse-settings` is invoked with a valid settings payload or flags representing natural scroll on
- **THEN** `/var/lib/hal/mouse.conf` is updated accordingly for the eLinux HMI to apply on HMI start

#### Scenario: Power mode helper writes power.conf

- **WHEN** `set-power-mode balanced` (or `set-performance-mode balanced`) succeeds
- **THEN** `/var/lib/hal/power.conf` contains `mode=balanced`

