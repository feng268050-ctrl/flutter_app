## MODIFIED Requirements

### Requirement: sim_virt OEM pack

The repository SHALL provide OEM pack `sim_virt` with `oem/packs/sim_virt/manifest.json` declaring `board_id` `sim`, `screen_id` `virt`, paths `boards/sim` and `screens/virt`, and `compat.soc_family` of `virt`. `OEM_ID=sim_virt make build-oem` SHALL produce `oem/out/sim_virt/oem.img`. The `boards/sim` tree MUST NOT ship `identity.env` or other per-unit identity seeds — emulator identity uses virtio `provision.img` per `gpt-provision-partition`.

#### Scenario: sim board pack has no identity.env

- **WHEN** a developer inspects `oem/boards/sim/` after this change
- **THEN** `identity.env` SHALL NOT be present

## REMOVED Requirements

### Requirement: sim_virt emulator identity via OEM identity.env

**Reason**: Per-unit SN must not live in shared OEM; provision virtio disk is authoritative for emulator identity when Vendor Storage is absent.

**Migration**: Remove `oem/boards/sim/identity.env`; use `make write-identity` or first-boot autogen into `provision/identity.env`.
