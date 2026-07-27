## ADDED Requirements

### Requirement: make upgrade streams OEM when available

After resolving `FACTORY_SKU` / `OEM_ID` (same resolver as `build-oem`), `make upgrade` SHALL stream `oem.img` into the device `oem` partition when the resolved image exists, unless the operator explicitly disables OEM update via documented env (e.g. empty `OEM_IMG=`). When `OEM_ONLY=1`, the command SHALL stream only `oem.img` (requiring it to exist), SHALL NOT write boot/rootfs, and SHALL plain-reboot without arming an A/B letter switch. When the resolved oem image is missing and `OEM_ONLY` is not set, full-system boot/rootfs upgrade MAY still proceed with a clear warning that OEM was skipped. `make upgrade` MUST NOT use `factory.img` / RockUSB for the A/B stream path.

#### Scenario: Default upgrade writes oem

- **WHEN** `oem/out/<oem_id>/oem.img` exists for the resolved sku and the operator runs `make upgrade` without disabling OEM
- **THEN** the host streams that oem image to `PARTLABEL=oem` in addition to inactive boot/rootfs

#### Scenario: OEM-only upgrade

- **WHEN** the operator runs `make upgrade OEM_ONLY=1` after `make build-oem`
- **THEN** the host streams only `oem.img` to `PARTLABEL=oem` and requests a plain reboot without changing the A/B active letter

#### Scenario: Missing oem warns but upgrades OS

- **WHEN** resolved `oem.img` is absent, `OEM_ONLY` is not `1`, and the operator runs `make upgrade`
- **THEN** the command MAY complete boot/rootfs upgrade after warning that OEM was not updated
