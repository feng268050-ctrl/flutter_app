## ADDED Requirements

### Requirement: Product /opt/hmi MUST NOT duplicate system librknnrt.so

The product rootfs SHALL provide Rockchip RKNN runtime at `/usr/lib/librknnrt.so` (via `make fetch-rknn-rt` / overlay). The HMI App tree under `/opt/hmi/lib/` MUST NOT contain `librknnrt.so`. Board `post-build.sh` SHALL remove any leftover `/opt/hmi/lib/librknnrt.so*` from the incremental Buildroot `target/` before packing `rootfs.img`. `scripts/verify-rootfs-overlay.sh` SHALL fail if `/opt/hmi/lib/librknnrt.so` is present.

#### Scenario: post-build purges App-bundled RKNN leftover

- **WHEN** `target/opt/hmi/lib/librknnrt.so` exists from a prior bake and `make build-rootfs` runs
- **THEN** the staging tree MUST NOT contain that file after post-build

#### Scenario: verify rejects duplicate

- **WHEN** `verify-rootfs-overlay.sh` finds `/opt/hmi/lib/librknnrt.so`
- **THEN** verification MUST report FAIL
