## 1. Post-build purge

- [x] 1.1 In `overlay/board/rockchip/rk3566_rk3568/post-build.sh`, after package install effects, remove all files under `$TARGET_DIR/usr/lib/udev/hwdb.d/` while keeping `$TARGET_DIR/usr/lib/udev/hwdb.bin`
- [x] 1.2 Ensure `$TARGET_DIR/etc/udev/hwdb.d` has no `*.hwdb` (remove if present); do not create `/etc/udev/hwdb.bin`
- [x] 1.3 Log a short post-build message when the purge runs

## 2. Verify gate

- [x] 2.1 In `scripts/verify-rootfs-overlay.sh`, FAIL if `usr/lib/udev/hwdb.bin` is missing
- [x] 2.2 FAIL if any `*.hwdb` exists under `usr/lib/udev/hwdb.d` or `etc/udev/hwdb.d`

## 3. Docs / close-out

- [x] 3.1 Mark tasks complete after implementation; archive change when ready
