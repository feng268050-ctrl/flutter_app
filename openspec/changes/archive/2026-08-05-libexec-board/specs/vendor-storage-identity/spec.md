## MODIFIED Requirements

### Requirement: On-board vendor_storage tooling

The appliance rootfs SHALL include a working Vendor Storage userspace tool (Rockchip `vendor_storage` or equivalent) and thin board helpers under **`/usr/libexec/board/`** that read and write the product identity ID map. After GPT adoption, `/dev/vendor_storage` SHALL be usable for these helpers on real hardware. Emulator or environments without Vendor Storage SHALL fail clearly on write and SHALL apply the documented empty-SN → chip-ID fallback on read. Operator commands `/usr/bin/read-identity` and `/usr/bin/write-identity` SHALL target those helpers.

#### Scenario: Device node present on hardware

- **WHEN** a ynh960-class board has adopted the vendor GPT and booted the new rootfs
- **THEN** identity write helpers under `/usr/libexec/board/` SHALL be able to open Vendor Storage successfully

#### Scenario: Emulator write fails clearly

- **WHEN** `make write-identity` targets the QEMU emulator without Vendor Storage
- **THEN** the command SHALL exit non-zero with a clear message rather than silently writing `product.ini` identity keys

#### Scenario: Helpers not canonical under hmi

- **WHEN** inspecting the shipped rootfs after the `libexec-board` migration
- **THEN** the canonical `read-product-identity` / `write-product-identity` implementations SHALL live under `/usr/libexec/board/`
