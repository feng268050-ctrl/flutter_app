## MODIFIED Requirements

### Requirement: Multi-configuration boot FIT

`make build-kernel` SHALL produce A/B FIT images (`boot.img` / `boot_b.img`) from a multi-configuration ITS that embeds **one** shared kernel image and **one or more** `flat_dt` images, each referenced by a named configuration whose name derives from product `board_id`. The default configuration SHALL be `ynh960` while that board remains the validation SKU. When `ek3562` is listed in the board inventory and its DTB builds, the FIT SHALL also expose configuration **`ek3562`**. Startup device trees MUST remain inside the FIT (MUST NOT be loaded from `/oem`).

#### Scenario: ynh960 remains default conf

- **WHEN** an operator builds kernel FITs with the multi-board packaging enabled and `ynh960` is in the inventory
- **THEN** the FIT SHALL expose a configuration named for `ynh960` as default
- **AND** a ynh960 device upgraded with that FIT SHALL boot to the HMI smoke path equivalent to the prior single-FDT FIT

#### Scenario: Multiple board FDTs share one kernel

- **WHEN** the board inventory lists two or more board ids with buildable DTBs (including `ynh960` and `ek3562` when both are enabled)
- **THEN** the FIT SHALL contain multiple `flat_dt` images and matching configurations
- **AND** those configurations SHALL reference the same kernel image node (MUST NOT duplicate the kernel payload per board)

#### Scenario: ek3562 conf present when inventoried

- **WHEN** `ek3562` is listed in `board/rk356x-fit-boards.txt` and `ek3562.dtb` builds
- **THEN** the FIT SHALL contain configuration `ek3562`
