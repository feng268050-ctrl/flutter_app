# multi-app-build-select Specification

## Purpose
Host Make/scripts select which Flutter app under app/ to build, push, and include in rootfs; `*_hmi` installs to /opt/hmi; optional factory_test auto-include on build-rootfs.

## Requirements
### Requirement: Make APP selects Flutter project under app/

The build system SHALL accept Make/env variable `APP` for `make build-app`, `make push-app`, and `make build-rootfs`. When unset or empty, `APP` SHALL default to `lws_hmi`. `APP` MUST name a directory under repo `app/` that contains `pubspec.yaml`. Invalid or missing apps MUST fail with a clear error before Flutter assemble.

#### Scenario: Default APP is lws_hmi

- **WHEN** the operator runs `make build-app` without setting `APP`
- **THEN** the build MUST use `app/lws_hmi` and install the release bundle under overlay `…/rootfs-overlay/opt/hmi`

#### Scenario: Explicit APP builds only that project

- **WHEN** the operator runs `APP=factory_test make build-app` and `app/factory_test/pubspec.yaml` exists
- **THEN** the build MUST assemble only that project into overlay `…/rootfs-overlay/opt/factory_test`
- **AND** MUST NOT wipe or rebuild overlay `opt/hmi`

#### Scenario: Unknown APP fails fast

- **WHEN** the operator runs `APP=does_not_exist make build-app`
- **THEN** the command MUST exit non-zero before Flutter assemble
- **AND** MUST report that `app/does_not_exist` is missing or invalid

### Requirement: HMI apps use _hmi suffix and install to /opt/hmi

Flutter HMI product apps SHALL be named with suffix `_hmi` (e.g. `lws_hmi`, `cnc_hmi`). Any such `APP` SHALL install to device/overlay path `/opt/hmi` so `hmi.service` can launch the bundle. A single rootfs SHALL contain at most one HMI payload at `/opt/hmi` (the selected `*_hmi` app) plus an optional non-HMI `factory_test` at `/opt/factory_test`. Non-HMI apps SHALL install to `/opt/<APP>`. Product companions (MediaMTX, AI daemon) SHALL install for HMI apps (`*_hmi`). Ship-asset prepare SHALL run when the selected app’s `assets/process-library` or `assets/firmware/control-board` sources exist.

#### Scenario: Alternate HMI product still uses /opt/hmi

- **WHEN** the operator runs `APP=cnc_hmi make build-app` and `app/cnc_hmi/pubspec.yaml` exists
- **THEN** the build MUST install the release bundle under overlay `…/rootfs-overlay/opt/hmi`
- **AND** MUST NOT install under `opt/cnc_hmi`

#### Scenario: Non-HMI app omits product companions

- **WHEN** `APP=factory_test make build-app` completes successfully
- **THEN** overlay `/opt/factory_test` MUST contain `lib/libapp.so` and `data/flutter_assets`
- **AND** MUST NOT be required to contain `bin/mediamtx` or `bin/lws_ai_daemon`

### Requirement: push-app deploys only the selected APP

`make push-app` SHALL be a Make alias of **`make upgrade-app`**: signed `tar.gz` + host HTTP + device `download <url>`, Ed25519 verify, install to `/opt/hmi` (or `/opt/<APP>` for non-HMI), and restart `hmi.service` only for `*_hmi` apps. The former unsigned SCP / `push-app-staging` / `push-app-apply-and-restart.sh` path MUST NOT be used. For any other `APP`, upgrade MUST copy the release layout to `/opt/<APP>` and MUST NOT restart `hmi.service`.

#### Scenario: Default push remains HMI hot-swap

- **WHEN** the operator runs `make push-app` after a default `make build-app`
- **THEN** the board `/opt/hmi` tree MUST be updated and `hmi.service` MUST be restarted via the signed upgrade-app path

#### Scenario: factory_test push does not restart HMI

- **WHEN** the operator runs `APP=factory_test make push-app` after a matching build-app
- **THEN** `/opt/factory_test` on the board MUST receive `libapp.so` and flutter_assets
- **AND** the push MUST NOT restart `hmi.service` as the primary apply path

### Requirement: build-rootfs ensures APP and optional factory_test

Before packing rootfs, `make build-rootfs` SHALL ensure the selected `APP` release tree exists under the fs-overlay (`lib/libapp.so`). When the selected APP is an HMI (`*_hmi`), that tree MUST be `/opt/hmi`. When `app/factory_test` exists with `pubspec.yaml`, `make build-rootfs` SHALL also ensure overlay `/opt/factory_test` is present (building it if missing) without requiring the operator to set `APP=factory_test`. Explicit `APP=factory_test` for `build-app` / `push-app` remains required to build or push only that app interactively.

#### Scenario: Rootfs auto-includes factory_test when source exists

- **WHEN** `app/factory_test/pubspec.yaml` exists and the operator runs `make build-rootfs` with default `APP`
- **THEN** the resulting rootfs staging MUST contain both `/opt/hmi/lib/libapp.so` and `/opt/factory_test/lib/libapp.so` (building factory_test into overlay first if it was missing)

#### Scenario: Interactive factory_test still needs APP for build-app

- **WHEN** the operator wants only to rebuild factory_test without baking rootfs
- **THEN** they MUST run `APP=factory_test make build-app` (default `make build-app` MUST NOT build factory_test)

### Requirement: APP selects cloud publish R2 artifact prefix

In addition to selecting the Flutter project for `build-app` / `push-app` / `build-rootfs`, Make/env **`APP`** SHALL select the cloud OTA publish identity for **`make publish`** / **`make publish-only`**: the R2 static-upload artifact prefix SHALL be the `APP` directory name with underscores replaced by hyphens (default `lws_hmi` → `lws-hmi`). Invalid or missing `app/<APP>/` MUST fail before upload. Non-HMI apps MUST NOT be published via the whole-device OTA publish targets unless an explicitly documented escape hatch is used.

#### Scenario: Default APP publishes under lws-hmi

- **WHEN** the operator runs `make publish` without setting `APP`
- **THEN** the publish client targets artifact prefix `lws-hmi`

#### Scenario: Explicit HMI APP changes publish prefix

- **WHEN** the operator runs `APP=cnc_hmi make publish` and `app/cnc_hmi/pubspec.yaml` exists
- **THEN** the publish client targets artifact prefix `cnc-hmi` and uses **that HMI app’s** `pubspec.yaml` version as the cloud OTA version (not `lws_hmi`’s)
