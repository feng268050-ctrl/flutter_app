## MODIFIED Requirements

### Requirement: Full-system apply updates boot and rootfs on the inactive letter

The platform SHALL support two full-system apply modes that share the same A/B safety invariants (inactive letter only; derive running letter from the block device mounted as `/`; require misc `active` agreement; reject pending try-boot; compare resolved block devices before writing; MUST NOT format userdata; MUST NOT delete subsystem userdata trees under `/userdata/{wpa_supplicant,network,bluetooth,hmi}`; MUST NOT overwrite the mounted root; MUST NOT rewrite U-Boot or MiniLoader).

**Staged apply** (online / product OTA): Board helpers SHALL accept a firmware bundle under **`/userdata/ota/`**, require hash-valid slot FITs **`boot.img` / `boot_b.img`** and **`rootfs.img`** (with digests), write rootfs only to the inactive `rootfs_*`, back up the running FIT from `boot` to `boot_b`, place the inactive letter’s FIT in `boot`, optionally apply **oem** when present, arm try-boot, and reboot.

**Stream apply** (developer `make upgrade` over SSH): The board SHALL accept host-orchestrated streams of **`rootfs.img`** and **only the inactive letter’s FIT** (plus optional oem) directly into the inactive rootfs device and the try-boot FIT path on `boot` (after backing up the running FIT to `boot_b`), then arm try-boot and reboot. Stream apply MUST NOT require full firmware images to be staged under `/userdata/ota/` before writing. Incomplete or failed streams MUST NOT arm try-boot.

#### Scenario: Successful staged full-system apply includes kernel

- **WHEN** a valid bundle with `boot.img` / `boot_b.img` and `rootfs.img` is staged under `/userdata/ota/` and staged apply succeeds
- **THEN** both inactive boot and inactive rootfs are written, try-boot is armed, and the device reboots toward that letter

#### Scenario: Successful stream apply writes during transfer

- **WHEN** stream apply receives a complete rootfs stream and the matching inactive FIT stream over SSH
- **THEN** the inactive rootfs and try-boot FIT on `boot` are written without a prior full-image stage under `/userdata/ota/`, try-boot is armed, and the device reboots toward that letter

#### Scenario: Bad staged package leaves active letter intact

- **WHEN** any required staged image fails checksum or write verification
- **THEN** the active letter and slot marker remain unchanged and apply exits non-zero

#### Scenario: Incomplete stream does not arm try-boot

- **WHEN** a stream apply transfer is truncated or fails before all required images are written
- **THEN** try-boot is not armed, the active letter remains bootable, and apply/host exit non-zero

#### Scenario: Stale metadata cannot overwrite the mounted root

- **WHEN** misc `active` disagrees with the rootfs partition actually mounted as `/`, or the selected write target resolves to that mounted block device
- **THEN** apply exits non-zero before writing, leaves both rootfs partitions unchanged, and reports the unsafe slot state

#### Scenario: Upgrade does not touch bootloader images

- **WHEN** a full-system staged or stream apply runs
- **THEN** the uboot partition content is not overwritten by the upgrade helpers

## ADDED Requirements

### Requirement: Storage layout documents stream upgrade vs staged OTA

`docs/storage-layout.md` (and related upgrade docs) SHALL document that developer **`make upgrade`** uses **stream-to-partition** over SSH, while **online OTA** uses **download / stage under `/userdata/ota/` then digest-verified apply**, and that userdata prefs must not be wiped by either path.

#### Scenario: Storage layout distinguishes the two paths

- **WHEN** a developer reads `docs/storage-layout.md` after this change
- **THEN** the doc states stream-to-partition for `make upgrade` and download-then-write staging for online OTA, both preserving userdata
