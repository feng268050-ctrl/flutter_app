## ADDED Requirements

### Requirement: Factory-reset wipe contract

The platform SHALL provide a single **factory-reset** operation as the implementation behind the **user-facing** 恢复出厂设置 feature. It returns the appliance to clean **user/operator** defaults without rewriting GPT, U-Boot, MiniLoader, boot FIT letters, rootfs letters, or oem. The operation MUST erase **all** operator/runtime state on the **userdata** partition (full userdata wipe — format or equivalent emptying of the grow partition). The operation MUST preserve:

- Rockchip Vendor Storage brand / model / SN (IDs **1** / **20** / **21**)
- Vendor Storage sealed cloud Ed25519 (ID **22**) and seal KEK wrap (ID **23**) on Rockchip boards
- The entire **`provision`** partition filesystem, including `properties.ini` and non-Rockchip `identity.env` / sealed blobs when applicable

The operation MUST NOT be implied by cold reboot, `make push-app`, `make upgrade`, or cloud/host OTA.

#### Scenario: Full userdata wipe

- **WHEN** factory-reset completes and the board reboots
- **THEN** prior contents under `/userdata` (wpa, network, bluetooth, hmi, ota, models, tee, cfg, etc.) SHALL be gone
- **AND** userdata SHALL NOT retain operator HAL prefs that lived only on userdata

#### Scenario: provision tunables survive

- **WHEN** `/mnt/provision/properties.ini` holds `camera_ip=10.0.0.50` before factory-reset
- **AND** factory-reset completes
- **THEN** `camera_ip` SHALL still be `10.0.0.50` on provision

#### Scenario: Identity and cloud key survive on Rockchip

- **WHEN** Vendor Storage holds brand, model, SN, ID **22**, and ID **23** before factory-reset
- **AND** factory-reset completes
- **THEN** readback of identity and sealed blobs is unchanged
- **AND** the device MUST NOT require cloud re-activation solely because factory-reset ran

### Requirement: Board factory-reset helper

The image SHALL ship `/usr/libexec/board/factory-reset.sh` and `/usr/bin/factory-reset`. The helper MUST stop Flutter seats, stop or release network/BT stacks as needed, **wipe the entire userdata partition** (not selective deletes under `/userdata/hal` while keeping files), recreate empty userdata layout for bind-prefs on next boot, sync, and reboot. The helper MUST NOT format, `mkfs`, or delete files on `PARTLABEL=provision`. The helper MUST NOT clear or rewrite Vendor Storage IDs **1** / **20** / **21** / **22** / **23** on Rockchip boards.

#### Scenario: Helper preserves provision

- **WHEN** factory-reset runs on a board with mounted provision
- **THEN** `/mnt/provision/properties.ini` is unchanged after reboot
- **AND** userdata operator trees are empty

### Requirement: Flash-time prefs hygiene matches wipe contract

A compliant **`make flash`** path SHALL wipe **userdata** (full operator partition content) while preserving Vendor Storage (Rockchip) and the **provision** partition per `gpt-provision-partition`. Flash imaging is not the user-facing factory-reset entry but MUST align with the same preserve/erase split.

#### Scenario: Repeat flash preserves provision and VS

- **WHEN** a provisioned board receives two compliant `make flash` operations without GPT geometry change
- **THEN** `properties.ini` on provision and Rockchip VS identity SHALL match pre-second-flash values
- **AND** userdata after flash SHALL not retain prior operator trees
