# multi-app-build-select Specification

## Purpose
Host Make/scripts select which Flutter app under app/ to build, push, and include in rootfs; `*_hmi` installs to /opt/hmi; optional os_settings auto-include on build-rootfs.

## Requirements
### Requirement: Make APP selects Flutter project under app/

The build system SHALL accept Make/env variable `APP` for `make build-app`, `make push-app`, and `make build-rootfs`. When unset or empty, `APP` SHALL default to `lws_hmi`. `APP` MUST name a directory under repo `app/` that contains `pubspec.yaml`. Invalid or missing apps MUST fail with a clear error before Flutter assemble.

#### Scenario: Default APP is lws_hmi

- **WHEN** the operator runs `make build-app` without setting `APP`
- **THEN** the build MUST use `app/lws_hmi` and install the release bundle under overlay `…/rootfs-overlay/opt/hmi`

#### Scenario: Explicit APP builds only that project

- **WHEN** the operator runs `APP=os_settings make build-app` and `app/os_settings/pubspec.yaml` exists
- **THEN** the build MUST assemble only that project into overlay `…/rootfs-overlay/opt/os_settings`
- **AND** MUST NOT wipe or rebuild overlay `opt/hmi`

#### Scenario: Unknown APP fails fast

- **WHEN** the operator runs `APP=does_not_exist make build-app`
- **THEN** the command MUST exit non-zero before Flutter assemble
- **AND** MUST report that `app/does_not_exist` is missing or invalid

### Requirement: HMI apps use _hmi suffix and install to /opt/hmi

Flutter HMI product apps SHALL be named with suffix `_hmi` (e.g. `lws_hmi`, `cnc_hmi`). Any such `APP` SHALL install to device/overlay path `/opt/hmi` so `hmi.service` can launch the bundle. A single rootfs SHALL contain at most one HMI payload at `/opt/hmi` (the selected `*_hmi` app) plus an optional non-HMI `os_settings` at `/opt/os_settings`. Non-HMI apps SHALL install to `/opt/<APP>`. Product companions (MediaMTX, AI daemon) SHALL install for HMI apps (`*_hmi`). Ship-asset prepare SHALL run when the selected app’s `assets/process-library` or `assets/firmware/control-board` sources exist.

#### Scenario: Alternate HMI product still uses /opt/hmi

- **WHEN** the operator runs `APP=cnc_hmi make build-app` and `app/cnc_hmi/pubspec.yaml` exists
- **THEN** the build MUST install the release bundle under overlay `…/rootfs-overlay/opt/hmi`
- **AND** MUST NOT install under `opt/cnc_hmi`

#### Scenario: Non-HMI app omits product companions

- **WHEN** `APP=os_settings make build-app` completes successfully
- **THEN** overlay `/opt/os_settings` MUST contain `lib/libapp.so` and `data/flutter_assets`
- **AND** MUST NOT be required to contain `bin/mediamtx` or `bin/lws_ai_daemon`

### Requirement: push-app deploys only the selected APP

`make push-app` SHALL stream the selected app’s overlay install tree over SSH and install to `/opt/hmi` for `*_hmi` (then restart `hmi.service`), or to `/opt/<APP>` for any other `APP` without restarting `hmi.service`. This is unsigned debug hot-swap (`host-push-hmi`), not a Make alias of `make upgrade-app`.

#### Scenario: Default push remains HMI hot-swap

- **WHEN** the operator runs `make push-app` after a default `make build-app`
- **THEN** the board `/opt/hmi` tree MUST be updated and `hmi.service` MUST be restarted

#### Scenario: settings push does not restart HMI

- **WHEN** the operator runs `APP=os_settings make push-app` after a matching build-app
- **THEN** `/opt/os_settings` on the board MUST receive `libapp.so` and flutter_assets
- **AND** the push MUST NOT restart `hmi.service` as the primary apply path

### Requirement: build-rootfs ensures APP and optional settings

Before packing rootfs, `make build-rootfs` SHALL ensure the selected `APP` release tree exists under the fs-overlay (`lib/libapp.so`). When the selected APP is an HMI (`*_hmi`), that tree MUST be `/opt/hmi`. When `app/os_settings` exists with `pubspec.yaml`, `make build-rootfs` SHALL also ensure overlay `/opt/os_settings` is present (building it if missing) without requiring the operator to set `APP=os_settings`. Explicit `APP=os_settings` for `build-app` / `push-app` remains required to build or push only that app interactively.

#### Scenario: Rootfs auto-includes settings when source exists

- **WHEN** `app/os_settings/pubspec.yaml` exists and the operator runs `make build-rootfs` with default `APP`
- **THEN** the resulting rootfs staging MUST contain both `/opt/hmi/lib/libapp.so` and `/opt/os_settings/lib/libapp.so` (building settings into overlay first if it was missing)

#### Scenario: Interactive settings still needs APP for build-app

- **WHEN** the operator wants only to rebuild settings without baking rootfs
- **THEN** they MUST run `APP=os_settings make build-app` (default `make build-app` MUST NOT build settings)

### Requirement: APP selects cloud publish R2 artifact prefix

In addition to selecting the Flutter project for `build-app` / `push-app` / `build-rootfs`, Make/env **`APP`** SHALL select the cloud OTA publish identity for **`make publish`** / **`make publish-only`**: the R2 static-upload artifact prefix SHALL be the `APP` directory name with underscores replaced by hyphens (default `lws_hmi` → `lws-hmi`). Invalid or missing `app/<APP>/` MUST fail before upload. Non-HMI apps MUST NOT be published via the whole-device OTA publish targets unless an explicitly documented escape hatch is used.

#### Scenario: Default APP publishes under lws-hmi

- **WHEN** the operator runs `make publish` without setting `APP`
- **THEN** the publish client targets artifact prefix `lws-hmi`

#### Scenario: Explicit HMI APP changes publish prefix

- **WHEN** the operator runs `APP=cnc_hmi make publish` and `app/cnc_hmi/pubspec.yaml` exists
- **THEN** the publish client targets artifact prefix `cnc-hmi` and uses **that HMI app’s** `pubspec.yaml` version as the cloud OTA version (not `lws_hmi`’s)
