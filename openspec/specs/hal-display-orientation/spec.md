# hal-display-orientation Specification

## Purpose
TBD - created by archiving change hal-persist-var-lib-hal. Update Purpose after archive.
## Requirements
### Requirement: Portable Orientation API under output display

The HAL SHALL expose a portable `Orientation` API under `hal/output/display` that gets and sets the preferred panel orientation with exactly two product modes: **portrait** and **landscape**. Default when unset SHALL be **landscape**. Callers MUST obtain the type from `package:cyber_hal/output/display` (or `…/orientation.dart`) and MUST NOT depend on App-local `DisplayOrientationController` as the long-term contract. Temporary in-App media layout rotation (not panel orientation) MAY remain product UI without this API.

#### Scenario: Default is landscape

- **WHEN** no persisted orientation preference exists
- **THEN** get returns landscape

#### Scenario: Set is readable

- **WHEN** the client sets orientation to portrait
- **THEN** a subsequent get returns portrait (after persist succeeds)

### Requirement: Linux Orientation applies via launch

On Linux, setting orientation SHALL go through `change-orientation` / `change-orientation.sh` (or an equivalent injectable helper), which persists `/var/lib/hal/display.conf` key `orientation`. Apply SHALL restart `hmi.service` (or equivalent) so `hmi-launch.sh` maps the preference for Weston:

- `landscape` → `transform=rotate-270`
- `portrait` → `transform=normal` (ynh960 panel mapping)

The Linux HAL backend MUST NOT write preference files as the sole writer when the shell helper is the persistence contract. Warm-read MAY read `display.conf` directly. Legacy standalone `display-orientation` SHALL be one-shot imported when `orientation` is missing.

#### Scenario: Preference survives restart on Weston

- **WHEN** the client sets portrait via HAL and `hmi.service` restarts
- **THEN** Weston output transform is `normal` (portrait) per `hmi-launch.sh` mapping

#### Scenario: Landscape restores production default

- **WHEN** the client sets landscape and the HMI process is restarted
- **THEN** Weston uses `transform=rotate-270`

### Requirement: Failed Orientation persist keeps previous mode

Setting orientation SHALL NOT brick boot: if preference write fails, the previous orientation remains in effect on the next launch.

#### Scenario: Failed persist keeps previous orientation

- **WHEN** preference write fails
- **THEN** a subsequent HMI launch still uses the last successfully persisted mode (or landscape default)

