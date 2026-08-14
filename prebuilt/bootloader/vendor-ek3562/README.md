# vendor-ek3562 bootloader (RK3562)

Drop the board vendor binaries here (do not reuse `rockchip-ynh960`):

```text
prebuilt/bootloader/vendor-ek3562/uboot.img
prebuilt/bootloader/vendor-ek3562/MiniLoaderAll.bin
```

`FACTORY_SKU=ek3562-dev` resolves `UBOOT_ID=vendor-ek3562`.
`make build-img` / `make flash` fail until both files exist.

U-Boot must select FIT configuration `ek3562` (`bootm <addr>#ek3562` or
factory env). Do not binary-patch `uboot.img` (env CRC / brick risk).

FIT DTB is pending vendor DTS (`overlay/kernel/rockchip/ek3562.md`) — do not
flash a factory image that still boots the default `ynh960` conf on this SoC.
