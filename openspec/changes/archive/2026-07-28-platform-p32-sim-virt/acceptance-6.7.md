# P3.2 §6.7 acceptance — same OS + OEM switch

Formal path: **QEMU + device Image + device rootfs.img + sim_virt oem**. Not a separate virt BR rootfs. Not empty UTM.

| # | Criterion | Status |
|---|-----------|--------|
| 1 | Docs: same Image/rootfs, OEM, `make build-emulator` / `make emulator`; colleague first-time in README | **Done** — [`docs/p32-emulator.md`](../../../docs/p32-emulator.md), README Daily iteration |
| 2 | Same App; guest Linux HAL; no usbOtg | **Done** |
| 3 | Compose sim_virt; bad pack fails | **Done** — oem-compose + `/dev/vdb` mount |
| 4 | Cold boot: compose → hmi.service (VirGL + Weston + Flutter) | **Done** (operator: `make emulator` reaches HMI) |
| 5a | Three NICs: eth0 camera bridge, wlan0 L3, ethssh SSH (`MODE=EMU`) | **Done** — launcher + `.link` + vmnet/`sudo -E` |
| 5b | USB Modbus (RS485 → `/dev/ttyUSB0` via sim helper) | **Done** |
| 5c | USB Bluetooth product path | **Deferred** — see `p32-emulator.md` Future |
| 6 | GPIO LED overlay: sim auto, lights-only, blink via HAL `set` listener | **Done** |
| 7 | Same Image still packs FIT for ynh960 | **Done** — shared `emulator-virtio` fragment on product-line Image |
| 8 | Host VirGL audio/tablet; emulator rootfs grow for debug-app | **Done** — `streams=1`, `virtio-tablet`, `EMULATOR_ROOTFS_SIZE` default 1536M |
| 9 | `make debug-app` / `push-app` / `shell` via `SN=SIM-EMU` or `IP=127.0.0.1:2222` | **Done** |

## Post-landing notes (not in original §6.7 bullets)

- Stock Homebrew QEMU lacks GL — **`make setup-emulator-qemu`** (qemu-virgl) required on macOS.
- Guest Mesa via 9p (`fetch-emulator-swgl`), not baked into device rootfs.
- Emulator working `rootfs.img` is a **grown copy**; device OTA artifact stays **600M**.
