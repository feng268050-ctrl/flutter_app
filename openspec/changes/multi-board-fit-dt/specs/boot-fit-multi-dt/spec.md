## ADDED Requirements

### Requirement: Multi-configuration boot FIT

`make build-kernel` SHALL produce A/B FIT images (`boot.img` / `boot_b.img`) from a multi-configuration ITS (successor to single-`fdt`/`conf` `boot-slim.its`) that embeds **one** shared kernel image and **one or more** `flat_dt` images, each referenced by a named configuration whose name derives from product `board_id`. The default configuration SHALL be `ynh960` while that board remains the validation SKU. Startup device trees MUST remain inside the FIT (MUST NOT be loaded from `/oem`).

#### Scenario: ynh960 remains default conf

- **WHEN** an operator builds kernel FITs with the multi-board packaging enabled and only the ynh960 board DTB is in the inventory
- **THEN** the FIT SHALL expose a configuration named for `ynh960` as default
- **AND** a ynh960 device upgraded with that FIT SHALL boot to the HMI smoke path equivalent to the prior single-FDT FIT

#### Scenario: Multiple board FDTs share one kernel

- **WHEN** the board inventory lists two or more board ids with buildable DTBs
- **THEN** the FIT SHALL contain multiple `flat_dt` images and matching configurations
- **AND** those configurations SHALL reference the same kernel image node (MUST NOT duplicate the kernel payload per board)

### Requirement: Boot-time DT selection before Linux

Product boot firmware SHALL select the FIT configuration **before** entering the Linux kernel. Linux on product boards MUST treat the loaded DT as authoritative for hardware. Selection MAY use U-Boot environment, boot script, or factory-programmed default conf, but MUST be deterministic per flashed SKU.

#### Scenario: Selected conf matches intended board

- **WHEN** a device is provisioned for `board_id` `ynh960`
- **THEN** U-Boot SHALL boot the FIT configuration for `ynh960` (default or env override)
- **AND** the running kernel SHALL expose a device tree consistent with that board’s overlay set

### Requirement: Ordering before kernel LTS rebase

This multi-board FIT packaging SHALL be implemented and ynh960-regressed **before** implementation of `kernel-61-lts-rebase` begins. Subsequent kernel LTS merges and product overlay patch rebases SHALL target the multi-board overlay/FIT layout (all inventoried board DTS fragments), not the legacy single anonymous `conf` ITS.

#### Scenario: LTS change waits on multi-DT scaffolding

- **WHEN** operators plan kernel 6.1 LTS tip catch-up
- **THEN** they SHALL treat `multi-board-fit-dt` packaging as a prerequisite (or record an explicit waiver with rationale)
- **AND** MUST NOT redesign single-FDT ITS as part of the LTS change after this capability exists

### Requirement: FIT size and inventory verification

The build SHALL fail if the multi-configuration FIT exceeds the GPT `boot` / `boot_b` size limits. Host verify (or build-kernel post-check) SHALL list the embedded configuration names from the board inventory and fail if a listed board lacks a DTB or conf.

#### Scenario: Oversized FIT fails build

- **WHEN** the generated `boot.img` exceeds the boot partition size used by `verify-firmware-partitions`
- **THEN** the build or verify step SHALL fail before factory packaging succeeds

#### Scenario: Inventory conf names are checkable

- **WHEN** `make build-kernel` completes successfully with inventory boards `B1…Bn`
- **THEN** a documented inspect/verify path SHALL show FIT configurations for each listed board id
