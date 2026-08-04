## MODIFIED Requirements

### Requirement: Full-system apply updates boot and rootfs on the inactive letter

The platform SHALL support a **single** full-system apply mode for both product/cloud OTA and developer `make upgrade`: stage an **OTA zip** (or its extracted contents) under **`/userdata/ota/`**, extract if needed, verify each image with a detached **Ed25519** signature (`*.img.sig`) against the device-embedded pubkey over the complete image bytes, write rootfs only to the inactive `rootfs_*`, back up the running FIT from `boot` to `boot_b`, place the inactive letter’s FIT in `boot`, optionally apply **oem** when present and signed, arm try-boot, and reboot. Apply SHALL share the same A/B safety invariants (inactive letter only; derive running letter from the block device mounted as `/`; require misc `active` agreement; reject pending try-boot; compare resolved block devices before writing; MUST NOT format userdata; MUST NOT delete subsystem userdata trees under `/userdata/{wpa_supplicant,network,bluetooth,hmi}`; MUST NOT overwrite the mounted root; MUST NOT rewrite U-Boot or MiniLoader).

Product and developer full-system upgrades SHALL use Ed25519 verify as the sole pre-write authenticity/integrity gate and SHALL NOT require a separate `.sha256` / digest check (or unsigned digest/manifest) or zip-level seal alone as authorization to write. **Stream-to-partition without staging and without Ed25519 verification SHALL NOT** be the default full-system upgrade path.

#### Scenario: Successful staged full-system apply includes kernel

- **WHEN** a valid Ed25519-signed bundle (from an OTA zip) with the inactive letter’s FIT and `rootfs.img` (and matching `*.sig`), optionally `oem.img`, is staged under `/userdata/ota/` and staged apply succeeds
- **THEN** both inactive boot and inactive rootfs are written, try-boot is armed, and the device reboots toward that letter

#### Scenario: Bad or missing image signature refuses write

- **WHEN** any required staged image fails Ed25519 verification against the embedded pubkey (corrupt bytes, or wrong/missing `*.sig`)
- **THEN** the active letter and slot marker remain unchanged, no partition write for that apply proceeds past the gate, and apply exits non-zero

#### Scenario: Host-uploaded zip follows the same staged path

- **WHEN** `make upgrade` has finished uploading the OTA zip under `/userdata/ota/` and on-device extract-and-apply runs
- **THEN** verification and writes obey the same staged Ed25519 rules as a cloud-downloaded zip

#### Scenario: Bad staged package leaves active letter intact

- **WHEN** any required staged image fails Ed25519 verification or write verification
- **THEN** the active letter and slot marker remain unchanged and apply exits non-zero

#### Scenario: Stale metadata cannot overwrite the mounted root

- **WHEN** misc `active` disagrees with the rootfs partition actually mounted as `/`, or the selected write target resolves to that mounted block device
- **THEN** apply exits non-zero before writing, leaves both rootfs partitions unchanged, and reports the unsafe slot state

#### Scenario: Upgrade does not touch bootloader images

- **WHEN** a full-system staged apply runs
- **THEN** the uboot partition content is not overwritten by the upgrade helpers

### Requirement: Storage layout documents unified zip staged OTA

`docs/storage-layout.md` (and related upgrade docs) SHALL document that **both** developer **`make upgrade`** and **online/cloud OTA** use **an OTA zip staged under `/userdata/ota/` → extract → Ed25519-signed image verified apply** (detached `*.sig` per full img; HMI ships with rootfs), differing only in how the zip arrives (host upload vs network download; both shown as download progress on the upgrade page), and that userdata prefs must not be wiped by either path. Docs SHALL NOT describe unsigned SSH stream-to-partition as the supported full-system upgrade contract.

#### Scenario: Storage layout describes unified staged path

- **WHEN** a developer reads `docs/storage-layout.md` after this change
- **THEN** the doc states that cloud OTA and `make upgrade` share zip staging + Ed25519-verified apply under `/userdata/ota/`, and that userdata is preserved
