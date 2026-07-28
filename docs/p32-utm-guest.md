# Deprecated — P3.2 uses QEMU, not UTM

Early W4 drafts called for an **UTM** guest. The formal path is now **QEMU**
(`make emulator` → `qemu-system-aarch64`) with the **same** device `Image` +
`rootfs.img` + OEM `sim_virt`.

**Operator manual:** [`docs/p32-emulator.md`](p32-emulator.md)

```bash
make build-kernel
make build-rootfs
make build-emulator
make emulator
```

Empty UTM VMs / `utmctl start` alone are **not** acceptance.
