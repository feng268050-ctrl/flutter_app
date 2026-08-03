## ADDED Requirements

### Requirement: Product rootfs MUST NOT ship Wi-Fi/BT firmware kitchen sink

The shared product rootfs SHALL NOT install the multi-vendor Rockchip/Innohi Wi‑Fi/BT firmware dump (e.g. bulk `fw_bcm*`, `fw_syn*`, unrelated `.hcd`, Realtek trees) into `/usr/lib/firmware` or `/vendor/etc/firmware`. Combo module firmware for product boards SHALL come from the OEM radio pack. Kernel modules for the onboard AIC radio MAY remain on the rootfs/module path as today. `verify-rootfs-overlay.sh` (or equivalent) SHALL fail if forbidden kitchen-sink patterns are present after `make build-rootfs`.

#### Scenario: build-rootfs has no fw_bcm kitchen sink

- **WHEN** `make build-rootfs` completes after this change is implemented
- **THEN** staging `target/usr/lib/firmware` MUST NOT contain `fw_bcm*` blobs from the multi-chip dump
- **AND** AIC8800D80 product firmware MUST NOT be required to live under rootfs for Wi‑Fi bring-up success
