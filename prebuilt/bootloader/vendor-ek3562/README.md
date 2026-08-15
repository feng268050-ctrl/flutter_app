# vendor-ek3562 bootloader (RK3562)

Drop self-built Rockchip binaries here (do **not** reuse `rockchip-ynh960`):

```text
prebuilt/bootloader/vendor-ek3562/uboot.img
prebuilt/bootloader/vendor-ek3562/MiniLoaderAll.bin
```

`FACTORY_SKU=ek3562-dev` resolves `UBOOT_ID=vendor-ek3562`.
`make build-img` / `make flash` fail until both files exist.

## FIT (already in-repo)

- Inventory: `board/rk356x-fit-boards.txt` lists `ek3562`
- Conf name: `ek3562` (default FIT conf remains `ynh960`)
- OEM: `compat.fit_dt` = `ek3562`
- DTS SoT: `overlay/kernel/rockchip/ek3562.dts` (+ display / io / linux-root)

U-Boot **must** select FIT configuration `ek3562` (`bootm <addr>#ek3562` or factory env).
Do not binary-patch `uboot.img` (env CRC / brick risk).

Build notes: [`docs/uboot-rkbin.md`](../../../docs/uboot-rkbin.md), [`overlay/kernel/rockchip/ek3562.md`](../../../overlay/kernel/rockchip/ek3562.md), OpenSpec `ek3562-board-bringup`.
