# rockchip-ynh960 bootloader variant (vendor-verified for ynh960 Linux GPT).

Binaries are the same blobs historically kept under:
  prebuilt/sdk-uboot/uboot.img
  prebuilt/sdk-loader/MiniLoaderAll.bin

`make build-img` / FACTORY_SKU resolution reads this directory.
Do not binary-patch uboot.img (env CRC / brick risk).
