# per-app-rootfs-artifacts Specification

## Purpose
Host firmware layout resolves product-specific rootfs.img (and factory packages that embed it) by Make/env APP, while boot FITs stay shared.

## Requirements
### Requirement: Host publishes rootfs.img under output/firmware/APP

After `make build-rootfs`, the host SHALL publish the device rootfs artifact at `output/firmware/<APP>/rootfs.img` where `APP` is the Make/env variable (default `lws_hmi`). Shared boot artifacts SHALL remain at `output/firmware/boot.img` and `output/firmware/boot_b.img`. The on-device / stream basename SHALL remain `rootfs.img`.

#### Scenario: Default APP rootfs path

- **WHEN** the operator runs `make build-rootfs` without setting `APP`
- **THEN** `output/firmware/lws_hmi/rootfs.img` MUST exist and be the artifact used for subsequent default `make upgrade`

#### Scenario: Alternate HMI APP rootfs path

- **WHEN** the operator runs `APP=cnc_hmi make build-rootfs` after a successful pack for that APP
- **THEN** `output/firmware/cnc_hmi/rootfs.img` MUST exist
- **AND** MUST NOT overwrite `output/firmware/lws_hmi/rootfs.img` if that file already exists

### Requirement: upgrade loads rootfs from APP firmware dir

`make upgrade` (full-system mode) SHALL stream `rootfs.img` from `output/firmware/<APP>/rootfs.img` (default `APP=lws_hmi`). It SHALL continue to load shared FITs from `output/firmware/boot.img` / `boot_b.img`. If the APP-scoped rootfs is missing, the command MUST fail fast with guidance to run `APP=<APP> make build-rootfs`.

#### Scenario: upgrade uses APP-scoped rootfs

- **WHEN** `output/firmware/lws_hmi/rootfs.img` exists and the operator runs `make upgrade`
- **THEN** the host MUST stream that file as the rootfs payload (not a different product’s rootfs under another APP dir)

### Requirement: factory.img and flash resolve under APP and FACTORY_SKU

`make build-img` SHALL package the APP-scoped `rootfs.img` into `output/firmware/<APP>/<FACTORY_SKU>/factory.img`. `make flash` (without `IMAGE=`) SHALL default to that path for the current `APP` and `FACTORY_SKU`. Migration `output/firmware/update.img` SHALL point at the selected/default APP + sku factory artifact.

#### Scenario: flash default uses APP-scoped factory

- **WHEN** `APP=lws_hmi` and `FACTORY_SKU=ynh960-p800` and factory was built for that pair
- **THEN** `make flash` MUST program `output/firmware/lws_hmi/ynh960-p800/factory.img` unless `IMAGE=` overrides
