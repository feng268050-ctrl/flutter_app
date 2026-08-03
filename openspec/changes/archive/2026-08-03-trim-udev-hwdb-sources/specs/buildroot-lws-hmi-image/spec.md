## ADDED Requirements

### Requirement: Product rootfs ships hwdb.bin without hwdb.d sources

The product rootfs SHALL ship the compiled systemd hardware database at `/usr/lib/udev/hwdb.bin` when `BR2_PACKAGE_SYSTEMD_HWDB` is enabled. It MUST NOT ship `*.hwdb` source files under `/usr/lib/udev/hwdb.d/` or `/etc/udev/hwdb.d/` in the packed image. Because Buildroot installs both the compiled binary and the text sources, the board `post-build.sh` (BR2_ROOTFS_POST_BUILD_SCRIPT) SHALL remove those `*.hwdb` sources after package install and before packing `rootfs.img`. The image MUST NOT place a compiled database at `/etc/udev/hwdb.bin` solely as a byproduct of this trim. `scripts/verify-rootfs-overlay.sh` SHALL fail if `/usr/lib/udev/hwdb.bin` is missing, or if any `*.hwdb` remains under `usr/lib/udev/hwdb.d` or `etc/udev/hwdb.d` in the staging `target/`.

#### Scenario: post-build drops hwdb sources

- **WHEN** Buildroot has installed `/usr/lib/udev/hwdb.d/*.hwdb` and `/usr/lib/udev/hwdb.bin`, and `make build-rootfs` runs with the product post-build script
- **THEN** the packed rootfs staging tree MUST contain `/usr/lib/udev/hwdb.bin` and MUST NOT contain any `*.hwdb` under `/usr/lib/udev/hwdb.d/` or `/etc/udev/hwdb.d/`

#### Scenario: verify rejects leftover hwdb sources

- **WHEN** `verify-rootfs-overlay.sh` inspects a staging `target/` that still has any `*.hwdb` under `usr/lib/udev/hwdb.d` or `etc/udev/hwdb.d`
- **THEN** verification MUST fail

#### Scenario: verify rejects missing hwdb.bin

- **WHEN** `verify-rootfs-overlay.sh` inspects a staging `target/` that lacks `/usr/lib/udev/hwdb.bin` while the product profile enables systemd hwdb
- **THEN** verification MUST fail
