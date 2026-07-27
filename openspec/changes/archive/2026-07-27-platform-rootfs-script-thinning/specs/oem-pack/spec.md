## ADDED Requirements

### Requirement: Board helpers live under OEM

OEM board packs SHALL place board-specific bringup scripts under `boards/<board_id>/helpers/` (device path `/oem/boards/<board_id>/helpers/`). OEM `board_profile.json` `helpers` entries for modem bringup and USB OTG mode SHALL use absolute paths under `/oem/boards/<board_id>/helpers/`. Portable stack helpers (wpa/network/bluetooth stack-up, A/B, oem-compose, hmi-launch) SHALL remain on rootfs.

#### Scenario: ynh960 profile points at OEM helpers

- **WHEN** inspecting `oem/boards/ynh960/board_profile.json` after W2
- **THEN** `helpers.wifi_modem`, `helpers.bt_modem`, and `helpers.usb_otg_mode` SHALL reference paths under `/oem/boards/ynh960/helpers/`

#### Scenario: Wi-Fi stack resolves modem from profile

- **WHEN** `wifi-stack-up` runs and `/run/hmi/board_profile.json` (or compose oem.env) provides a modem helper path
- **THEN** it SHALL invoke that path instead of hardcoding only `/usr/libexec/bluetooth/wifibt-bringup.sh`

### Requirement: Screen pack LCD seed files

Screen packs that require Innohi ParamUpdate / private1 LCD tables SHALL ship those files under `screens/<screen_id>/lcd/` and reference them from `screen.json`. Early display-init SHALL seed private1 **only** from the active OEM screen `lcd/` directory (resolved via `/oem/manifest.json` without requiring `/run/hmi`). Missing OEM lcd files SHALL fail visibly; the init MUST NOT seed from `/system/etc` as a fallback.

#### Scenario: OEM lcd seeds private1

- **WHEN** `/oem/manifest.json` is valid and the resolved screen `lcd/` directory contains the required LCD param files
- **THEN** display-init SHALL copy those OEM files into private1

#### Scenario: Missing OEM lcd fails hard

- **WHEN** OEM is missing `manifest.json` or screen `lcd/` lacks required param files
- **THEN** display-init SHALL exit non-zero without copying `/system/etc` LCD tables into private1

### Requirement: HMI launch consumes screen.env defaults

`hmi-launch` SHALL use operator-persisted orientation from `display.conf` when set. When orientation is unset, it SHALL apply `SCREEN_DEFAULT_ORIENTATION` from `/run/hmi/screen.env` (written by oem-compose from `screen.json`). If neither source provides a value, `hmi-launch` SHALL exit non-zero (no hardcoded orientation fallback).

#### Scenario: screen.env used when display.conf empty

- **WHEN** `display.conf` has no orientation key and `/run/hmi/screen.env` sets `SCREEN_DEFAULT_ORIENTATION=landscape_left`
- **THEN** `hmi-launch` SHALL start the HMI with that orientation

#### Scenario: Operator preference wins

- **WHEN** `display.conf` sets `orientation=portrait` and `screen.env` sets a different default
- **THEN** `hmi-launch` SHALL use the operator `portrait` (or mapped) orientation

#### Scenario: Missing orientation fails

- **WHEN** `display.conf` has no orientation and `screen.env` is missing or has an empty `SCREEN_DEFAULT_ORIENTATION`
- **THEN** `hmi-launch` SHALL exit non-zero

## MODIFIED Requirements

### Requirement: Screen pack screen.json

Each screen pack SHALL provide `screen.json` with at least logical `width` / `height` and `default_orientation`. When LCD param tables are required for the panel, `lcd_param_files` SHALL list paths relative to the screen pack (under `lcd/`), not repository `board/*.txt` paths alone. Compose SHALL continue to expose orientation (and related) values in `/run/hmi/screen.env`.

#### Scenario: ynh960 panel screen.json

- **WHEN** compose succeeds for the ynh960 panel pack
- **THEN** `/run/hmi/screen.env` SHALL expose orientation (and related) values derived from that `screen.json`

#### Scenario: lcd_param_files under screen pack

- **WHEN** inspecting `oem/screens/panel-ynh960-800x1280/screen.json`
- **THEN** `lcd_param_files` entries SHALL refer to files under that screen pack's `lcd/` directory

### Requirement: oem-compose early boot

Rootfs SHALL include `/usr/libexec/hmi/oem-compose.sh` and an `oem-compose.service` ordered before HMI. Compose SHALL ensure `PARTLABEL=oem` is mounted at `/oem`, validate manifest, and write at least `/run/hmi/oem.env` and `/run/hmi/board_profile.json` (and screen env) with `OEM_SOURCE=partition`. On missing or invalid OEM content it SHALL fail visibly in the journal and MUST NOT load a rootfs-bundled fallback pack or silently swap boards. Rootfs MUST NOT ship `/usr/share/hmi/oem-fallback`.

#### Scenario: Valid OEM exports run files

- **WHEN** a valid oem partition is mounted and `oem-compose` runs
- **THEN** `/run/hmi/oem.env` and `/run/hmi/board_profile.json` exist before `hmi.service` starts and `OEM_SOURCE=partition`

#### Scenario: Corrupt OEM does not swap boards

- **WHEN** `/oem/manifest.json` exists but `board_path` is missing
- **THEN** compose SHALL exit non-zero without writing another board's profile as success

#### Scenario: Missing OEM fails hard

- **WHEN** `/oem/manifest.json` is absent after mount attempt
- **THEN** compose SHALL exit non-zero and MUST NOT compose from any rootfs fallback tree
