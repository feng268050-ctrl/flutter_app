## ADDED Requirements

### Requirement: Factory-reset wipe contract

The platform SHALL provide a single **factory-reset** operation as the implementation behind the **user-facing** 恢复出厂设置 feature. It returns the appliance to clean **user/operator** defaults without rewriting GPT, U-Boot, MiniLoader, boot FIT letters, rootfs letters, or oem. The operation MUST erase operator/runtime state under `/userdata` as defined by the preserve/erase matrix. The operation MUST preserve:

- Vendor Storage brand / model / SN (IDs **1** / **20** / **21**)
- Vendor Storage sealed cloud Ed25519 (ID **22**) — activated cloud identity MUST remain valid without re-activation
- Vendor Storage HUK-wrapped seal KEK (ID **23**)
- Factory tunables file **`/var/lib/hal/properties.ini`** (→ `/userdata/hal/properties.ini`)

The operation MUST NOT be implied by cold reboot, `make push-app`, `make upgrade`, or cloud/host OTA.

#### Scenario: Wipe clears operator prefs and App state

- **WHEN** factory-reset completes and the board reboots
- **THEN** operator networks and wanted markers under `/userdata/{wpa_supplicant,network,bluetooth}` are gone
- **AND** Wi‑Fi credentials vault and operator `wpa_supplicant.conf` networks are gone
- **AND** App databases and settings under the hmi tree (including process-library and alarm-log DBs) are gone
- **AND** operator HAL preference files under `/userdata/hal/` (e.g. `display.conf`, `sound.conf`, `locale.conf`) are gone

#### Scenario: Factory properties.ini preserved

- **WHEN** `/userdata/hal/properties.ini` exists with factory keys (e.g. `camera_ip`) before factory-reset
- **AND** factory-reset completes
- **THEN** that `properties.ini` file is still present with the same factory keys

#### Scenario: Wipe clears media and staging

- **WHEN** factory-reset completes
- **THEN** prior contents under `/userdata/storage`, `/userdata/ota`, and `/userdata/models` are removed (directories MAY be recreated empty)

#### Scenario: Identity, cloud key, and seal KEK survive

- **WHEN** Vendor Storage holds brand, model, SN, sealed cloud Ed25519 (ID **22**), and seal KEK wrap (ID **23**) before factory-reset
- **AND** factory-reset completes
- **THEN** brand, model, and SN readback are unchanged
- **AND** ID **22** still holds the sealed cloud Ed25519 blob
- **AND** ID **23** remains present
- **AND** the device MUST NOT require cloud re-activation solely because factory-reset ran

#### Scenario: Firmware letters untouched

- **WHEN** factory-reset runs on a board with distinct A/B rootfs contents
- **THEN** the helper MUST NOT `dd` or format `boot`, `boot_b`, `rootfs_a`, `rootfs_b`, or `oem`

### Requirement: Board factory-reset helper

The image SHALL ship `/usr/libexec/board/factory-reset.sh` and an operator command `/usr/bin/factory-reset` that invokes it. The helper MUST stop Flutter seats that may hold userdata open (`hmi.service`, `os-settings.service`), stop or release network/BT stacks as needed to unlock prefs binds, erase wipe-contract **operator** trees under `/userdata`, selectively clear operator files under `/userdata/hal/` while preserving `properties.ini`, recreate empty bind-prefs layout for wiped trees as required for next boot, sync, and reboot. The helper MUST NOT clear or rewrite Vendor Storage IDs **1** / **20** / **21** / **22** / **23**. The helper MUST log progress to the system journal. When `/userdata` is expected but not mounted, the helper MUST fail closed without rebooting into a half-applied state when detection is reliable; otherwise it MUST log clearly and exit non-zero.

#### Scenario: Helper invoked from user Settings path

- **WHEN** the user confirms 恢复出厂设置 in HMI Settings (or an optional mirror invokes `/usr/bin/factory-reset`) on a product board with `/userdata` mounted
- **THEN** the wipe contract is applied
- **AND** the board reboots
- **AND** `properties.ini` and VS IDs 1/20/21/22/23 are unchanged

#### Scenario: Seats stopped before delete

- **WHEN** `hmi.service` or `os-settings.service` is active
- **AND** factory-reset starts
- **THEN** those services are stopped before deleting userdata trees

### Requirement: HMI Settings exposes user factory reset

**Product HMI Settings** SHALL expose **恢复出厂设置** / Erase All Data as a **user-facing** action (this is the required product path). The UI MUST present a two-step confirmation that states: the user’s data and settings will be permanently erased; device provisioning (`properties.ini`) and cloud activation are kept; firmware is not rolled back. Confirming MUST invoke the board `factory-reset` helper (not a Dart-only delete). This feature MUST NOT be documented or presented as a 产线 / factory-floor procedure.

#### Scenario: User confirms from HMI Settings

- **WHEN** the user completes both confirmation steps in product HMI Settings
- **THEN** the App invokes `/usr/bin/factory-reset` (or the libexec script)
- **AND** the device proceeds to wipe and reboot

#### Scenario: Cancel leaves data intact

- **WHEN** the user cancels at either confirmation step
- **THEN** userdata operator trees, `properties.ini`, and VS ID **22** remain unchanged

### Requirement: Optional OS Settings mirror of the same user action

**OS Settings** MAY expose the same Erase All Data control when that seat is active. If present, it MUST call the same board helper and use the same keep/erase semantics. Presence in OS Settings MUST NOT redefine the feature as after-sales-only or 产线-only.

#### Scenario: OS Settings mirror uses same helper

- **WHEN** OS Settings exposes Erase All Data and the user completes confirmation
- **THEN** the App invokes the same `/usr/bin/factory-reset` helper
- **AND** wipe semantics match the HMI path

### Requirement: Flash-time prefs hygiene matches wipe contract

A compliant **`make flash`** path SHOULD leave **operator** userdata aligned with the user factory-reset wipe contract (clear operator prefs; preserve `properties.ini` and VS IDs **1** / **20** / **21** / **22** / **23**). This is platform hygiene for image install — **not** the user-facing factory-reset feature. Documentation MUST distinguish: users reset via HMI Settings; upgrade/OTA preserve userdata; flash is a separate imaging path.

#### Scenario: Docs distinguish user reset from flash and upgrade

- **WHEN** an operator reads storage-layout / Settings docs after this change
- **THEN** they state that **恢复出厂设置** is a user HMI Settings action
- **AND** that upgrade/OTA preserve userdata
- **AND** that flash imaging is not the product’s user factory-reset entry