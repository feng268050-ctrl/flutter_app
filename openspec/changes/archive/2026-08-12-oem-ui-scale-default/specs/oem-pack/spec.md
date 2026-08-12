## MODIFIED Requirements

### Requirement: Screen pack screen.json

Each screen pack SHALL provide `screen.json` with at least logical `width` / `height` and `default_orientation`. When LCD param tables are required for the panel, `lcd_param_files` SHALL list paths relative to the screen pack (under `lcd/`), not repository `board/*.txt` paths alone. Compose SHALL continue to expose orientation (and related) values in `/run/hmi/screen.env`. Screen packs MAY declare optional `default_ui_scale` (positive number, typically `0.5`–`2.0`) as the factory default UI scale multiplier for that panel; when omitted, runtime behavior SHALL treat the OEM default as absent (Apps fall back to `1.0` until seeded or operator-set).

#### Scenario: ynh960 panel screen.json

- **WHEN** compose succeeds for the ynh960 panel pack
- **THEN** `/run/hmi/screen.env` SHALL expose orientation (and related) values derived from that `screen.json`

#### Scenario: lcd_param_files under screen pack

- **WHEN** inspecting `oem/screens/panel-ynh960-800x1280/screen.json`
- **THEN** `lcd_param_files` entries SHALL refer to files under that screen pack's `lcd/` directory

#### Scenario: ynh960 default_ui_scale exported

- **WHEN** the ynh960 panel `screen.json` includes `"default_ui_scale": 1.13`
- **AND** `oem-compose` succeeds
- **THEN** `/run/hmi/screen.env` SHALL include `SCREEN_DEFAULT_UI_SCALE=1.13`

#### Scenario: virt default_ui_scale exported

- **WHEN** the virt `screen.json` includes `"default_ui_scale": 1.28`
- **AND** `oem-compose` succeeds for `sim_virt`
- **THEN** `/run/hmi/screen.env` SHALL include `SCREEN_DEFAULT_UI_SCALE=1.28`

### Requirement: HMI launch consumes screen.env defaults

`hmi-launch` SHALL use operator-persisted orientation from `display.conf` when set. When orientation is unset, it SHALL apply `SCREEN_DEFAULT_ORIENTATION` from `/run/hmi/screen.env` (written by oem-compose from `screen.json`). If neither source provides a value, `hmi-launch` SHALL exit non-zero (no hardcoded orientation fallback). Before starting the embedder, when `/var/lib/hal/display.conf` has no `ui_scale` key, `hmi-launch` SHALL seed `ui_scale` from `SCREEN_DEFAULT_UI_SCALE` in `/run/hmi/screen.env` when that variable is set and numerically valid (clamped to the same range as HAL `LinuxUiScale`). When `ui_scale` is already present in `display.conf`, `hmi-launch` MUST NOT overwrite it.

#### Scenario: screen.env used when display.conf empty

- **WHEN** `display.conf` has no orientation key and `/run/hmi/screen.env` sets `SCREEN_DEFAULT_ORIENTATION=landscape_left`
- **THEN** `hmi-launch` SHALL start the HMI with that orientation

#### Scenario: Operator preference wins

- **WHEN** `display.conf` sets `orientation=portrait` and `screen.env` sets a different default
- **THEN** `hmi-launch` SHALL use the operator `portrait` (or mapped) orientation

#### Scenario: Missing orientation fails

- **WHEN** `display.conf` has no orientation and `screen.env` is missing or has an empty `SCREEN_DEFAULT_ORIENTATION`
- **THEN** `hmi-launch` SHALL exit non-zero

#### Scenario: ynh960 OEM ui_scale seeded on first boot

- **WHEN** `display.conf` exists or is created without a `ui_scale` key
- **AND** the active pack is ynh960 panel and `/run/hmi/screen.env` sets `SCREEN_DEFAULT_UI_SCALE=1.13`
- **THEN** `hmi-launch` SHALL upsert `ui_scale=1.13` into `/var/lib/hal/display.conf` before starting the embedder

#### Scenario: virt OEM ui_scale seeded on first boot

- **WHEN** `display.conf` exists or is created without a `ui_scale` key
- **AND** the active pack is `sim_virt` and `/run/hmi/screen.env` sets `SCREEN_DEFAULT_UI_SCALE=1.28`
- **THEN** `hmi-launch` SHALL upsert `ui_scale=1.28` into `/var/lib/hal/display.conf` before starting the embedder

#### Scenario: Operator ui_scale wins over OEM

- **WHEN** `display.conf` already contains `ui_scale=1.05`
- **AND** `screen.env` sets `SCREEN_DEFAULT_UI_SCALE=1.28` (or any other OEM default)
- **THEN** `hmi-launch` SHALL leave `ui_scale=1.05` unchanged

## ADDED Requirements

### Requirement: ynh960 panel default UI scale

The ynh960 800×1280 screen pack (`oem/screens/panel-ynh960-800x1280/screen.json`) SHALL declare `default_ui_scale` of approximately `1.13` so factory-flashed devices obtain panel-appropriate UI scale without manual OS Settings configuration.

#### Scenario: ynh960 pack declares default_ui_scale

- **WHEN** inspecting `oem/screens/panel-ynh960-800x1280/screen.json`
- **THEN** `default_ui_scale` SHALL be present and approximately `1.13`

### Requirement: virt screen default UI scale

The virt emulator screen pack (`oem/screens/virt/screen.json`) SHALL declare `default_ui_scale` of `1.28` for the QEMU virtio display.

#### Scenario: virt pack declares default_ui_scale

- **WHEN** inspecting `oem/screens/virt/screen.json`
- **THEN** `default_ui_scale` SHALL be present and `1.28`
