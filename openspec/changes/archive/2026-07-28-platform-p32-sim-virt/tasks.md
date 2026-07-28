## 1. Docs / contract realign

- [x] 1.1 Rewrite proposal/design/specs for same Image + same rootfs + OEM switch (QEMU)
- [x] 1.2 Operator doc `docs/p32-emulator.md`; point platform plan §6.5 at same-OS path

## 2. Kernel Image publish + virtio

- [x] 2.1 Add `emulator-virtio.config` fragment; list in shared Image defconfig (`board/ynh960_defconfig` today — name is product-line build entry, not “simulate ynh960”)
- [x] 2.2 Publish `Image` from kernel build to firmware/emulator export path
- [x] 2.3 Ensure `CONFIG_SND_VIRTIO` (and related) apply when `.lws-owned-tree` skips full platform overlay — always sync kernel config fragments

## 3. Assemble + QEMU run

- [x] 3.1 `scripts/build-emulator.sh` packages Image + rootfs.img + sim_virt oem
- [x] 3.2 `scripts/run-emulator.sh` launches qemu-system-aarch64 to multi-user/HMI
- [x] 3.3 Makefile `build-emulator` / `emulator` / help / AGENTS / README
- [x] 3.4 Host VirGL: `setup-emulator-qemu` (qemu-virgl) + `fetch-emulator-swgl` (9p Mesa); playback-only `virtio-sound` (`streams=1`)
- [x] 3.5 Absolute pointer: `virtio-tablet-pci` (no host mouse grab)
- [x] 3.6 Network topology: eth0 = host camera NIC `vmnet-bridged`; wlan0 = `vmnet-shared` / SLIRP; `ethssh` = SSH hostfwd (`make devices` MODE=EMU); macOS `sudo -E` for vmnet
- [x] 3.7 USB xHCI auto-passthrough (ioreg on macOS); sim `modbus_rtu_device=/dev/ttyUSB0`
- [x] 3.8 Emulator-only rootfs grow (default 1536M) for `debug-app` / `push-app` headroom (device OTA stays 600M)
- [x] 3.9 Host tooling: `SN=SIM-EMU` alias, `make debug-app` / `push-app` / `shell` over EMU; colleague first-time steps in README

## 4. Rootfs sim boot thin

- [x] 4.1 display-init: mount emulator oem disk; skip missing display helper for sim
- [x] 4.2 oem-compose: mount `/dev/vdb` when present
- [x] 4.3 hmi-launch / weston: sim-friendly transform; keep drm-backend

## 5. App / HAL polish (post-assemble)

- [x] 5.1 GPIO LED overlay: sim-only auto show; lights-only; vertical top-left; blink via `GpioHal` level listener (no UI timer / settings toggle)
- [x] 5.2 HAL `modbus_rtu_device` helper override for USB-RS485 on emulator

## 6. Acceptance notes

- [x] 6.1 Update `acceptance-6.7.md` for same-OS QEMU checklist + post-landing topology / debug / audio / tablet
- [x] 6.2 Field smoke: USB Modbus dongle + IP-camera eth0 bridge; cold boot HMI; `MODE=EMU` / debug-app; ynh960 shared Image still packs FIT (operator-validated)

### Deferred (not blocking archive)

- USB Wi‑Fi dongle → real 802.11 on guest `wlan0`
- USB Bluetooth dongle → product BT path closed on emulator
