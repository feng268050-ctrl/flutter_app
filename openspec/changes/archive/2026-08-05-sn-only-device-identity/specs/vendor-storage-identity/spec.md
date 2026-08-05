## MODIFIED Requirements

### Requirement: Host make write-identity provisions Vendor Storage

The host build system SHALL provide `make write-identity` that writes `BRAND`, `MODEL`, and product serial onto the selected board over USB-SSH or registered SSH (same device selection rules as `push-app` / `shell`: `SN=` / `IP=` for selection; **`CHIP_ID=` MUST NOT be accepted**). The identity serial value SHALL be passed as **`PRODUCT_SN=`** so it is not confused with device-selection `SN=`. The host SHALL invoke on-board Vendor Storage write helpers (not package identity into `factory.img`). If a non-empty SN is already stored and `FORCE` is not `1`, the command SHALL refuse to overwrite and exit non-zero. After a successful write, tooling SHALL verify readback of the three fields and SHOULD restart `hmi.service` so the App reloads identity.

#### Scenario: First-time write

- **WHEN** Vendor Storage SN is empty and the operator runs `SN=ABC123 make write-identity BRAND=LaserCyber MODEL=L1 Pro PRODUCT_SN=LC-001`
- **THEN** the board SHALL store brand/model and SN `LC001` (hyphens stripped) in Vendor Storage and readback SHALL match

#### Scenario: Strip hyphens from PRODUCT_SN

- **WHEN** the operator runs `make write-identity` with `PRODUCT_SN=L1P-S-001`
- **THEN** the stored SN SHALL be `L1PS001`

#### Scenario: Reject other non-alphanumeric PRODUCT_SN

- **WHEN** the operator runs `make write-identity` with `PRODUCT_SN=L1P_S_001` (underscore or other non-alnum besides `-`)
- **THEN** the command SHALL fail without writing Vendor Storage

#### Scenario: Refuse overwrite without FORCE

- **WHEN** Vendor Storage already has a non-empty SN and the operator runs `make write-identity` with a different `PRODUCT_SN` without `FORCE=1`
- **THEN** the command SHALL fail without changing stored identity

#### Scenario: FORCE overwrites

- **WHEN** Vendor Storage already has a non-empty SN and the operator runs the same write with `FORCE=1`
- **THEN** the command SHALL replace brand, model, and SN with the new values after successful write

### Requirement: HAL and board serial helpers read identity from Vendor Storage

HAL `ProductInfo.brand`, `ProductInfo.model`, and `ProductInfo.sn` SHALL be loaded from Vendor Storage (IDs above), not from `product.ini` keys `brand` / `model` / `sn`. `ProductInfo.chipId` SHALL remain chip/board serial for Apps, diagnostics, and secrets and MUST NEVER equal the product SN key from `product.ini`. Board helpers used for USB gadget iSerial and host `make devices` SN enrichment SHALL use the same product SN rule as `ProductInfo.sn`. Host `make devices` MUST list **SN** only (no ChipID column). Stale `brand`/`model`/`sn` lines in `/var/lib/hal/product.ini` MUST be ignored for these properties.

#### Scenario: Ini stale keys ignored

- **WHEN** `product.ini` contains `sn=OLD` but Vendor Storage SN is `NEW`
- **THEN** `ProductInfo.sn` and `make devices` SN SHALL be `NEW`

#### Scenario: SysInfo still exposes both

- **WHEN** Vendor Storage SN is `FACTORY-001` and chip serial is `ABC123`
- **THEN** `SysInfoSnapshot.serialNumber` SHALL be `FACTORY-001` and `chipId` SHALL be `ABC123`
