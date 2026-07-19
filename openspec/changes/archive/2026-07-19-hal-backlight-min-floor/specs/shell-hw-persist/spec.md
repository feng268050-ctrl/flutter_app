## MODIFIED Requirements

### Requirement: Simple hardware knobs persist via verb-noun shell helpers

The image SHALL provide board helpers under `/usr/libexec/hmi/` that both apply and persist the following preferences under `/var/lib/hmi/` (where those helpers are still shipped). Backlight apply/persist on current images is HAL-owned; the preference file schema remains:

| Helper / writer | Preference file |
|-----------------|-----------------|
| HAL backlight (or legacy `change-backlight.sh` if present) | `backlight-brightness` (logical 0–100; apply MUST NOT write sysfs absolute 0) |
| `change-volume.sh` | `media-volume` (0–100) |
| `change-orientation.sh` | `display-orientation` (`portrait` / `landscape`) |
| `apply-mouse-settings.sh` | `mouse.conf` |

Each shipped helper MUST write the preference file as part of a successful apply. For backlight, successful HAL writes MAY persist logical `0`, and apply/restore of that value MUST keep the panel above absolute hardware zero.

#### Scenario: Logical zero preference does not black out panel

- **WHEN** `/var/lib/hmi/backlight-brightness` contains `0` and HAL applies persisted preference
- **THEN** sysfs brightness is the hardware floor (≥ 1), not absolute 0

#### Scenario: Orientation helper writes launch preference

- **WHEN** `change-orientation portrait` succeeds
- **THEN** `/var/lib/hmi/display-orientation` contains `portrait` so the next `hmi-launch.sh` start uses the portrait flutter-pi mapping

#### Scenario: Mouse helper writes mouse.conf

- **WHEN** `apply-mouse-settings` is invoked with a valid settings payload or flags representing natural scroll on
- **THEN** `/var/lib/hmi/mouse.conf` is updated accordingly for flutter-pi to apply on HMI start
