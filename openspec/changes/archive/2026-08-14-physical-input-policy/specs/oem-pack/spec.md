## MODIFIED Requirements

### Requirement: OEM manifest schema

On-device `/oem/manifest.json` SHALL include at least: `schema_version`, `pack_id`, `board_id`, `screen_id`, `board_path`, `screen_path`. Optional `compat` MAY include `os_min` and `soc_family`. Packs MAY additionally ship `input_defaults.json` at `/oem/packs/<pack_id>/input_defaults.json` (resolved relative to OEM root via `pack_id` in manifest).

#### Scenario: Compose reads pack identity

- **WHEN** `oem-compose` starts and `/oem/manifest.json` is valid
- **THEN** it SHALL resolve `board_path` and `screen_path` relative to `/oem` and refuse to proceed if either path is missing

## ADDED Requirements

### Requirement: Input defaults seed on compose

When `/var/lib/hal/input.conf` is absent, `oem-compose` SHALL create it from the active pack's `input_defaults.json` when present, writing `physical_keyboard_enabled` and `physical_mouse_enabled` as `0` or `1`. When the pack file is absent, compose SHALL NOT create `input.conf`.

#### Scenario: Pack defaults seeded once

- **WHEN** compose runs on first boot for pack `ynh960_panel-800x1280` with `input_defaults.json` present and no runtime conf
- **THEN** `/var/lib/hal/input.conf` SHALL exist with keys from the pack file
