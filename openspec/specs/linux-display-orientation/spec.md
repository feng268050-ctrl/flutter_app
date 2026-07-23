# linux-display-orientation Specification

## Purpose

Reusable display-orientation API (portrait / landscape) persisted for flutter-pi `-o` mapping on HMI restart.
## Requirements
### Requirement: Display orientation API exposes portrait and landscape

The system SHALL provide a reusable panel-orientation API with exactly two product modes: **portrait** and **landscape**, owned by `cyber_hal` (`Orientation` under `hal/output/display`). The API SHALL get the current preferred mode and set a new preferred mode. Default when unset SHALL be **landscape** (ynh960 production default). Product Apps MUST depend on the HAL API rather than embedding board helper paths for orientation.

#### Scenario: Default is landscape

- **WHEN** no persisted orientation preference exists
- **THEN** get returns landscape

### Requirement: Linux maps modes to flutter-pi launch orientation

On Linux, **landscape** and **portrait** SHALL be persisted as `/var/lib/hal/display.conf` key `orientation` via `change-orientation` / `change-orientation.sh`. `hmi-launch.sh` SHALL map those tokens for the active stack:

- flutter-pi: `landscape` → `-o landscape_left`, `portrait` → `-o portrait_up`
- Weston: `landscape` → `transform=rotate-270`, `portrait` → `transform=normal`

The Linux Flutter/HAL orientation backend MUST NOT write the preference file as the sole primary writer when the shell helper is present. HAL MUST NOT use a standalone `display-orientation` file as the primary write path. When `orientation` is missing but a legacy `display-orientation` file exists (under `/var/lib/hal/` or `/var/lib/hmi/`), launch / `change-orientation` / HAL warm-read SHALL one-shot import that token into `display.conf`.

#### Scenario: Preference survives restart

- **WHEN** the client sets portrait (via HAL or `change-orientation`) and the HMI process is restarted via the normal launch path on flutter-pi
- **THEN** flutter-pi starts with `-o portrait_up` and the UI is in portrait

#### Scenario: Landscape restores production default

- **WHEN** the client sets landscape and the HMI process is restarted on flutter-pi
- **THEN** flutter-pi starts with `-o landscape_left`

#### Scenario: Shell writes same file as launch reads

- **WHEN** `change-orientation portrait` succeeds
- **THEN** `/var/lib/hal/display.conf` contains `orientation=portrait`

#### Scenario: Legacy display-orientation migrates once

- **WHEN** `display.conf` lacks `orientation` and `/var/lib/hmi/display-orientation` (or `/var/lib/hal/display-orientation`) contains `portrait`
- **THEN** the next launch or `change-orientation` creates/updates `/var/lib/hal/display.conf` with `orientation=portrait`

#### Scenario: Weston uses same preference

- **WHEN** `orientation=portrait` is persisted and `hmi.service` starts on a Weston image
- **THEN** Weston is launched with output `transform=normal`

### Requirement: Applying orientation may restart HMI

Setting orientation on Linux MAY restart the HMI process to apply flutter-pi `-o` or Weston `transform`. The operation SHALL NOT brick boot: if preference write fails, the previous orientation remains in effect.

#### Scenario: Failed persist keeps previous orientation

- **WHEN** preference write fails
- **THEN** a subsequent HMI launch still uses the last successfully persisted mode (or landscape default)

