## ADDED Requirements

### Requirement: Board OEM MAY include a radio firmware pack

A board OEM pack MAY include a `radio/` directory with a `manifest.json` and a `firmware/` subtree containing only the combo Wi‑Fi/BT **module firmware blobs** required for that board’s onboard radio (not a multi-vendor kitchen sink). For ynh960 (AIC8800D80), the pack SHALL include the documented keep-set under `radio/firmware/` and identify the chip in `manifest.json`. Kernel modules (`aic8800_*.ko`) MUST NOT be shipped inside the OEM radio pack.

#### Scenario: ynh960 oem.img contains AIC keep-set

- **WHEN** `OEM_ID` resolves to the ynh960 board pack and `make build-oem` completes after this capability is implemented
- **THEN** the produced `oem.img` MUST contain `boards/ynh960/radio/firmware/fmacfw_8800d80_u02.bin` (and the other keep-set files listed in the pack manifest)
- **AND** MUST NOT contain Broadcom `fw_bcm*` kitchen-sink trees as part of that radio pack

#### Scenario: OEM radio pack excludes kernel modules

- **WHEN** operators inspect the ynh960 OEM radio pack
- **THEN** `aic8800_*.ko` MUST be absent from `radio/`
