## Context

systemd hwdb is enabled (`BR2_PACKAGE_SYSTEMD_HWDB=y`). Buildroot installs both `/usr/lib/udev/hwdb.d/*.hwdb` (~8.1 MiB text, mostly pci/usb/OUI name catalogs) and the compiled `/usr/lib/udev/hwdb.bin` (~11.7 MiB). At runtime udev/`systemd-hwdb query` only reads the binary. Product HAL keyboard/mouse presence does not depend on pretty names, but operators still want the full name database available via the bin for `lsusb`/`udevadm` style inspection.

`systemd-hwdb-update.service` runs only when `ConditionNeedsUpdate=/etc` **and** one of: missing `/usr/lib/udev/hwdb.bin`, existing `/etc/udev/hwdb.bin`, or non-empty `/etc/udev/hwdb.d/`. Shipping an immutable `/usr/lib/udev/hwdb.bin` with empty `/etc` hwdb inputs is the documented pattern for immutable images.

## Goals / Non-Goals

**Goals:**

- Drop `hwdb.d` sources from the packed rootfs after the package has already built `hwdb.bin`.
- Keep full pretty-name coverage that is already inside `hwdb.bin`.
- Gate with `verify-rootfs-overlay.sh` so incremental target reuse cannot leave sources behind.

**Non-Goals:**

- Disabling `BR2_PACKAGE_SYSTEMD_HWDB`.
- Trimming contents of `hwdb.bin` (no input-only keep-set).
- Changing udev rules or product HID probing.

## Decisions

### D1 — Post-build `rm` of `/usr/lib/udev/hwdb.d/*` after systemd install

Same class as JIT / RKNN orphan purge: Buildroot package install is unchanged; board `post-build.sh` strips rebuild inputs before packing. Prefer emptying the directory over deleting the directory itself (avoid surprising tools that assume the path exists).

### D2 — Keep `/usr/lib/udev/hwdb.bin`; do not write `/etc/udev/hwdb.bin`

Immutable-image layout per hwdb(7). Avoids first-boot rewrite into `/etc`.

### D3 — Assert `/etc/udev/hwdb.d` has no `*.hwdb`

Current tree is empty; verify fails if local overlays later drop sources there (would arm `systemd-hwdb-update` and could regenerate from incomplete inputs).

### D4 — Verify requires `hwdb.bin` present

Trimming sources must not accidentally remove the binary (e.g. if HWDB package disabled). Fail closed.

## Risks / Trade-offs

- **[Risk]** Operator runs `systemd-hwdb update` on device with empty sources → empty/broken bin under `/etc` shadowing `/usr`. → Mitigation: document immutable bake; verify keeps `/etc` empty; product does not ship update workflows that depend on sources.
- **[Risk]** Future overlay adds `/etc/udev/hwdb.d/*.hwdb` without regenerating bin at build → first boot may rebuild incomplete `/etc` bin. → Mitigation: verify gate; design requires bake-time `systemd-hwdb update --usr` if product ever needs custom entries (out of scope now).
- **[Trade-off]** Saves ~8 MiB only (bin remains ~12 MiB). Accepted: user chose name retention over input-only or HWDB-off.

## Migration Plan

1. Land post-build + verify.
2. `make apply-overlay` + `make build-rootfs` (clears target leftovers).
3. `make upgrade` (or factory) to ship.

Rollback: remove the purge/verify lines; rebuild rootfs (sources return from systemd package install).

## Open Questions

- None.
