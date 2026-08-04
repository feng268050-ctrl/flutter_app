## 1. RockUSB OTA-images flash helper

- [ ] 1.1 Add a host helper (extend `flash-usb.sh` and/or new script used by upgrade) that, on macOS, selects RockUSB by `SN=`/`CHIPID=`, performs Maskrom `ul` bring-up when needed, and `di`-downloads `boot` / `boot_b` / `rootfs_a` / `rootfs_b` / optional `oem` from the resolved loose image paths
- [ ] 1.2 Resolve images like SSH upgrade: `output/firmware/boot.img`, `boot_b.img`, `output/firmware/<APP>/rootfs.img`, `factory-sku.sh` oem; honor `OEM_IMG=` empty skip and `OEM_ONLY=1` (oem only); refuse `factory.img` / `uf` on this path
- [ ] 1.3 Fail fast if required images missing or `di` fails; print a clear banner that this is OTA-equivalent images (not factory flash, not product OTA)

## 2. make upgrade dispatch

- [ ] 2.1 Update `scripts/upgrade-remote.sh` (and Makefile help env if needed) to auto-dispatch: SSH Linux target → existing stream; else RockUSB Loader/Maskrom → OTA-images helper; else guidance error; support optional `UPGRADE_TRANSPORT=ssh|rockusb`
- [ ] 2.2 Keep SSH stream behavior and preflight unchanged when SSH transport is selected

## 3. Docs

- [ ] 3.1 Update Makefile `help`, README Make commands, and `docs/storage-layout.md` upgrade-vs-flash-vs-OTA table for RockUSB `make upgrade`
- [ ] 3.2 Add/adjust AGENTS.md rebuild table row for host upgrade/flash script changes (exercise `make upgrade` on Loader/Maskrom; no firmware rebuild unless images stale)

## 4. Verification

- [ ] 4.1 Without hardware: missing images / no device errors are clear; `UPGRADE_TRANSPORT=rockusb` without RockUSB fails; SSH path still invoked when USB-SSH present (smoke)
- [ ] 4.2 On hardware when available: Maskrom and Loader each complete OTA-image downloads; board boots updated OS; confirm `make flash` factory path still untouched; `OEM_ONLY=1` only touches oem
