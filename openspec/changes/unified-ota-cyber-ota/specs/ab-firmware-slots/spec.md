## MODIFIED Requirements

### Requirement: Full-system apply updates boot and rootfs on the inactive letter

The platform SHALL support a **single** full-system **staged** apply mode for both product/cloud OTA and developer `make upgrade`: stage an **OTA `tar.gz`** under **`/userdata/ota/`**, optionally verify the archive (**required for cloud/product download**; **not required for host `make upgrade` upload**), extract, write rootfs only to the inactive `rootfs_*`, back up the running FIT from `boot` to `boot_b`, place the inactive letter’s FIT in `boot`, optionally apply **oem** when present, arm try-boot, and reboot. Apply SHALL share the same A/B safety invariants (inactive letter only; derive running letter from the block device mounted as `/`; require misc `active` agreement; reject pending try-boot; compare resolved block devices before writing; MUST NOT format userdata; MUST NOT delete subsystem userdata trees under `/userdata/{wpa_supplicant,network,bluetooth,hmi}`; MUST NOT overwrite the mounted root; MUST NOT rewrite U-Boot or MiniLoader).

Product/cloud full-system upgrades SHALL use whole-archive Ed25519 verify as the authenticity gate before write. Developer host-upload upgrades SHALL use staged extract-and-apply **without** Ed25519 as a gate. **Stream-to-partition without staging SHALL NOT** be the default full-system upgrade path.

#### Scenario: Successful staged full-system apply includes kernel

- **WHEN** a staged OTA `tar.gz` containing the inactive letter’s FIT and `rootfs.img` (optionally `oem.img`) is applied successfully (after cloud verify when applicable)
- **THEN** both inactive boot and inactive rootfs are written, try-boot is armed, and the device reboots toward that letter

#### Scenario: Bad cloud package signature refuses write

- **WHEN** a cloud-staged archive fails Ed25519 verification against the embedded pubkey
- **THEN** the active letter remains unchanged, no partition write proceeds past the gate, and apply exits non-zero

#### Scenario: Host-uploaded package applies without signature

- **WHEN** `make upgrade` has finished uploading an OTA `tar.gz` under `/userdata/ota/` without a `.sig` and on-device extract-and-apply runs
- **THEN** writes proceed under the same A/B safety rules without requiring Ed25519 verification

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

`docs/storage-layout.md` (and related upgrade docs) SHALL document that **both** developer **`make upgrade`** and **online/cloud OTA** use **an OTA `tar.gz` staged under `/userdata/ota/` → extract → apply**, differing by ingress and trust: cloud downloads ALSO require whole-archive Ed25519 verify; host upload does not. Both show transfer as download progress on the upgrade page. Userdata prefs must not be wiped. Docs SHALL NOT describe unsigned SSH stream-to-partition as the supported full-system upgrade contract.

#### Scenario: Storage layout describes unified staged path and trust split

- **WHEN** a developer reads `docs/storage-layout.md` after this change
- **THEN** the doc states that cloud OTA and `make upgrade` share `tar.gz` staging under `/userdata/ota/`, that cloud verifies Ed25519 and host upgrade does not, and that userdata is preserved
