## MODIFIED Requirements

### Requirement: Full-system apply updates boot and rootfs on the inactive letter

The platform SHALL support a **single** full-system **staged** apply mode for both product/cloud OTA and developer USB-SSH/SSH `make upgrade`: stage an **OTA `tar.gz` and detached `.sig`** under **`/userdata/ota/`**, **Ed25519-verify** the archive (**required for cloud/product download and for host HTTP pull**), extract, then write in this order: inactive `rootfs_*` ← `rootfs.img`; backup running FIT `boot`→`boot_b`; place the inactive letter’s FIT in `boot`; optionally apply **oem**; arm try-boot; reboot. Apply SHALL share the same A/B safety invariants (inactive letter only; derive running letter from the block device mounted as `/`; require misc `active` agreement; reject pending try-boot; compare resolved block devices before writing; MUST NOT format userdata; MUST NOT delete subsystem userdata trees under `/userdata/{wpa_supplicant,network,bluetooth,hmi}`; MUST NOT overwrite the mounted root; MUST NOT rewrite U-Boot or MiniLoader).

Product/cloud and host SSH full-system upgrades SHALL use whole-archive Ed25519 verify as the authenticity gate before write. **Stream-to-partition without staging SHALL NOT** be the default full-system upgrade path. RockUSB `di` / `make flash` remain outside this staged verify gate (Loader `di` writes **both** letters and does not use try-boot arm).

#### Scenario: Successful staged full-system apply includes kernel

- **WHEN** a staged OTA `tar.gz` containing the inactive letter’s FIT and `rootfs.img` (optionally `oem.img`) is applied successfully after Ed25519 verify
- **THEN** inactive rootfs is written, boot is backed up to boot_b, the try FIT is written to boot, try-boot is armed, and the device reboots toward that letter

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

### Requirement: Storage layout documents unified tar.gz staged OTA

`docs/storage-layout.md` (and related upgrade docs) SHALL document that **both** developer USB-SSH/SSH **`make upgrade`** and **online/cloud OTA** use **an OTA `tar.gz` (+ `.sig`) staged under `/userdata/ota/` → Ed25519 verify → extract → apply**. Both show transfer as download progress on the upgrade page, then verify. Userdata prefs must not be wiped. Docs SHALL NOT describe unsigned SSH stream-to-partition as the supported full-system upgrade contract. RockUSB `di` / `make flash` MAY remain documented as unsigned.

#### Scenario: Storage layout describes unified staged path with verify

- **WHEN** a developer reads `docs/storage-layout.md` after this change
- **THEN** the doc states that cloud OTA and SSH `make upgrade` share `tar.gz`+`.sig` staging under `/userdata/ota/`, both verify Ed25519, and that userdata is preserved
