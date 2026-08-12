## MODIFIED Requirements

### Requirement: sim_virt OEM pack

The repository SHALL provide OEM pack `sim_virt` with `oem/packs/sim_virt/manifest.json` declaring `board_id` `sim`, `screen_id` `virt`, paths `boards/sim` and `screens/virt`, and `compat.soc_family` of `virt` (not `rk356x`). `OEM_ID=sim_virt make build-oem` SHALL produce `oem/out/sim_virt/oem.img`. The `boards/sim` tree MUST NOT ship `identity.env` or other per-unit identity seeds — emulator identity uses virtio `provision.img` per `gpt-provision-partition`.

#### Scenario: sim_virt pack present

- **WHEN** a developer inspects `oem/packs/sim_virt/manifest.json`
- **THEN** the manifest SHALL declare `pack_id` `sim_virt`, `board_id` `sim`, `screen_id` `virt`, and `compat.soc_family` `virt`

#### Scenario: build-oem for sim_virt

- **WHEN** `OEM_ID=sim_virt make build-oem` succeeds
- **THEN** `oem/out/sim_virt/oem.img` SHALL exist as an ext4 image containing the pack layout

#### Scenario: sim board pack has no identity.env

- **WHEN** a developer inspects `oem/boards/sim/` after this change
- **THEN** `identity.env` SHALL NOT be present
