# DRM panel drivers (git SoT)

| File | Source |
|------|--------|
| `panel-simple.c` | [rockchip-linux/kernel](https://github.com/rockchip-linux/kernel) `develop-6.1` at parent of [`65f19639f903`](https://github.com/rockchip-linux/kernel/commit/65f19639f903) (`d8e42edcd660`) |

**Why this revision (not tip):** Tip of `develop-6.1` changed `panel_simple_loader_protect` to a `rockchip_drm_sub_dev *` callback. Our owned SDK (6.1.180 + Rockchip DRM from the Innohi drop) still exports `int panel_simple_loader_protect(struct drm_panel *panel)` in `panel-simple.h`, and DSI/LVDS/RGB/DP call that symbol. The pre-`65f19639` file matches that ABI and still parses DT `panel-init-sequence`.

**Why override the SDK copy:** Innohi had patched `panel-simple.c` to `#include <innohi/common.h>` and pass `LCD_PARAM_S` into I2C display-bridge drivers (`bridge` phandle). This product line configures the panel via DT only — Rockchip’s file already does that without the Innohi ABI.

`make apply-overlay` installs this file into `linux-sdk/kernel/drivers/gpu/drm/panel/panel-simple.c`.
