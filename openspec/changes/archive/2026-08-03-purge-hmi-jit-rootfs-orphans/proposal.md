## Why

Buildroot applies `BR2_ROOTFS_OVERLAY` with `rsync` **without** `--delete`, so JIT leftovers under `/opt/hmi/data/flutter_assets/` (notably `kernel_blob.bin`, ~50 MiB) can survive in the incremental `target/` tree after release packaging has already stopped shipping them. Current host/SDK overlays are clean, but packed `rootfs.img` still carried orphans from the pre–AOT switch era.

## What Changes

- Rootfs **post-build** explicitly removes release-forbidden Flutter JIT artifacts under `/opt/hmi/data/flutter_assets/` (`kernel_blob.bin`, `isolate_snapshot_data`, `vm_snapshot_data`).
- `verify-rootfs-overlay.sh` fails if those files are still present after `build-rootfs`.
- No change to `make debug-app` staging (JIT remains valid only for the debug deploy path, not the product rootfs).

## Capabilities

### New Capabilities

- (none)

### Modified Capabilities

- `buildroot-lws-hmi-image`: Product `/opt/hmi` release layout MUST NOT contain Flutter JIT snapshot blobs; post-build MUST purge them when Buildroot incremental target reuse would otherwise keep them.

## Impact

- `overlay/board/rockchip/rk3566_rk3568/post-build.sh`
- `scripts/verify-rootfs-overlay.sh`
- Next `make apply-overlay` + `make build-rootfs` (drops ~50–60 MiB of dead weight from `target/` / `rootfs.img`)
