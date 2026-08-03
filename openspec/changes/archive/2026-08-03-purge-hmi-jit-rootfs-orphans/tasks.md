## 1. Post-build purge

- [x] 1.1 In `overlay/board/rockchip/rk3566_rk3568/post-build.sh`, next to the existing `/opt/hmi` engine/icu `rm`, remove `kernel_blob.bin`, `isolate_snapshot_data`, and `vm_snapshot_data` under `data/flutter_assets/`, with a short log line

## 2. Verify gate

- [x] 2.1 In `scripts/verify-rootfs-overlay.sh` `/opt/hmi` section, FAIL if any of those three JIT files are present

## 3. Smoke

- [x] 3.1 Confirm host overlay still has no JIT blobs; optionally note rebuild commands for clearing SDK `target/`
