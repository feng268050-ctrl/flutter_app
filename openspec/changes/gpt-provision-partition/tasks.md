## 1. GPT and factory packaging

- [ ] 1.1 Add `provision` (`0x2000` sectors @ `0x4BE200`) to `board/parameter-buildroot-fit.txt`; userdata grow `@0x4C0200`; document frozen ABI in `docs/storage-layout.md`
- [ ] 1.2 Extend `scripts/verify-firmware-partitions.sh` for `provision` size/start
- [ ] 1.3 Extend `scripts/verify-no-vendor-payload.sh` → reject `provision` in package-file and `provision.img` in staging (rename script or add sibling if clearer)
- [ ] 1.4 Update `board/package-file-ynh960-linux-ab` comment (omit `provision` like vendor)
- [ ] 1.5 Wire verify into `scripts/build-img.sh`

## 2. Boot mount and bind

- [ ] 2.1 Mount `PARTLABEL=provision` → `/mnt/provision` in `display-init` (or early unit) before `bind-prefs`; mkfs only when unformatted
- [ ] 2.2 Bind `/var/lib/hal/properties.ini` → `/mnt/provision/properties.ini` (not userdata)
- [ ] 2.3 Update `bind-prefs.sh`: stop treating `properties.ini` as userdata/hal authoritative; one-time migrate userdata copy → provision
- [ ] 2.4 Add `provision-mount` / path docs to `os-path-layout` overlay verify if needed

## 3. Identity helpers

- [ ] 3.1 Remove OEM `identity.env` lookup from `read-product-identity.sh`; add `provision/identity.env` for non-VS boards
- [ ] 3.2 Update `write-product-identity.sh`: VS when present; else write `provision/identity.env`
- [ ] 3.3 Update host `scripts/write-identity.sh` to allow emulator / non-Rockchip (no hard fail on missing VS alone)
- [ ] 3.4 Delete `oem/boards/sim/identity.env`; rebuild `sim_virt` OEM

## 4. HAL and host tunables

- [ ] 4.1 Ensure `ProductIniReader` reads provision-bound path; tests updated
- [ ] 4.2 Update `set-product-prop.sh` / `del-product-prop.sh` for provision-backed file
- [ ] 4.3 Reject stale userdata-only paths in docs/scripts

## 5. Factory-reset and userdata wipe

- [ ] 5.1 Implement or update `factory-reset.sh`: full userdata wipe; never touch provision or VS
- [ ] 5.2 Align flash-time userdata hygiene docs/scripts with same contract (if in scope)

## 6. Emulator

- [ ] 6.1 `scripts/build-emulator.sh`: stage/create `output/firmware/emulator/provision.img`
- [ ] 6.2 `scripts/run-emulator.sh`: virtio `-drive` for `provision.img`
- [ ] 6.3 Optional dev autogen SN into `provision/identity.env` on first boot (`sim` board profile)
- [ ] 6.4 Update `packages/cyber_hal` stub/tests if they hard-code `SIM-0001` from OEM

## 7. Docs and AGENTS

- [ ] 7.1 `docs/storage-layout.md`: provision partition, Rockchip VS+provision, flash/reset matrix
- [ ] 7.2 `docs/hal-portability.md`, `docs/p32-emulator.md`, `docs/device-cloud-ed25519.md`
- [ ] 7.3 `README.md` / `docs/make-commands.md` flash vs upgrade vs 返厂 SOP
- [ ] 7.4 AGENTS.md rebuild table for parameter / overlay / emulator paths

## 8. Verification

- [ ] 8.1 `scripts/verify-rootfs-overlay.sh` updates for provision mount/bind
- [ ] 8.2 Manual: first flash adoption → `set-prop` → second `make flash` → tunables + VS SN unchanged; userdata empty after flash hygiene
- [ ] 8.3 Manual: factory-reset → userdata gone; provision `properties.ini` + VS identity intact
- [ ] 8.4 Manual: two emulator `provision.img` → different SN; no OEM `identity.env`
