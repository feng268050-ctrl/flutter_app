# board/virt — notes

P3.2 **formal** path no longer builds a separate virt Buildroot rootfs.

Use:

```bash
make build-kernel
make build-rootfs
make build-emulator
make emulator
```

See [`docs/p32-emulator.md`](../../docs/p32-emulator.md).

Residual files under `rootfs-overlay/` / `linux-virt.fragment` are optional references; the shared-Image virtio fragment is [`overlay/kernel/rockchip/emulator-virtio.config`](../../overlay/kernel/rockchip/emulator-virtio.config) (not a ynh960 board feature).
