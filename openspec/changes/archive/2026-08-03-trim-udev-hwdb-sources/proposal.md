## Why

Product rootfs ships both systemd `hwdb.bin` (~12 MiB) and the full `hwdb.d` text sources (~8 MiB). Runtime only reads the binary; the sources are rebuild inputs. Keeping both doubles disk cost for PCI/USB/OUI pretty-name data we already want to retain in compiled form.

## What Changes

- After Buildroot installs systemd hwdb, board **post-build** removes `/usr/lib/udev/hwdb.d/*.hwdb` (and any stray files under that dir), keeping `/usr/lib/udev/hwdb.bin`.
- Ensure `/etc/udev/hwdb.d` stays empty of `.hwdb` files so `systemd-hwdb-update.service` does not regenerate an empty/overriding database on first boot.
- `verify-rootfs-overlay.sh` fails if `hwdb.bin` is missing or if any `*.hwdb` remains under `usr/lib/udev/hwdb.d` or `etc/udev/hwdb.d`.
- Does **not** disable `BR2_PACKAGE_SYSTEMD_HWDB` and does **not** trim the contents of `hwdb.bin` (full vendor/pretty-name database stays).

## Capabilities

### New Capabilities

- (none)

### Modified Capabilities

- `buildroot-lws-hmi-image`: Product rootfs MUST ship compiled `hwdb.bin` without shipping `hwdb.d` source trees that duplicate that data.

## Impact

- `overlay/board/rockchip/rk3566_rk3568/post-build.sh`
- `scripts/verify-rootfs-overlay.sh`
- Next `make apply-overlay` + `make build-rootfs` (~−8 MiB in `target/` / `rootfs.img`)
- Field note: on-device `systemd-hwdb update` cannot rebuild from sources until sources are restored; product images treat hwdb as immutable bake-time data.
