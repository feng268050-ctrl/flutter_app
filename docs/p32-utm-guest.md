# Deprecated — see docs/p32-emulator.md

P3.2 formal path is **same kernel Image + same rootfs.img + sim_virt OEM** via QEMU:

```bash
make build-kernel
make build-rootfs
make build-emulator
make emulator
```
