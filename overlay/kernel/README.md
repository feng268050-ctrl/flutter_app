# Kernel overlay (platform)

**Board device trees:** git source of truth is [`rockchip/`](rockchip/) (`ynh960.dts`,
`customer_board_*.dtsi`, …). **Drivers:** AIC8800 combo under
[`drivers/net/wireless/aic8800/`](drivers/net/wireless/aic8800/). Product GPIO is
**gpiod** (no `overlay/kernel/innohi/` — `gpio_innohi` removed).
`make apply-overlay` copies kernel trees into `linux-sdk/kernel/`, **strips**
owned-SDK `source "innohi/Kconfig"` / `drivers-y := innohi/` / `-Iinnohi/inc`, and
replaces Innohi-patched `panel-simple.c` with Rockchip `develop-6.1`
pre-`65f19639` (ABI matches owned `panel-simple.h`; see
[`drivers/gpu/drm/panel/`](drivers/gpu/drm/panel/README.md)).

Kernel **patches** and stable device script patches are squashed into owned
`linux-sdk/` by `make squash-linux-sdk-platform` / `make trim-linux-sdk` (W3).

**FIT inventory:** product `board_id` values that ship in the family boot FIT are
listed in [`board/rk356x-fit-boards.txt`](../../board/rk356x-fit-boards.txt)
(not discovered by globbing this directory). Add a board here **and** append that
`board_id` to the inventory; regenerate ITS via `scripts/generate-boot-fit-its.sh`
(or `make apply-overlay`). Emulator/`sim` is not a FIT conf.

**Policy:** kernel C patches → squash / owned tree. **DTS / `*.config` / firmware /
logo** → edit here and `make apply-overlay` every time.

Third-party Buildroot packages stay under `overlay/buildroot/package/` and
`overlay/third-party/`.
