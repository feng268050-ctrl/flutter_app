## ADDED Requirements

### Requirement: OEM product.ini is not per-unit identity authority

OEM board packs MAY ship a `product.ini` seed for SKU tunables under `boards/<board_id>/product.ini`. That seed MUST NOT be the authority for per-unit `brand`, `model`, or `sn` after Vendor Storage adoption. Per-unit identity SHALL be provisioned and read via Rockchip Vendor Storage (`vendor-storage-identity`). OEM documentation and pack contents SHOULD omit identity keys from the seed; compose MUST NOT use OEM identity keys to overwrite Vendor Storage or to act as the live product SN source.

#### Scenario: ynh960 seed is tunables-oriented

- **WHEN** inspecting `oem/boards/ynh960/product.ini` after this change
- **THEN** the file MAY define tunables such as `camera_ip`
- **AND** operators MUST NOT rely on it to set or preserve a per-unit product SN across `make flash`
