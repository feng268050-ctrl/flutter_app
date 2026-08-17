## MODIFIED Requirements

### Requirement: GPT provides paired boot and rootfs A/B slots

The product GPT (via `board/parameter-buildroot-fit.txt`) SHALL define **`boot` and `boot_b`** (equal fixed sizes; letter **A** uses PARTNAME `boot`, letter **B** uses PARTNAME `boot_b`) and **`rootfs_a` and `rootfs_b`** (1 GiB / `0x00200000` sectors each unless documented otherwise). Slot letter **A** means `boot` + `rootfs_a`; letter **B** means `boot_b` + `rootfs_b`. U-Boot SHALL load the FIT from the letter-matched boot partition (not by swapping partition contents into a fixed `boot`). A single grow **`userdata`** SHALL remain. There SHALL NOT be only one product rootfs after this change.

#### Scenario: Parameter lists paired slots

- **WHEN** a developer inspects `board/parameter-buildroot-fit.txt` after this change
- **THEN** the CMDLINE mtdparts list contains `boot`, `boot_b`, `rootfs_a`, and `rootfs_b` with equal sizes per pair and a trailing `userdata:grow`

#### Scenario: Storage layout documents flash-like upgrade

- **WHEN** a developer reads `docs/storage-layout.md`
- **THEN** the doc documents boot+rootfs A/B, that full-system `make upgrade` updates the inactive boot and rootfs partitions (and optional oem), and that userdata prefs must not be wiped

### Requirement: Slot marker selects boot and rootfs together

The platform SHALL persist the **active** slot letter, **try-boot** letter, and rollback metadata in **`misc`** (or another documented non-userdata location). On boot, U-Boot/firmware SHALL load the FIT from the **letter-matched** boot partition (`A`→`boot`, `B`→`boot_b`, preferring armed `try_boot` when set) and mount **`rootfs_${letter}`** (prefer PARTLABEL). The system MUST NOT boot a letter-A FIT with `rootfs_b` or the reverse. Apply and rollback MUST NOT rely on copying or swapping FIT bytes between `boot` and `boot_b` to satisfy U-Boot.

#### Scenario: Default letter after factory flash

- **WHEN** a board is freshly flashed with the A/B `update.img` (or `factory.img`) and slot-aware U-Boot
- **THEN** it boots letter A (`boot` + `rootfs_a`) and reaches the HMI

#### Scenario: Armed upgrade boots inactive letter pair

- **WHEN** try-boot is armed to the former inactive letter, that letter’s FIT is already written to its boot partition, and the board reboots
- **THEN** U-Boot loads the FIT from that letter’s boot partition and mounts the matching `rootfs_*`

### Requirement: Full-system apply updates boot and rootfs on the inactive letter

The platform SHALL support a **single** full-system **staged** apply mode for both product/cloud OTA and developer USB-SSH/SSH `make upgrade`: stage an **OTA `tar.gz` and detached `.sig`** under **`/userdata/ota/`**, **Ed25519-verify** the archive (**required for cloud/product download and for host HTTP pull**), extract, then write in this order: inactive `rootfs_*` ← `rootfs.img`; inactive letter’s FIT ← matching `boot.img` (letter A) or `boot_b.img` (letter B) written to that letter’s boot partition only; optionally apply **oem**; arm try-boot; reboot. Apply MUST NOT backup `boot`→`boot_b` and MUST NOT swap `boot`↔`boot_b` contents. Apply SHALL share the same A/B safety invariants (inactive letter only; derive running letter from the block device mounted as `/`; require misc `active` agreement; reject pending try-boot; compare resolved block devices before writing; MUST NOT format userdata; MUST NOT delete subsystem userdata trees under `/userdata/{wpa_supplicant,network,bluetooth,hmi}`; MUST NOT overwrite the mounted root; MUST NOT rewrite U-Boot or MiniLoader).

Product/cloud and host SSH full-system upgrades SHALL use whole-archive Ed25519 verify as the authenticity gate before write. **Stream-to-partition without staging SHALL NOT** be the default full-system upgrade path. RockUSB `di` / `make flash` remain outside this staged verify gate (Loader `di` writes **both** letters and does not use try-boot arm).

#### Scenario: Successful staged full-system apply includes kernel

- **WHEN** a staged OTA `tar.gz` containing the inactive letter’s FIT and `rootfs.img` (optionally `oem.img`) is applied successfully after Ed25519 verify
- **THEN** inactive rootfs is written, the try FIT is written only to the inactive letter’s boot partition, try-boot is armed, and the device reboots toward that letter

#### Scenario: Bad package signature refuses write

- **WHEN** a staged archive (cloud or host HTTP) fails Ed25519 verification against the embedded pubkey
- **THEN** the active letter remains unchanged, no partition write proceeds past the gate, and apply exits non-zero

#### Scenario: Host package without signature refuses write

- **WHEN** `make upgrade` over SSH triggers a host HTTP pull of an OTA `tar.gz` under `/userdata/ota/` without a valid `.sig`
- **THEN** apply MUST refuse to write and exit non-zero

#### Scenario: Bad staged write leaves active letter intact

- **WHEN** write verification fails after extract
- **THEN** the active letter and slot marker remain unchanged and apply exits non-zero

#### Scenario: Stale metadata cannot overwrite the mounted root

- **WHEN** misc `active` disagrees with the rootfs partition actually mounted as `/`, or the selected write target resolves to that mounted block device
- **THEN** apply exits non-zero before writing, leaves both rootfs partitions unchanged, and reports the unsafe slot state

#### Scenario: Upgrade does not touch bootloader images

- **WHEN** a full-system staged apply runs
- **THEN** the uboot partition content is not overwritten by the upgrade helpers

### Requirement: Boot confirm commits or rolls back the letter pair

After an armed try-boot, the image SHALL **commit** the new letter when health checks pass, or **revert** to the previous letter and reboot when checks fail or the try budget is exhausted. Commit and rollback SHALL always move boot and rootfs **selection** together via the misc marker. Rollback MUST restore the previous letter by updating misc and rebooting; it MUST NOT swap or copy FIT contents between `boot` and `boot_b`.

#### Scenario: Healthy boot commits new letter

- **WHEN** try-boot boots the new letter and health checks pass (including HMI reaching an acceptable running state within the configured timeout)
- **THEN** that letter becomes active and try-boot is cleared

#### Scenario: Unhealthy boot rolls back both images

- **WHEN** try-boot boots the new letter and health checks fail within the try budget
- **THEN** misc restores the previous letter as active (boot+rootfs selection), no boot-partition content swap is performed, and the board reboots into the previous letter
