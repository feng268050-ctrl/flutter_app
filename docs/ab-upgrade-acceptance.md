# P2.4 A/B upgrade — device acceptance

Run after flashing an image built with the A/B `parameter-buildroot-fit.txt` GPT.

See also: [`storage-layout.md`](storage-layout.md), [`ab-slot-misc.md`](ab-slot-misc.md).

## Positive path (task 4.2)

1. `make apply-overlay` → `make build-kernel` → `make build-rootfs` → `make build-img`
2. **One-time** `make flash` (repartitions to `boot`/`boot_b` + `rootfs_a`/`rootfs_b`)
3. Confirm boot letter **A**: HMI up; `ls /dev/disk/by-partlabel/` shows `boot`, `boot_b`, `rootfs_a`, `rootfs_b`
4. Optionally set a Wi‑Fi or other pref under `/userdata/lws-hmi` (survives upgrade)
5. Change kernel and/or rootfs (e.g. rebuild), then:
   ```bash
   make build-img
   make upgrade
   ```
6. Expect: inactive letter written, reboot, HMI up on the other letter; prefs intact
7. Confirm: `journalctl -u lws-hmi-ab-boot-confirm` shows COMMIT

## Negative path (task 4.3)

1. Stage a corrupt `boot.img` or wrong digest under `/userdata/ota/` (or break the host bundle digest before transfer)
2. Run board apply / `make upgrade`
3. Expect: apply exits non-zero / `apply.status=fail`; **active letter unchanged**; prefs intact; no uboot rewrite

Also verify mounted-root protection:

1. Arm or simulate stale misc metadata whose `active` letter disagrees with the rootfs block device mounted as `/`.
2. Run board apply.
3. Expect: apply exits before any `dd`, reports the metadata/mounted-root mismatch, and never writes the mounted root partition.

App-only development is outside this A/B upgrade path; use `make build-app` followed by `make push-app`.
