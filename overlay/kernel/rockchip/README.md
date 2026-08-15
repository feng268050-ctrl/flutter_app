# Board device trees (git source of truth)

Product board **`.dts` / `.dtsi`** for FIT DTBs live here. `make apply-overlay`
copies this directory into `linux-sdk/kernel/arch/arm64/boot/dts/rockchip/`.
**Do not** treat the SDK copy as authoritative — edit only under `overlay/kernel/`.

SoC skeleton (EVB base, `rk3568-linux.dtsi`, `customer.dtsi`) stays in the
**owned** `linux-sdk/` kernel tree (build input only). Product wiring, Innohi
board blocks, and panel timing live here and are **not** re-synced from vendor.

**Baseline policy:** the current linux-sdk tree is already heavily customized.
We do **not** expect vendor SDK rebases. If Innohi/Rockchip ship something new,
selectively copy the needed driver/DTS/binary into `overlay/` (same as ek3562).

## ynh960 (shipping)

| File | Role |
|------|------|
| `ynh960.dts` | Top-level board DTS (`RK_KERNEL_DTS_NAME`, FIT conf `ynh960`) |
| `customer_board_ynh960.dtsi` | Frozen board wiring + `#include` of lws fragments below |
| `ynh960-*.dtsi` | Focused overlays (display, USB, touch, GMAC, RTC, …) |
| `ynh960-panel-init.dtsi` | Generated from `board/lcd_mipi_param.txt` (`scripts/gen-ynh960-panel-init-dtsi.sh`) |

Kconfig fragments: same directory (`*.config`), synced to kernel `arch/arm64/configs/`.

### Vendor kernel drivers (ynh960)

| Path | Role |
|------|------|
| [`../drivers/net/wireless/aic8800/`](../drivers/net/wireless/aic8800/) | AIC8800D80 SDIO Wi‑Fi/BT modules |
| `ynh960-own-gpio.dtsi` | disables `own_gpio`; USB_HOST_PWREN* via gpio-hog; product pads free for gpiod |

Platform udev: [`../../board/rockchip/common/rootfs-overlay/usr/lib/udev/rules.d/61-partition-init.rules`](../../board/rockchip/common/rootfs-overlay/usr/lib/udev/rules.d/61-partition-init.rules) (`by-name` / `by-partlabel`).

## ek3562 (RK3562 EVB2 DDR4 V10 — DTS landed)

Board package is in this directory (`ek3562.dts` + `ek3562-display.dtsi` + `ek3562-io.dtsi` +
`rk3562-evb2-*` / `rk3562-linux` / `rk3562-rk809`). Panel is lab **7″ 800×1280**; I/O expander
is **PCA9535** on i2c1（silk IN/OUT line map TBD）. **FIT inventory includes `ek3562`**;
OEM `fit_dt` = `ek3562`. Bootloader still gated — follow [`ek3562.md`](ek3562.md).

## Workflow

```bash
# After editing any *.dts / *.dtsi here:
make apply-overlay
make build-kernel          # DTB-only changes
# or FORCE_KERNEL_IMAGE=1 make build-kernel  # if *.config changed too
```
