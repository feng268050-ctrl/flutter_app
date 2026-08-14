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
| [`../innohi/`](../innohi/) | leftover `gpio_innohi` (see [`../innohi/README.md`](../innohi/README.md)) |

Platform udev: [`../../board/rockchip/common/rootfs-overlay/usr/lib/udev/rules.d/61-partition-init.rules`](../../board/rockchip/common/rootfs-overlay/usr/lib/udev/rules.d/61-partition-init.rules) (`by-name` / `by-partlabel`).

## ek3562 (pending vendor)

See [`ek3562.md`](ek3562.md). When ready: add `ek3562.dts` + board `.dtsi` here,
append `ek3562` to `board/rk356x-fit-boards.txt`, clear OEM `fit_dt: pending`.

## Workflow

```bash
# After editing any *.dts / *.dtsi here:
make apply-overlay
make build-kernel          # DTB-only changes
# or FORCE_KERNEL_IMAGE=1 make build-kernel  # if *.config changed too
```
