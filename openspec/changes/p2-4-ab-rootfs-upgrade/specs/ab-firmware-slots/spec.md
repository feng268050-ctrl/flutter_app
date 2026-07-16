## ADDED Requirements

### Requirement: GPT provides paired boot and rootfs A/B slots

The product GPT (via `board/parameter-buildroot-fit.txt`) SHALL define **`boot_a` and `boot_b`** (equal fixed sizes, matching the former single `boot` budget unless storage-layout documents otherwise) and **`rootfs_a` and `rootfs_b`** (1 GiB / `0x00200000` sectors each unless documented otherwise). Slot letter **A** means `boot_a` + `rootfs_a`; letter **B** means `boot_b` + `rootfs_b`. A single grow **`userdata`** SHALL remain. There SHALL NOT be only one product `boot` or only one product `rootfs` after this change.

#### Scenario: Parameter lists paired slots

- **WHEN** a developer inspects `board/parameter-buildroot-fit.txt` after this change
- **THEN** the CMDLINE mtdparts list contains `boot_a`, `boot_b`, `rootfs_a`, and `rootfs_b` with equal sizes per pair and a trailing `userdata:grow`

#### Scenario: Storage layout documents flash-like upgrade

- **WHEN** a developer reads `docs/storage-layout.md`
- **THEN** the doc documents boot+rootfs A/B, that full-system `make upgrade` updates boot and rootfs (and optional oem), and that userdata prefs must not be wiped

### Requirement: Slot marker selects boot and rootfs together

The platform SHALL persist the **active** slot letter, **try-boot** letter, and rollback metadata in **`misc`** (or another documented non-userdata location). On boot, U-Boot/firmware SHALL load the FIT from **`boot_${letter}`** and mount **`rootfs_${letter}`** (prefer PARTLABEL). The system MUST NOT boot `boot_a` with `rootfs_b` or the reverse.

#### Scenario: Default letter after factory flash

- **WHEN** a board is freshly flashed with the A/B `update.img`
- **THEN** it boots letter A (`boot_a` + `rootfs_a`) and reaches the HMI

#### Scenario: Armed upgrade boots inactive letter pair

- **WHEN** try-boot is armed to the former inactive letter and the board reboots
- **THEN** both the kernel FIT and rootfs for that letter are used

### Requirement: Full-system apply updates boot and rootfs on the inactive letter

Board helpers SHALL stage a firmware bundle under **`/userdata/ota/`**, require **`boot.img` and `rootfs.img`** (with digests), write them only to the **inactive** `boot_*` and `rootfs_*` partitions, verify integrity, optionally apply **oem** when present in the bundle, arm try-boot, and reboot. Helpers MUST NOT format userdata, MUST NOT delete `/userdata/lws-hmi`, MUST NOT overwrite the active letter’s boot or rootfs, and MUST NOT rewrite U-Boot or MiniLoader.

#### Scenario: Successful full-system apply includes kernel

- **WHEN** a valid bundle with `boot.img` and `rootfs.img` is staged and apply succeeds
- **THEN** both inactive boot and inactive rootfs are written, try-boot is armed, and the device reboots toward that letter

#### Scenario: Bad package leaves active letter intact

- **WHEN** any required image fails checksum or write verification
- **THEN** the active letter and slot marker remain unchanged and apply exits non-zero

#### Scenario: Upgrade does not touch bootloader images

- **WHEN** a full-system apply runs
- **THEN** the uboot partition content is not overwritten by the upgrade helpers

### Requirement: Boot confirm commits or rolls back the letter pair

After an armed try-boot, the image SHALL **commit** the new letter when health checks pass, or **revert** to the previous letter and reboot when checks fail or the try budget is exhausted. Commit and rollback SHALL always move boot and rootfs selection together.

#### Scenario: Healthy boot commits new letter

- **WHEN** try-boot boots the new letter and health checks pass (including HMI reaching an acceptable running state within the configured timeout)
- **THEN** that letter becomes active and try-boot is cleared

#### Scenario: Unhealthy boot rolls back both images

- **WHEN** try-boot boots the new letter and health checks fail within the try budget
- **THEN** the previous letter is restored as active (boot+rootfs) and the board reboots into it

### Requirement: App-only upgrade path is reserved

The board/host upgrade tooling SHALL accept an **app-only** mode that updates application files under **`/oem/hmi`** (or the documented oem app path) **without** switching the boot/rootfs letter. Full-system paired-slot update remains the primary P2.4 acceptance path.

#### Scenario: App-only does not switch letters

- **WHEN** upgrade is invoked in app-only mode with a valid app payload
- **THEN** the active boot/rootfs letter marker is unchanged
