## ADDED Requirements

### Requirement: OEM board_id aligns with FIT configuration

OEM pack `manifest.json` (and thus on-device `/oem/manifest.json`) SHALL declare `board_id` that corresponds to the FIT configuration name used to boot that SKU. OEM MUST NOT supply the startup device tree. Compose or host verify MAY fail or warn when a pack’s `board_id` is not present in the running OS’s documented FIT board inventory for that OS version.

#### Scenario: Manifest board_id matches FIT conf name

- **WHEN** inspecting `oem/packs/*/manifest.json` for a product pack
- **THEN** `board_id` SHALL be a FIT configuration id expected by `boot-fit-multi-dt` (e.g. `ynh960`)
- **AND** startup DTB files MUST NOT appear under `/oem` as the boot source

#### Scenario: Compose does not load DTB from OEM

- **WHEN** `oem-compose` runs successfully
- **THEN** it SHALL export board profile / screen env as today
- **AND** it MUST NOT replace the kernel’s loaded device tree from OEM contents
