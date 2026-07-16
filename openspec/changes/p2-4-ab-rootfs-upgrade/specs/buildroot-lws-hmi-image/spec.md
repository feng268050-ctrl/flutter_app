## ADDED Requirements

### Requirement: Firmware GPT and size gates cover boot and rootfs A/B

The lws_hmi image build SHALL consume the A/B `parameter-buildroot-fit.txt` layout with **`boot_a`/`boot_b`** and **`rootfs_a`/`rootfs_b`**. `scripts/verify-firmware-partitions.sh` (or equivalent) SHALL fail the build if `boot.img` exceeds either boot slot or `rootfs.img` exceeds either rootfs slot. Factory packaging SHALL populate **both letters** with the same boot and rootfs images (or an equivalent documented first-boot clone policy).

#### Scenario: Oversized rootfs fails verify

- **WHEN** `rootfs.img` is larger than the `rootfs_a`/`rootfs_b` GPT size
- **THEN** firmware partition verification fails before shipping `update.img`

#### Scenario: Oversized boot fails verify

- **WHEN** `boot.img` is larger than the `boot_a`/`boot_b` GPT size
- **THEN** firmware partition verification fails before shipping `update.img`

#### Scenario: Parameter overlay installs A/B table

- **WHEN** developer runs `make apply-overlay` after this change
- **THEN** the SDK board parameter file matches the repo A/B `parameter-buildroot-fit.txt`

### Requirement: Rootfs overlay ships A/B upgrade helpers

The lws_hmi rootfs overlay SHALL include the board full-system apply/confirm helpers (scripts and any systemd units required by `ab-firmware-slots`), including support for writing **boot and rootfs** on the inactive letter. `scripts/verify-rootfs-overlay.sh` SHALL fail if those helpers are missing from the staging target after `make build-rootfs`.

#### Scenario: verify finds upgrade helpers

- **WHEN** `make build-rootfs` completes successfully after this change
- **THEN** `verify-rootfs-overlay.sh` reports PASS including A/B upgrade helper presence checks

### Requirement: Kernel/boot selection matches A/B letter pairs

The boot chain configuration used by the product image SHALL load the active letter’s `boot_*` FIT and mount the matching `rootfs_*`. Hardcoded sole reliance on a pre-A/B single `boot` partition and `root=/dev/mmcblk0p6` for product boots MUST NOT remain as the only mechanism after this change.

#### Scenario: Bootargs or DTS documents paired slot root

- **WHEN** a developer inspects the ynh960 Linux root DTS/bootargs overlay after this change
- **THEN** root selection is expressed in terms of A/B letters (PARTLABEL or slot-resolved device) paired with the selected boot slot
