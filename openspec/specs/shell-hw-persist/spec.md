# shell-hw-persist Specification

## Purpose

Verb-noun board helpers that apply simple hardware settings and persist the canonical `/var/lib/lws-hmi/` preference files consumed by boot restore and HMI launch.

## Requirements

### Requirement: Simple hardware knobs persist via verb-noun shell helpers

The image SHALL provide board helpers under `/usr/lib/lws-hmi/` that both apply and persist the following preferences under `/var/lib/lws-hmi/`:

| Helper | Preference file |
|--------|-----------------|
| `change-backlight.sh` | `backlight-brightness` (0–100) |
| `change-volume.sh` | `media-volume` (0–100) |
| `change-orientation.sh` | `display-orientation` (`portrait` / `landscape`) |
| `apply-mouse-settings.sh` | `mouse.conf` |

Each helper MUST write the preference file as part of a successful apply. Operator-facing commands SHALL be linked into `/usr/bin` without a `.sh` suffix (`change-backlight`, `change-volume`, `change-orientation`, `apply-mouse-settings`). Flutter Linux backends for these knobs MUST invoke the helpers for set operations and MUST NOT be the sole writers of those preference files.

#### Scenario: SSH change-backlight survives reboot

- **WHEN** an operator runs `change-backlight 75` successfully and the board reboots
- **THEN** `/var/lib/lws-hmi/backlight-brightness` contains `75` and boot restore / HMI re-apply restores approximately 75% brightness

#### Scenario: Demo volume uses the same helper as SSH

- **WHEN** the Demo sets media volume to 40 via the media audio controller
- **THEN** `change-volume` (or `/usr/lib/lws-hmi/change-volume.sh`) runs and `/var/lib/lws-hmi/media-volume` contains `40`

#### Scenario: Orientation helper writes launch preference

- **WHEN** `change-orientation portrait` succeeds
- **THEN** `/var/lib/lws-hmi/display-orientation` contains `portrait` so the next `hmi-launch.sh` start uses the portrait flutter-pi mapping

#### Scenario: Mouse helper writes mouse.conf

- **WHEN** `apply-mouse-settings` is invoked with a valid settings payload or flags representing natural scroll on
- **THEN** `/var/lib/lws-hmi/mouse.conf` is updated accordingly for flutter-pi to apply on HMI start
