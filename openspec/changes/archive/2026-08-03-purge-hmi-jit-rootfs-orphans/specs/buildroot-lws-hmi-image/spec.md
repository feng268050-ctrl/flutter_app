## ADDED Requirements

### Requirement: Product /opt/hmi MUST NOT contain Flutter JIT snapshot blobs

The product rootfs HMI bundle under `/opt/hmi` SHALL be release AOT layout (`lib/libapp.so` + `data/flutter_assets` assets). It MUST NOT contain Flutter JIT artifacts `kernel_blob.bin`, `isolate_snapshot_data`, or `vm_snapshot_data` under `data/flutter_assets/`. Because Buildroot overlay rsync into the incremental `target/` tree does not delete overlay orphans, the board `post-build.sh` (BR2_ROOTFS_POST_BUILD_SCRIPT) SHALL explicitly remove those paths when present before packing `rootfs.img`. `scripts/verify-rootfs-overlay.sh` SHALL fail if any of those files remain in the staging `target/` after `make build-rootfs`.

#### Scenario: Stale kernel_blob purged on build-rootfs

- **WHEN** Buildroot `target/opt/hmi/data/flutter_assets/kernel_blob.bin` exists from a prior incremental build and `make build-rootfs` runs with the product post-build script
- **THEN** the packed rootfs staging tree MUST NOT contain that file

#### Scenario: verify rejects JIT leftovers

- **WHEN** `verify-rootfs-overlay.sh` inspects a staging `target/` that still has `/opt/hmi/data/flutter_assets/kernel_blob.bin` (or `isolate_snapshot_data` / `vm_snapshot_data`)
- **THEN** verification MUST report FAIL for the release `/opt/hmi` layout

#### Scenario: debug-app path unchanged

- **WHEN** the operator builds or deploys a debug HMI via `make debug-app` / debug staging
- **THEN** that path MAY still include `kernel_blob.bin` outside the product rootfs overlay bake (post-build applies only to Buildroot `target/` for image packing)
