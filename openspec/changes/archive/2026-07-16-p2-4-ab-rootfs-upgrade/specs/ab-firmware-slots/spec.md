## ADDED Requirements

### Requirement: GPT provides paired boot and rootfs A/B slots

The product GPT (via `board/parameter-buildroot-fit.txt`) SHALL define **`boot` and `boot_b`** (equal fixed sizes; letter A uses the partition named `boot` because vendor U-Boot `boot_fit` requires that PARTNAME) and **`rootfs_a` and `rootfs_b`** (1 GiB / `0x00200000` sectors each unless documented otherwise). Slot letter **A** means `boot` + `rootfs_a`; letter **B** means `boot_b` + `rootfs_b` (with try-boot swapping `boot`↔`boot_b` so U-Boot always loads `boot`). A single grow **`userdata`** SHALL remain. There SHALL NOT be only one product rootfs after this change.

#### Scenario: Parameter lists paired slots

- **WHEN** a developer inspects `board/parameter-buildroot-fit.txt` after this change
- **THEN** the CMDLINE mtdparts list contains `boot`, `boot_b`, `rootfs_a`, and `rootfs_b` with equal sizes per pair and a trailing `userdata:grow`

#### Scenario: Storage layout documents flash-like upgrade

- **WHEN** a developer reads `docs/storage-layout.md`
- **THEN** the doc documents boot+rootfs A/B, that full-system `make upgrade` updates boot and rootfs (and optional oem), and that userdata prefs must not be wiped

### Requirement: Slot marker selects boot and rootfs together

The platform SHALL persist the **active** slot letter, **try-boot** letter, and rollback metadata in **`misc`** (or another documented non-userdata location). On boot, U-Boot/firmware SHALL load the FIT from the partition named **`boot`** (after any try-boot swap) and mount **`rootfs_${letter}`** (prefer PARTLABEL). The system MUST NOT boot a letter-A FIT with `rootfs_b` or the reverse.

#### Scenario: Default letter after factory flash

- **WHEN** a board is freshly flashed with the A/B `update.img`
- **THEN** it boots letter A (`boot` + `rootfs_a`) and reaches the HMI

#### Scenario: Armed upgrade boots inactive letter pair

- **WHEN** try-boot is armed to the former inactive letter and the board reboots
- **THEN** both the kernel FIT (via swapped `boot`) and rootfs for that letter are used

### Requirement: Full-system apply updates boot and rootfs on the inactive letter

Board helpers SHALL stage a firmware bundle under **`/userdata/ota/`**, require hash-valid slot FITs **`boot.img` / `boot_b.img`** and **`rootfs.img`** (with digests), write rootfs only to the inactive `rootfs_*`, back up the running FIT from `boot` to `boot_b`, and place the inactive letter’s FIT in `boot` for vendor U-Boot to load. They SHALL verify integrity, optionally apply **oem** when present in the bundle, arm try-boot, and reboot. The helper SHALL derive the running letter from the block device actually mounted as `/`, require it to agree with misc `active`, reject a still-pending try-boot, and compare resolved block devices immediately before writing. Helpers MUST NOT format userdata, MUST NOT delete `/userdata/lws-hmi`, MUST NOT overwrite the mounted root, and MUST NOT rewrite U-Boot or MiniLoader.

#### Scenario: Successful full-system apply includes kernel

- **WHEN** a valid bundle with `boot.img` and `rootfs.img` is staged and apply succeeds
- **THEN** both inactive boot and inactive rootfs are written, try-boot is armed, and the device reboots toward that letter

#### Scenario: Bad package leaves active letter intact

- **WHEN** any required image fails checksum or write verification
- **THEN** the active letter and slot marker remain unchanged and apply exits non-zero

#### Scenario: Stale metadata cannot overwrite the mounted root

- **WHEN** misc `active` disagrees with the rootfs partition actually mounted as `/`, or the selected write target resolves to that mounted block device
- **THEN** apply exits non-zero before `dd`, leaves both rootfs partitions unchanged, and reports the unsafe slot state

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

